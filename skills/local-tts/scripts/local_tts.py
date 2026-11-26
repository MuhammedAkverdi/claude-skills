"""Free local Turkish voiceover with word timings (no API key, CPU only).

Engines / voices (only the ones that passed a blind listening test):
  yazgi-male-01     yazgi-tts-1, deep warm male narrator (Turkish)      Apache-2.0
  yazgi-female-02   yazgi-tts-1, calm mature female (Turkish)           Apache-2.0
  supertonic-M2     Supertonic 3, male, 31 languages                   OpenRAIL-M

Output, per clip: <out>.mp3, <out>.mp3.alignment.json (same keys as ElevenLabs /with-timestamps:
characters, character_start_times_seconds, character_end_times_seconds — for the exact input text),
<out>.mp3.prompt.txt. Timings come from faster-whisper word timestamps mapped onto the script words.

Usage:
  python local_tts.py --voice yazgi-male-01 --text "Merhaba." --out vo-01.mp3 [--speed 0.9]
  python local_tts.py --voice yazgi-female-02 --batch jobs.json      # [{"text": "...", "out": "vo-01.mp3"}, ...]
  python local_tts.py --align-only --text-file t.txt --audio x.mp3   # timings for an existing clip
"""
import argparse, difflib, json, os, re, subprocess, sys, tempfile, time, unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf

VOICES = {
    "yazgi-male-01": ("yazgi", "male-01"),
    "yazgi-female-02": ("yazgi", "female-02"),
    "supertonic-M2": ("supertonic", "M2"),
}
_engines = {}
START_BIAS = 0.07  # seconds; see align()


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def synth(voice, text, speed, lang, seed):
    """Return (float32 mono audio, sample_rate)."""
    engine, name = VOICES[voice]
    if engine == "yazgi":
        if "yazgi" not in _engines:
            from yazgi_tts import YazgiTTS
            _engines["yazgi"] = YazgiTTS()
        from yazgi_tts import RATE
        audio = np.asarray(_engines["yazgi"].say(text, voice=name, seed=seed), dtype=np.float32).squeeze()
        return audio, RATE  # speed is applied afterwards with ffmpeg atempo
    if "supertonic" not in _engines:
        from supertonic import TTS
        _engines["supertonic"] = TTS(auto_download=True)
    st = _engines["supertonic"]
    wav, _ = st.synthesize(text, voice_style=st.get_voice_style(voice_name=name), total_steps=10,
                           speed=max(0.7, min(2.0, speed)), lang=lang)
    return np.asarray(wav, dtype=np.float32).squeeze(), st.sample_rate


def to_mp3(audio, sr, out, tempo):
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "a.wav"
        sf.write(wav, audio, sr)
        af = ["-af", f"atempo={tempo:.3f}"] if abs(tempo - 1.0) > 1e-3 else []
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), *af, "-ar", "44100", "-ac", "1",
                        "-b:a", "128k", str(out)], check=True)


# ---------------- alignment ----------------
_whisper = None


def norm(w):
    w = unicodedata.normalize("NFC", w).replace("İ", "i").replace("I", "ı").lower()
    return re.sub(r"[^\wçğıöşü]", "", w)


def duration(path):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                 str(path)], check=True, capture_output=True, text=True).stdout.strip())


def align(text, audio_path, model_size, lang="tr"):
    global _whisper
    if _whisper is None:
        from faster_whisper import WhisperModel
        _whisper = WhisperModel(model_size, device="cpu", compute_type="int8")
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(audio_path), "-f", "s16le", "-ac", "1", "-ar", "16000", "-"],
                         check=True, capture_output=True).stdout        # decode with ffmpeg (no PyAV dependency)
    pcm = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    segs, _ = _whisper.transcribe(pcm, language=lang, word_timestamps=True, beam_size=5,
                                  initial_prompt=text[:400], vad_filter=False)
    heard = [(w.word, w.start, w.end) for s in segs for w in (s.words or [])]

    spans = [(m.start(), m.end()) for m in re.finditer(r"\S+", text)]           # script words
    sw = [norm(text[a:b]) for a, b in spans]
    hw = [norm(h[0]) for h in heard]
    times = [None] * len(spans)
    for blk in difflib.SequenceMatcher(None, sw, hw, autojunk=False).get_opcodes():
        tag, i1, i2, j1, j2 = blk
        if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
            for k in range(i2 - i1):
                times[i1 + k] = (heard[j1 + k][1], heard[j1 + k][2])
        elif tag == "replace" and j2 > j1:                                       # spread heard span over script words
            t0, t1 = heard[j1][1], heard[j2 - 1][2]
            lens = [max(1, len(sw[i])) for i in range(i1, i2)]; tot = sum(lens); acc = t0
            for i, L in zip(range(i1, i2), lens):
                d = (t1 - t0) * L / tot; times[i] = (acc, acc + d); acc += d
    matched = sum(t is not None for t in times)

    dur = duration(audio_path)
    # fill gaps (words whisper missed) by interpolation between neighbours, weighted by length
    i = 0
    while i < len(times):
        if times[i] is not None:
            i += 1; continue
        j = i
        while j < len(times) and times[j] is None:
            j += 1
        t0 = times[i - 1][1] if i > 0 else 0.0
        t1 = times[j][0] if j < len(times) else dur
        lens = [max(1, len(sw[k])) for k in range(i, j)]; tot = sum(lens); acc = t0
        for k, L in zip(range(i, j), lens):
            d = max(0.0, t1 - t0) * L / tot; times[k] = (acc, acc + d); acc += d
        i = j
    # whisper word starts are ~77 ms early vs ElevenLabs ground truth (measured on 84 words); shift starts later
    times = [(min(s + START_BIAS, e), e) for s, e in times]
    # keep times monotonic
    for k in range(1, len(times)):
        s, e = times[k]
        s = max(s, times[k - 1][0]); e = max(e, s)
        times[k] = (s, e)

    starts = [0.0] * len(text); ends = [0.0] * len(text)
    for (a, b), (s, e) in zip(spans, times):
        n = b - a
        for k in range(n):                                                       # linear within the word
            starts[a + k] = s + (e - s) * k / n
            ends[a + k] = s + (e - s) * (k + 1) / n
    # whitespace between words: from the end of the previous word to the start of the next
    last_e, idx = 0.0, 0
    for (a, b), (s, e) in zip(spans, times):
        for c in range(idx, a):
            starts[c] = last_e; ends[c] = s
        last_e, idx = e, b
    for c in range(idx, len(text)):
        starts[c] = last_e; ends[c] = dur
    al = {"characters": list(text),
          "character_start_times_seconds": [round(x, 3) for x in starts],
          "character_end_times_seconds": [round(x, 3) for x in ends]}
    return al, matched, len(spans)


def run_job(args, text, out):
    out = Path(out); out.parent.mkdir(parents=True, exist_ok=True)
    text = text.strip()
    t = time.time()
    audio, sr = synth(args.voice, text, args.speed, args.lang, args.seed)
    tempo = args.speed if VOICES[args.voice][0] == "yazgi" else 1.0
    to_mp3(audio, sr, out, tempo)
    t_tts = time.time() - t
    al, matched, total = align(text, out, args.whisper, args.lang)
    Path(f"{out}.alignment.json").write_text(json.dumps(al, ensure_ascii=False), encoding="utf-8")
    dur = duration(out)
    Path(f"{out}.prompt.txt").write_text(
        f"Voice: {args.voice}\nSpeed: {args.speed}\nLang: {args.lang}\nSeed: {args.seed}\nChars: {len(text)}\n"
        f"Generated: {time.strftime('%Y-%m-%dT%H:%M:%S')} locally (local-tts)\n"
        f"Alignment: faster-whisper {args.whisper}, {matched}/{total} words matched\nText:\n{text}\n", encoding="utf-8")
    res = {"file": str(out), "duration_s": round(dur, 3), "chars": len(text), "tts_seconds": round(t_tts, 1),
           "words_matched": f"{matched}/{total}", "alignment_file": f"{out}.alignment.json"}
    if matched < 0.8 * total:
        res["warning"] = "less than 80% of words heard - listen to this clip; the voice may have misread words"
    print(json.dumps(res, ensure_ascii=False), flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--voice", choices=list(VOICES), default="yazgi-male-01")
    p.add_argument("--text"); p.add_argument("--text-file"); p.add_argument("--out")
    p.add_argument("--batch", help="JSON list of {text, out}")
    p.add_argument("--speed", type=float, default=1.0, help="0.7-1.3; tales 0.9")
    p.add_argument("--lang", default="tr", help="Supertonic only (31 languages)")
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--whisper", default="small", help="faster-whisper model for timings")
    p.add_argument("--align-only", action="store_true"); p.add_argument("--audio")
    a = p.parse_args()
    a.speed = max(0.7, min(1.3, a.speed))
    text = Path(a.text_file).read_text(encoding="utf-8") if a.text_file else a.text
    if a.align_only:
        al, m, n = align(text.strip(), a.audio, a.whisper, a.lang)
        Path(f"{a.audio}.alignment.json").write_text(json.dumps(al, ensure_ascii=False), encoding="utf-8")
        print(json.dumps({"alignment_file": f"{a.audio}.alignment.json", "words_matched": f"{m}/{n}"})); return
    if a.batch:
        for job in json.loads(Path(a.batch).read_text(encoding="utf-8")):
            run_job(a, job["text"], job["out"])
    else:
        if not text or not a.out:
            p.error("--text/--text-file and --out are required")
        run_job(a, text, a.out)


if __name__ == "__main__":
    main()
