---
name: local-tts
description: Free, local Turkish voiceover / narration ("dış ses", "anlatıcı", "seslendir") with word-level timestamps for exact subtitles — no API key, no account, runs on the CPU of any Windows PC. Three ear-tested voices: yazgı-tts-1 male-01 (deep warm male narrator) and female-02 (calm mature female), and Supertonic 3 M2 (male, also 31 other languages). Writes vo-XX.mp3 + .alignment.json in the same format as elevenlabs-tts, so gemini-reels and any subtitle builder work unchanged. Default narrator engine for `gemini-reels`; use `elevenlabs-tts` only when the user wants ElevenLabs voices. Use when the user says "seslendir", "dış ses yap", "anlatıcı sesi", "voiceover", "text to speech", "ücretsiz ses", "yerel ses".
---

# Local voiceover (`local-tts`)

Free and offline after setup. Weights: yazgı-tts-1 **Apache-2.0**, Supertonic 3 **OpenRAIL-M** (commercial use allowed, no impersonation/misuse), faster-whisper **MIT**. Label narration as AI-generated where platforms ask for it.

Scripts: `$S = "$env:USERPROFILE\.claude\skills\local-tts\scripts"`, Python: `$PY = "$env:USERPROFILE\.local-tts\venv\Scripts\python.exe"`.

## Voices — only these three (blind listening test against ElevenLabs; every other voice of both models was rejected)

| `--voice` | Sound | Best for |
|---|---|---|
| `yazgi-male-01` (default) | 30s, deep, warm, narrator | tales, documentary, ads |
| `yazgi-female-02` | 60s, low, strong, calm | tales, calm/soothing, storytelling |
| `supertonic-M2` | male, neutral | non-Turkish text (`--lang en/de/fr/es/ar/…`), or as a third Turkish option |

Never offer other voices of these models. For a young female voice or strong emotion, offer `elevenlabs-tts` instead (it needs the user's ElevenLabs key).

## Step 0 — Setup (once per PC)

```powershell
if (-not (Test-Path $PY)) { powershell -ExecutionPolicy Bypass -File "$S\setup.ps1" -Warmup }
```
Creates `%USERPROFILE%\.local-tts\venv` (torch CPU, yazgi-tts, supertonic, faster-whisper; ~1.5 GB with models). Tell the user the size and get an OK before the first install (it downloads from PyPI, download.pytorch.org and Hugging Face). Needs Python 3.11+ and ffmpeg on PATH.

## Step 1 — Approve text and voice

Show the narration text per scene and the voice; for a new project play a short sample of the 2–3 fitting voices (one sentence each, `--out` into `03-audio\ses-ornekleri\`) and let the user pick. Children's tales: `--speed 0.9`. Short sentences, commas for breathing; write numbers as digits or words — the Turkish front end reads dates, prices and phone numbers correctly.

## Step 2 — Generate

One clip:
```powershell
$env:PYTHONIOENCODING = "utf-8"
& $PY "$S\local_tts.py" --voice yazgi-male-01 --speed 0.9 --text-file vo-01.txt --out 03-audio\vo-01.mp3
```
Many clips (models load once — use this for Reels):
```powershell
# jobs.json (UTF-8): [{"text": "Bir gece gökyüzündeki ay kayboldu.", "out": "03-audio/vo-01.mp3"}, ...]
& $PY "$S\local_tts.py" --voice yazgi-female-02 --speed 0.9 --batch jobs.json
```
Each clip prints one JSON line: `file`, `duration_s`, `tts_seconds`, `words_matched`, and `warning` when < 80 % of the words were heard (then listen to that clip: the voice may have misread a word; regenerate with `--seed 1`). Outputs per clip: `vo-01.mp3` (44.1 kHz mono), `vo-01.mp3.alignment.json` (`characters`, `character_start_times_seconds`, `character_end_times_seconds` for the exact input text — same as ElevenLabs), `vo-01.mp3.prompt.txt`.

Existing audio, timings only: `& $PY "$S\local_tts.py" --align-only --text-file t.txt --audio clip.mp3`.

## Facts (measured on a mid-range Windows laptop, CPU only)

- Speed: yazgı ~0.8× real time (60 s of narration ≈ 50 s), Supertonic ~0.3×; whisper alignment adds a few seconds per clip; first run downloads the models (~1.5 min).
- Timing accuracy vs ElevenLabs' own timestamps on 84 words: mean 49 ms, median 38 ms, 95 % within 123 ms (after a +70 ms start correction for whisper's early bias) — good for word-by-word subtitles.
- yazgı has no native speed control → `--speed` is applied with ffmpeg `atempo` (keeps pitch); Supertonic uses its own speed.
- yazgı reads calmly with little emotion; questions without "mı" don't rise — add "mı" or rephrase.
- Foreign names are read with Turkish letter sounds; respell them in the text ("Xiaomi" → "Şaomi").

## Rules

- Get the text and voice approved before generating long narration; deliver with `SendUserFile` and say which voice and speed were used.
- Never present the voice as a real person.
