---
name: elevenlabs-tts
description: Generate Turkish and multilingual voiceovers, narration ("dış ses", "anlatıcı", "seslendirme") and character-level timestamps for exact subtitles with the user's ElevenLabs account via the REST API (`/with-timestamps`, ~2 s per clip, 10,000 free characters/month on the free plan). Use whenever a video, Reels, Short, ad or narration needs realistic Turkish speech or subtitle timing, or the user says "seslendir", "dış ses yap", "anlatıcı sesi", "voiceover", "text to speech", "metni oku". Default narrator engine for `gemini-reels` and `gemini-video`. Ask the user to approve the script text and the voice before spending characters.
---

# ElevenLabs TTS & Alignment (`elevenlabs-tts`)

Part of the claude-skills set (gemini-image, gemini-video, gemini-music, gemini-reels, elevenlabs-tts, ui-design). Needs your own ElevenLabs API key (free plan works) and `ffprobe` on PATH.

Produces a studio-quality voiceover (`MP3` + `alignment.json` character timestamps) in about 2 seconds via the ElevenLabs REST API.

**Two routes in Claude:**
- **REST scripts (default, below):** they save `.mp3` + `.alignment.json` + `.prompt.txt` straight into the project folder. Needed for exact `.ass` subtitles and for Reels.
- **ElevenLabs connector** (optional: connect ElevenLabs in Claude's connector settings; tools like `account_get_usage`, `creative_list_voices`): use it for browsing/designing/cloning voices (`creative_list_voices`, `creative_design_voice`), sound effects or quick one-off speech without timestamps. Load tools with ToolSearch first.

## API key (never print or log it)

Set by the user on 2026-11-26 as a User environment variable `ELEVENLABS_API_KEY` (verified). The scripts resolve it in this order:
1. `$env:ELEVENLABS_API_KEY` (current process)
2. User environment variable
3. `<this skill>\.env` (`ELEVENLABS_API_KEY=...`)

If it is ever missing, Claude never types or handles the key: tell the user to run this in their own PowerShell (hidden input, not saved in history):
```powershell
$k = Read-Host "ElevenLabs anahtari" -AsSecureString; [Environment]::SetEnvironmentVariable('ELEVENLABS_API_KEY',[Net.NetworkCredential]::new('',$k).Password,'User')
```

## Step 0 — Quota, voices and license

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\elevenlabs-tts\scripts\check_quota.ps1"
```
1. Check `subscription.tier` and `subscription.remaining` (2026-11-26: free, 9,630 / 10,000 left).
2. Count the characters of the final Turkish script and confirm it fits in `remaining` (a 4-scene Reels narration ≈ 300–450 chars).
3. Pick a `voice_id` from `voices`. Premade voices seen: George (warm storyteller, male), Alice (clear educator, female), Sarah (confident, female), Roger, Charlie, Callum, River, Harry, Liam, Will, Matilda, Laura. When it matters, ask the user (AskUserQuestion, Turkish) which kind of voice: derin anlatıcı / sıcak hikâyeci / enerjik genç…
4. **License:** on the `free` tier, remind the user briefly that it is for personal/non-commercial use; commercial or sponsored publishing needs a paid plan.

**Voice choice lessons (user review 2026-11-26):**
- Match gender/character to the content — a male voice on a children's bedtime tale was rejected; use a warm, soft female storyteller there. Generate 2–3 one-line samples and let the user listen before the full narration.
- **Free plan limit:** library voices (native Turkish narrators such as Zeynep `KAGDtM2gzDrjWlUp2KNe`, Melda `xtOBdZK8IsBvJfCFGpWa`, Betül Tuna `6GYyziau4Hk8qdg7od5c`, Derya `NNn9dv8zq2kUo7d3JSGG`) return `402 paid_plan_required` over the API. On free, only premade voices work (female: Sarah `EXAVITQu4vr4xnSDxMaL`, Alice `Xb7hH8MSUJpSbSDYk0k2`, Matilda `XrExE9yKIg1WjnnlVkGX`, Laura `FGY2WhTYpPnrIDTdsKH5`). Tell the user and let them choose (premade female now, or a paid plan for a native Turkish voice).
- **Pace:** `tts_generate.ps1 -Speed <0.7–1.2>` (added 2026-11-26). Children's tales 0.85–0.9; the default 1.0 sounded too fast.
- **Mixing:** narration must sit clearly above music (see `gemini-reels` Lessons §1: VO ≈ −16 LUFS, music ≈ −30 LUFS with sidechain ducking, check VO segment ≥ 8 dB above gaps).

## Step 1 — Model and lip-sync

- **Default model:** `eleven_multilingual_v2` — natural Turkish diction (ç ğ ı İ ö ş ü); stability 0.45, similarity_boost 0.78, style 0.35.
- **Expressive:** `eleven_v3` — inline tags like `[whispers]`, `[sighs]`; stability must be 0.0 / 0.5 / 1.0 (the script rounds it and drops `style`).
- **Lip-sync rule:** external TTS can't match a front-facing talking mouth. Use it for narrator / off-screen voice, and prompt Veo with `"No spoken dialogue, characters do not move their lips to speak, natural ambient sound effects only"`, or for shots where the speaker's mouth is hidden.

## Step 2 — Generate per-scene audio + timestamps

One clip per scene (`vo-01.mp3`, `vo-02.mp3`, …) so each video scene can be trimmed to `vo_dur + 0.6–0.8 s`.

**Turkish UTF-8 rule:** always pass Turkish text via `-TextFile` written as UTF-8 without BOM (`-Text` is safe only for plain ASCII under PowerShell 5.1):
```powershell
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$txtFile = "<project>\03-audio\vo-01.txt"
[IO.File]::WriteAllText($txtFile, "Karanlık ormanın derinliklerinde, kırmızı pelerinli kızın karşısına dev bir gölge çıktı.", $utf8NoBom)
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\elevenlabs-tts\scripts\tts_generate.ps1" -TextFile $txtFile -VoiceId "<VOICE_ID>" -OutPath "<project>\03-audio\vo-01.mp3" -ModelId "eleven_multilingual_v2"
```
Outputs: `vo-01.mp3` (44.1 kHz; duration printed in the JSON), `vo-01.mp3.alignment.json` (`characters`, `character_start_times_seconds`, `character_end_times_seconds`), `vo-01.mp3.prompt.txt` (model, voice, settings, text).

Deliver a standalone voiceover with `SendUserFile` (`display: "attach"`). Claude can't listen: tell the user to check pronunciation, especially names and numbers.

## Step 3 — Subtitles from `*.alignment.json`

Group the character timings into short 1–2 line cues (by punctuation or ~5–7 words) and shift each scene's cues by its start offset.
- `.ass` with `WrapStyle: 0` + explicit `\N`, UTF-8 without BOM.
- Reels safe zone: `MarginL: 90`, `MarginR: 160`, `MarginV: 480` (x 90..920, y 260..1460).

## Rules

- Never print, echo or commit `ELEVENLABS_API_KEY` or `.env` contents.
- No test loops: finalize the Turkish script and punctuation, get the user's OK on text and voice, check `remaining`, then generate once per scene.
- Spell tricky numbers/loanwords phonetically in Turkish when needed (`"on dokuz"` instead of `"19"`).
- Don't create, clone or delete voices, or change the ElevenLabs account/plan, without the user's OK.
