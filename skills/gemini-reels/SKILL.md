---
name: gemini-reels
description: Make complete vertical Instagram Reels, YouTube Shorts and TikTok videos end to end with the user's own Google AI Pro account — scenario + Style Lock first, 9:16 keyframes in Google Flow (`gemini-image`, 0 credits), scene motion with Gemini Veo (`gemini-video`), Turkish narrator voiceover (free local `local-tts` by default, `elevenlabs-tts` optional), a soundtrack in Flow Music (`gemini-music`, ~5 credits), then a 1080x1920 MP4, cover and caption/hashtag draft assembled with ffmpeg. Use whenever the user asks for a Reel/Short/vertical video or says "reels oluştur", "reels yap", "reels videosu", "shorts yap", "tiktok videosu", "dikey video hazırla", "make a reel", or `/gemini-reels`. ALWAYS start with its pre-brief (AskUserQuestion, including the length in seconds) and get the scenario and storyboard approved before spending video quota, characters or credits.
---

# Reels / Shorts pipeline (`gemini-reels`, director)

Part of the claude-skills set; first tested on a children's tale Reels (2026-11-26).

This skill directs; the work is done by the sibling skills. **Read each sibling's SKILL.md before its stage** (invoke it with the Skill tool) so selectors, watchers and safety rules stay exact:
- **Keyframes & cover (0 credits):** `gemini-image` §2A (Google Flow, Nano Banana Pro, 9:16, 2K download)
- **Scene motion:** `gemini-video` (Gemini Veo image-to-video, Portrait 9:16, Neon Orta; rolling 5-hour quota, two accounts `/` and `/u/1/`)
- **Voiceover + timestamps:** `local-tts` by default (free, CPU, no account; voices `yazgi-male-01`, `yazgi-female-02`, `supertonic-M2`), or `elevenlabs-tts` when the user wants ElevenLabs (needs their key; free plan 10,000 chars/month). Both write `vo-XX.mp3` + `.alignment.json` in the same format, so Stage 5 is identical.
- **Soundtrack (~5 credits):** `gemini-music` (Flow Music, Lyria 3.5)
- **Assembly:** ffmpeg / ffprobe in PowerShell; visual checks with `Read` on contact sheets.

Browser: the user's real Chrome via Claude in Chrome (`mcp__claude-in-chrome__*`; load them in one ToolSearch call). Questions: `AskUserQuestion`, in Turkish. Delivery: `SendUserFile`.

## Project folder

Create `reels-<slug>\` in the session's working folder (or the project folder the user names):
```text
reels-<slug>\
├── senaryo.md          # scenario, Style Lock, scene table, cost plan, IG caption + hashtags
├── 01-frames\          # 9:16 2K Flow keyframes scene-01.jpg …, prompt sidecars, storyboard.jpg
├── 02-clips\           # raw Veo clips + trimmed/normalized 1080x1920 clips, joined.mp4
├── 03-audio\           # vo-01.mp3 + .alignment.json …, soundtrack.mp3
├── cover-1080x1920.jpg
└── final-reels.mp4     # 1080x1920, 30 fps, H.264 + AAC
```
Claude in Chrome's `file_upload` takes absolute paths; keep upload images < 10 MB.

---

## Stage 0 — Live availability + pre-brief

### 0a. Check what is available (before promising anything)
1. **Veo:** the usage log (`gemini-video` §0, rolling 5 hours) is only a hint. Check live in Chrome: `https://gemini.google.com/videos` and `https://gemini.google.com/u/1/videos` — Pro badge, prompt box and "Create video / Video oluştur" enabled.
2. **Narration engine** (when narration is planned): `local-tts` — check `%USERPROFILE%\.local-tts\venv\Scripts\python.exe` exists, else offer its one-time setup (Step 0, ~1.5 GB). ElevenLabs only if chosen: `elevenlabs-tts` Step 0 `check_quota.ps1` (never print the key).

### 0b. Topic-adaptive pre-brief (ONE `AskUserQuestion` call, max 4 questions)
Think like a Reels director; ask only what changes the result for *this* topic, options tailored to it, first option "(Recommended)":
- **Length in seconds** — always ask if not given: "Reels kaç saniye olsun?" → 30 sn, 4–5 sahne (Recommended) / 15–20 sn, 2–3 sahne / 60 sn, 8–10 sahne.
- **Audio structure** — recommend **anlatıcı (dış ses) + Veo ortam sesi + Flow Music** when storytelling fits (no Turkish lip-sync glitches, one consistent voice, exact subtitles); alternatives: Veo's own dialogue / music only.
- **Narrator voice** — free local voices first: "Yerel ses, sıcak erkek anlatıcı (yazgı male-01)" / "Yerel ses, sakin olgun kadın (yazgı female-02)" / "ElevenLabs (anahtarın varsa; genç kadın sesi, daha duygulu)". Pick the recommended one by genre; samples are played after the scenario (see Lessons §2).
- **All scenes real video?** — default yes; Hybrid only if the user picks it (Lessons §4).
- Visual style, pacing/perspective, on-screen text — only if unclear.

Skip questions only for "hızlıca", "direkt", "sormadan"; still state assumptions and get approval before spending quota, characters or credits.

---

## Stage 1 — Scenario, Style Lock, cost plan (Approval gate #1)

Hook (0–3 s) → development → climax / CTA, scaled to the requested length (~6–7 s per trimmed scene: 20 s ≈ 3, 30 s ≈ 4–5, 60 s ≈ 8–10 scenes). For ≥ 45 s plan resources explicitly (Veo quota across both accounts, total ElevenLabs characters) and propose a mix (Veo for dynamic scenes, Hybrid 2K motion for static ones) if Veo can't cover all.

**Director self-check (mandatory):**
1. **Continuity bridges:** no jumps between places/story states without a visual bridge or a one-sentence narrator bridge.
2. **No frame-1 spoilers:** a climax/rescue keyframe must not already show the twist; start before the reveal.
3. **One action and 1–2 short lines per scene** (~5–7 s).
4. **Tight pacing:** trim Veo's ~10 s clips to the best 5–7.5 s (`vo_dur + 0.6–0.8 s` with narration).
5. **Lip-sync:** with narrator voice, tell Veo `"No spoken dialogue, characters do not move their lips to speak, natural ambient sound effects only"`.
6. Correctness rules from `gemini-image` / `gemini-video` (qibla, flags, exact text, Turkish spelling ç ğ ı İ ö ş ü).

**Write and show:**
1. **Style Lock** — one English block copied verbatim into every scene prompt (light, grade, lens, era, recurring characters).
2. **Scene table** — `Sahne | Süre (trim) | Yöntem (Veo / Hybrid) | Görsel & aksiyon | Kamera | Anlatıcı / ses | Ekranda yazı`.
3. Save `senaryo.md`.
4. **Cost & quota summary:** keyframes 0 credits · Veo clips planned vs. live availability · narration: local voice = free (or ElevenLabs chars vs. remaining, e.g. ~350 / 9,630) · music ~5 credits · Flow Video only if Veo is out and the user approves, strictly **x1**.
5. `AskUserQuestion`: "Senaryoyu onayla, görsellere geç (Recommended)" / "Senaryoyu düzenle".

---

## Stage 2 — 9:16 keyframes (Approval gate #2)

1. One Google Flow project (`gemini-image` §2A): agent OFF, Resim, **9:16**, Nano Banana Pro, x2, footer "0 kredi".
2. Scene 1 first (Style Lock + scene prompt). For scenes 2..N always include the same Style Lock; when a character/place returns, attach the approved frame with tile ⋮ → **İsteme ekle** (or a Flow **Karakter**) so the look stays the same.
3. Download the best variant of each in 2K → `01-frames\scene-01.jpg` …; `Read` each (9:16 framing, hands/faces, no stray text or watermark).
4. Storyboard strip (adjust inputs to the scene count) and show it:
   ```powershell
   ffmpeg -v error -y -i scene-01.jpg -i scene-02.jpg -i scene-03.jpg -filter_complex "[0]scale=-1:600[a];[1]scale=-1:600[b];[2]scale=-1:600[c];[a][b][c]hstack=inputs=3" -q:v 2 storyboard.jpg
   ```
   `SendUserFile` it (`render`) and get the OK before any video quota or characters are spent.

---

## Stage 3 — Voiceover first, then video

### 3a. Narration (`local-tts` Step 2, or `elevenlabs-tts` Step 2)
Play 2–3 short voice samples (Lessons §2), use speed 0.85–0.9 for tales (Lessons §3), get the user's OK on the final narration text and voice, then generate `03-audio\vo-01.mp3` … (+ `.alignment.json`):
- **Local (default, free):** one `--batch jobs.json` run with all scenes (`local_tts.py --voice yazgi-male-01 --speed 0.9 --batch …`); check every line's `words_matched` and re-make any clip with a `warning`.
- **ElevenLabs:** `tts_generate.ps1 -TextFile … -Speed 0.88` per scene (UTF-8 without BOM).
Each `duration_s + 0.6–0.8 s` becomes that scene's trim length.

### 3b. Veo clips (`gemini-video` §2, §5 image-first)
- Upload `01-frames\scene-XX.jpg` (< 10 MB) on `/videos`, **Portrait / Dikey (9:16)**, Neon Orta. Prompt with narration: `"Animate this image smoothly, keeping the exact same subject, environment, lighting, and visual style. No spoken dialogue, characters do not move their lips to speak, natural ambient sound effects only, no background music, no text on screen."` + the scene's motion and camera move.
- **Faster:** run account 0 and account 1 in parallel tabs (e.g. scene 1 on `/videos`, scene 2 on `/u/1/videos`); **download and `Move-Item` one at a time** so `gemini_generated_video_*.mp4` files don't get mixed up.
- Log each attempt in `gemini-video\usage-log.csv`; check each clip with the 2×2 contact sheet (`gemini-video` §3).

### Flow Video (only if Veo is out AND the user approves the stated cost)
Settings chip must read **Video · 9:16 · x1** (never x2–x4 by default — it multiplies credits); footer cost must match what the user approved (Veo 3.1 Lite 10, Omni 1.2 Flash 24 credits); attach the approved keyframe as start frame.

### Hybrid mode (2K still + ffmpeg motion) when the quota can't cover every scene
- Real video only for dynamic scenes (hook, people moving/talking, hands, water/fire/smoke, vehicles); Hybrid only for wide vistas, interiors, product close-ups, outro. Never fake walking or physical action with zoompan — say so in Stage 1 instead.
- Same Flow project + Style Lock keeps colors matching; use slow motion and short 0.3–0.4 s xfades:
```powershell
$in = "01-frames\scene-03.jpg"; $out = "02-clips\clip-03-hybrid.mp4"; $fps = 30; $secs = 4; $frames = $fps * $secs
ffmpeg -v error -y -loop 1 -i $in -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -filter_complex "[0:v]scale=2160:3840:force_original_aspect_ratio=increase,crop=2160:3840,zoompan=z='min(zoom+0.0008,1.10)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=1080x1920:fps=${fps},format=yuv420p[v]" -map "[v]" -map 1:a -t $secs -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 $out
```

---

## Stage 4 — Soundtrack (`gemini-music`, ~5 credits)

Unless the user wants only the clips' own sound:
1. Start Flow Music while the last Veo clip is generating.
2. Compose panel, Lyria 3.5, **Instrumental ON** when there is narration/dialogue; BPM to the cut pace (90–105 cinematic, 115–128 energetic); Length in `m:ss` (Flow Music's minimum is 1:00 — the mix's `duration=first` + fade-out cuts it cleanly).
3. Pause auto-play, download MP3 → `03-audio\soundtrack.mp3`, check with ffprobe, write `soundtrack.mp3.prompt.txt`, close the tab.

---

## Stage 5 — Assembly, captions, cover, caption draft

### 5a. Trim and normalize each clip
```powershell
ffmpeg -v error -y -i $raw -t $trimDur -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30,setsar=1,format=yuv420p" -c:v libx264 -crf 18 -preset medium -c:a aac -ar 48000 -ac 2 $norm
```
(No audio stream? add `-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest`.)

### 5b. Join and mix
- Join with hard cuts (concat demuxer) or 0.35 s `xfade` + `acrossfade` → `02-clips\joined.mp4` (see `gemini-video` §6).
- **3-track mix:** each `vo-0X.mp3` at its scene offset (`adelay=<ms>|<ms>`, `amix`) at volume 1.0; Veo ambient 0.30–0.40; music 0.20–0.25 with 0.8 s fade-in and 2 s fade-out at `len-2`.
- **2-track:** Veo dialogue 1.0 + music 0.22–0.28 (or ambient 0.25 + music 1.0 without speech).

### 5c. Turkish title and subtitles (`.ass`)
- Safe zone 1080×1920: text inside x 90..920, y 260..1460.
- `.ass`: PlayResX 1080, PlayResY 1920, `WrapStyle: 0` + explicit `\N`, Segoe UI Bold, **equal** MarginL / MarginR (e.g. 100/100) + MarginV 430 for subtitles, MarginL = MarginR (60/60) + MarginV 330 + Alignment 8 for the hook title, UTF-8 without BOM. With narration, cue times come from `*.alignment.json` (word-by-word reveal, see Lessons §5–6b).
- Paths with non-ASCII characters (e.g. a Turkish user folder name with `İ`) break libass: `Push-Location` into the folder holding `subtitles.ass` and use `-vf "ass=subtitles.ass"`.

### 5d. Cover + caption draft
1. `cover-1080x1920.jpg`: crop/scale the strongest 2K keyframe (`-q:v 2`), `Read` it.
2. Append a ready-to-paste Turkish **Instagram açıklama + hashtag taslağı** to `senaryo.md`.

---

## Stage 6 — Final check, delivery, v2

1. `ffprobe`: 1080×1920, 30 fps, h264 + aac, duration as planned. Contact sheet (`-fps_mode vfr`, never `-vsync`) → `Read` it with the cover: subtitles inside the safe zone, Turkish letters correct, continuity, no broken frames.
2. `SendUserFile`: `final-reels.mp4` (`render`), `cover-1080x1920.jpg`, `01-frames/storyboard.jpg`, `senaryo.md`; summary in Turkish: length, resolution, method per scene, quota/characters/credits spent, checks done. Claude can't hear: ask the user to listen for pronunciation and pacing.
3. **v2:** regenerate only the changed piece; save as `final-reels-v2.mp4`, never overwrite.

## Lessons from the first Claude run (2026-11-26, "Fındık ve Kayıp Ay", 60 s, 9 scenes)

- **Chrome blocks repeated downloads** from one site after the first: ask the user to click the crossed-out download icon in the address bar → "always allow multiple downloads" for flow.google.com. Never change Chrome settings yourself.
- **Flow keyframe consistency:** add the approved scene-1 tile with ⋮ → **İsteme ekle** before every scene prompt that has the character; leave it off for scenes without the character. A page helper that finds the tile by its `img.src` (`/asb/<id>` prefix), clicks its `more_vert` button and then the `[role=menuitem]` ending in "İsteme ekle" / "İndir" → "2K" saved many clicks. After adding a reference the prompt box ref changes; focus it with JS (`[contenteditable=true]` lower on the page).
- **Gemini /videos resets to Neon Düşük and Yatay on every page load:** set Neon → Düşünme düzeyi → Orta and Dikey again before each send.
- **Capacity error on both accounts** happened right away at 03:40 (not a quota limit). Fallback that worked: Flow Video with the user's OK — settings Video · **Kareler** · 9:16 · **Veo 3.1 - Lite** · **x1** (footer "10 kredi"); **Başlat** opens a frame picker with a search box (search by the image's auto title, e.g. "wise owl"), then **İsteme ekle**; several clips can be queued at once (~2–3 min each, 8 s, 720x1280). Download: tile ⋮ → İndir → **720p Orijinal boyut** (1080p/4K are "Yükseltilmiş"; don't use without asking). The group's ↓ icon did not download videos.
- Downloads in a row can collide: collect each file by its own name/time before triggering the next one.
- **Assembly script:** a PowerShell script with Turkish text must be saved as **UTF-8 with BOM** for PowerShell 5.1. ffmpeg `drawtext` needs `fontfile=`, libass needs `fontsdir=.` with `segoeuib.ttf` copied next to `subtitles.ass` (no fontconfig on this PC). Trim overlapping cues (end = next start − 0.03). Add `loudnorm=I=-14:TP=-1.5` at the end of the mix (raw mix was −30 dB mean). Files over 30 MB don't reach phone viewers — also send a CRF 26 copy.
- Example project with a rerunnable `build.ps1`: the example project folder of the first test Reels.

### User review of that v1 — mistakes that must not happen again (MANDATORY rules)

The user rejected v1 for these reasons; each one is now a rule:

1. **Voice buried under music/ambience.** The bed was almost as loud as the narrator (measured: VO segments −16 dB, gaps −17.7 dB), and one final `loudnorm` flattened everything. Rule: normalise each stem first — narrator to about −16 LUFS, music bed to about −30 LUFS, clip ambience to about −32 LUFS — and **duck the music under the voice** (`[mus][vo]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400`). Only then apply a gentle final loudnorm. **Check:** mean volume of a narration segment must be ≥ 8 dB above a gap segment (`volumedetect` on both); don't deliver if not.
2. **Wrong voice for the content.** A male voice (George) on a children's bedtime tale was judged bad. Rule: pick voice gender/character to fit the genre (children's tale, lullaby → warm, soft female storyteller) and **let the user hear 2–3 short samples before generating the narration** (one line, ~80 chars each). Free ElevenLabs plan: native-Turkish library voices (Zeynep, Melda, Betül Tuna, Derya…) return `paid_plan_required` over the API — only premade voices (Sarah, Alice, Matilda, Laura…) work; say this to the user and offer the choice (premade female / paid plan). Since 2026-11-26 the free `local-tts` voices are the default: only `yazgi-male-01`, `yazgi-female-02` and `supertonic-M2` passed a blind listening test — never offer other yazgı/Supertonic voices.
3. **Narrator too fast.** Rule: children's tales at speed 0.85–0.9 (`local_tts.py --speed`, `tts_generate.ps1 -Speed`), short sentences, commas for breathing; plan scene lengths from the slowed VO.
4. **"Photo-only" scenes.** The user expects every scene to be real video. Rule: Hybrid (still + zoompan) is **not a default** — use it only if the user explicitly chose it in the pre-brief / cost plan. If Veo is short, ask: wait for the 5-hour window, or Flow Video credits (state the cost), or fewer/shorter scenes.
5. **Static subtitles.** Rule: subtitles must appear **word by word as the narrator speaks** — build ASS karaoke from `*.alignment.json`: per cue, each word gets `{\k<cs>}` with `SecondaryColour` fully transparent (`&HFF000000`) so unspoken words are invisible and each word pops in on time (or one event per word reveal). Keep 1–2 lines, centred.
6. **Crooked/ugly title.** Asymmetric margins (MarginL 90 / MarginR 160) pushed the "centred" title and subtitles off-centre, and the 2-line title looked bad. Rule: centred text uses **equal MarginL = MarginR** (keep both inside the safe zone, e.g. 120/120); title one clean line or balanced lines, larger, with a designed look (outline/shadow/soft glow, fade or scale-in animation); **extract the title frame and `Read` it** before delivery.
6b. **Subtitle timing bug (v2 draft, user caught it):** in PowerShell `[math]::Max(0, $x)` picks the Int32 overload and rounds every time to whole seconds → words appeared late or never (zero-length events). Always `[math]::Max(0.0, $x)`, format ASS time from integer centiseconds, and **verify the .ass**: no event shorter than 0.05 s, no overlaps, and list the full-text event of each cue. Build cues per sentence; split a sentence > 52 chars once at a balanced point (prefer a comma) so no cue is a lonely last word. Also beware PowerShell variable names are case-insensitive (`$c` overwrote `$C`). Keep a rerunnable build script (`build.ps1`) in each Reels project.
7. **Self-review before delivery.** Watch-list for the contact sheet and frame checks: voice vs bed level, subtitle timing (no overlaps), title alignment, every scene moving, no repeated near-identical shots. Offer a short draft (first 10–15 s) for the user's OK before rendering the whole film when anything new is tried.

## Rules

- No keyframes before the scenario is approved; no Veo quota, narration (local or ElevenLabs characters) or Flow credits before the storyboard is approved.
- Live check beats the usage log for Veo quota.
- Flow Video strictly x1 and only with the user's OK on the stated cost; never click Buy credits / Yükselt / plan upgrades.
- Never print the ElevenLabs key; no paid Gemini/Veo API keys; close every Chrome tab you opened.
- Don't publish anything to Instagram/YouTube/TikTok — deliver files; the user posts.
