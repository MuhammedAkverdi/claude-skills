---
name: gemini-music
description: Make songs, instrumentals, jingles, background music and sound effects for the user with their own Google AI Pro account in Google Flow Music (flowmusic.app, Lyria 3.5) in their real Chrome (Claude in Chrome), and deliver MP3/WAV/M4A or stems. Also covers, extends, variations, remixes and splitting a song into stems. Use whenever a task needs music or a song, or the user says "şarkı yap", "müzik üret", "beste", "altyapı", "fon müziği", "jingle", "cıngıl", "enstrümantal", "videoya müzik", "make a song", "generate music", "background music", "split stems". Claude has no music generation of its own — never say it can't make music; use this skill. ALWAYS run its pre-brief first: ask the user short questions (AskUserQuestion) and get the lyrics approved before generating, unless they said hızlıca/direkt/sormadan.
---

# Music via Google Flow Music (Claude in Chrome)

Claude cannot generate music itself. The user's Google AI Pro includes **Flow Music "Plus"**: ~10,000 credits a month + daily free top-ups. **One song ≈ 5 credits** (verified 2026-11-25: 10,530 → 10,525). Downloads (MP3/WAV/M4A, stems) are free and unlimited. Same house rules as the `gemini-image` / `gemini-video` skills.

Account in Chrome: the user's Flow Music profile and Google account (already signed in). Never type credentials.

## 0. Pre-brief — think like a producer before generating

1. **Analyse** the request against: purpose / where it's used (video background, Reels, gift song, jingle, ad) · vocal or instrumental · language of the lyrics · genre & reference mood · tempo/energy (BPM) · length · vocal type (female/male, choir, rap) · story/subject of the lyrics · names or words that must appear.
2. **Ask only real gaps** — at most 3–4 questions in ONE `AskUserQuestion` call, 2–4 options each, the first "(Recommended)". Turkish questions. Example: "Sözlü mü olsun?" → Türkçe sözlü (Recommended) / Enstrümantal / İngilizce sözlü.
3. **Lyrics:** if vocal, write the lyrics yourself (or improve the user's) with section tags `[Intro] [Verse] [Pre-Chorus] [Chorus] [Bridge] [Outro]`, short singable lines, correct Turkish spelling (ç ğ ı İ ö ş ü — e.g. "Martılar" not "Martilar"), names spelled exactly. **Show the lyrics and the sound description and get the user's OK before generating** (cheap to fix now, a regeneration costs credits and time).
4. **Correctness yourself:** respectful handling of religious content (no instruments if the user wants an ilahi/nasheed — then "a cappella, vocals and daf only"), no real artist names or copyrighted lyrics (write "in the style of 90s Turkish pop", never "sounds like <singer>"), child-safe content for kids' songs.

Skip the questions when the user says "hızlıca", "direkt", "sormadan", or it's a redo (v2). Then list your assumptions with the result.

## 1. Write the sound description (English, comma-separated)

```
[genre + subgenre], [mood], [lead vocal: gender, timbre, language "singing in Turkish"], [key instruments], [rhythm/feel], [production: warm analog / crisp modern / lo-fi], [BPM] BPM, [key if it matters]
```
- Name the language of the vocals explicitly ("warm female vocal singing in Turkish"); the lyric language follows the lyrics. Turkish vocals verified good by the user (2026-11-25 test "Günaydın İstanbul").
- For long/complex songs you may write a timed plan like the community examples: `[0:00–0:20] Production: … Vocal: …` per section, plus "No …" exclusions at the end.
- Instrumental: switch **Instrumental** on and leave lyrics empty; describe the lead instrument and structure.

## 2. Generate (Compose panel — verified 2026-11-25)

1. Load Chrome tools in one call: `ToolSearch select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__browser_batch,mcp__claude-in-chrome__find,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__get_page_text,mcp__claude-in-chrome__javascript_tool,mcp__claude-in-chrome__tabs_close_mcp` (+ `file_upload` for audio/images).
2. `tabs_context_mcp` `createIfEmpty: true` → `navigate` to `https://www.flowmusic.app/session` (a new session).
3. `find` "Toggle compose panel" → click it. The right panel **Compose** has:
   - **Lyrics** box (`textbox "Lyrics"`) + **Instrumental** switch.
   - **Sound** box (`textbox "Sound description"`) + **Advanced** switch → **Dynamics**: BPM, Length, Seed (all "Auto"), Model (**Lyria 3.5** default = best; Lyria 3 Pro = legacy).
   - **Details** (expand): title, **Upload image** / **Prompt image** for the cover.
4. `find` the refs, click → `type` lyrics, click → `type` sound. Set BPM/Length under Advanced only if the user asked for them. Add a title under Details (otherwise it's "Untitled"). Click **Generate**.
5. The URL becomes `/session/<id>` and the chat shows `Creating "<title>"…`. Wait with this watcher (keep each `javascript_tool` call < 40 s; re-run on `done:false`):
   ```js
   const t0=Date.now(); let r=null; while(Date.now()-t0<38000){ const tx=document.querySelector('main')?.innerText||''; if(!/Creating "/.test(tx)){ r={done:true,secs:(Date.now()-t0)/1000}; break;} await new Promise(s=>setTimeout(s,2000)); } r||{done:false}
   ```
   Measured: ~25 s for a 1:52 song. **The new song auto-plays in the user's Chrome** — pause it right away (player bar ⏸) unless the user wants to listen there.
6. One Generate = one song. For important work make 2 versions (Generate again, or Remix → Variation) and let the user pick.

**Producer chat (alternative):** the "Ask Producer…" box at the bottom is a chat assistant (settings icon: Producer Standard/Fast, Ghostwriter Standard/Pro for lyrics, Instrument model). Use it when the user wants to co-write interactively; for predictable results prefer Compose. A "Make a 15s Shorts video" suggestion chip may appear after a song — it costs credits; don't click unasked.

## 3. Download

Player bar (bottom) → **⋯ (More options)** → **Download** → **MP3 / WAV / M4A**, **Get stems**, **Download video**. Default deliverable: **MP3** (48 kHz stereo, ~200 kbps); WAV when the user will edit/mix it. File lands as `<Title>.mp3` (`Untitled.mp3` without a title):
```powershell
for ($n=0; $n -lt 15; $n++) { $f = Get-ChildItem "$env:USERPROFILE\Downloads" -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-2) -and $_.Extension -in '.mp3','.wav','.m4a','.zip' } | Sort-Object LastWriteTime | Select-Object -Last 1; if ($f -and -not (Get-ChildItem "$env:USERPROFILE\Downloads" -Filter *.crdownload)) { break }; Start-Sleep 2 }; $f.FullName
```
Move it to the destination with a meaningful name, read duration with `ffprobe -v error -show_entries format=duration -of csv=p=0 <file>`, then `SendUserFile` (display `attach`). A PostHog survey popup ("How well did the lyrics fit…") may appear — close it with its ✕.

## 4. Check before sending

Claude cannot listen. Check what can be checked: duration matches the request, file plays (`ffprobe` ok), title right. Tell the user plainly that they should listen for pronunciation/lyrics — especially Turkish words — and offer a v2 with fixed spelling or a different vocal if something is off.

## 5. Edit an existing song (song ⋯ → Remix, or the Remix icon on a song page)

| Option | Use |
|---|---|
| **Cover** | Same song in another genre/vocal |
| **Replace** | Re-do one section |
| **Extend** | Make it longer |
| **Variation** | A similar alternative take |
| **Use prompt** | Reuse that song's sound description |
| **Trim** | Cut to length |
| **Split stems** / Download → Get stems | Separate vocals, drums, bass, other |
| **Create video** | Music video (credits — see §7) |

User's own audio: chat box **+** → **Upload → Audio** (max 40 MB) or **Recording**; then ask Producer for "make a backing track for my vocal" / "remix this". Use the same file-input interception as `gemini-image` §2A step 9 for uploads.

## 6. Use with videos

For a video's background music: match the length (Length field or Trim), choose Instrumental unless asked, then join with ffmpeg in the video skill, e.g. `ffmpeg -i video.mp4 -i music.mp3 -map 0:v -map 1:a -c:v copy -shortest -af "afade=t=out:st=<len-2>:d=2" out.mp4` (keep the clip's own dialogue by mixing with `amix` instead when it has speech).

## 7. Costs and safety

- Song ≈ 5 credits; balance: account menu → "<n> credits" or `https://www.flowmusic.app/settings`. Daily free credits top up.
- **Music videos are expensive** ("Credits are required… They can be expensive"). Never start one, a "Shorts video", or buy credits without the user's OK with the cost stated. Never click **Buy Credits** / plan changes.
- Don't publish songs, submit to Featured, follow artists, change account settings or privacy toggles unasked. Sessions and songs stay private unless published.
- Google doesn't claim ownership of the user's original songs; the user is responsible for inputs and use (Google ToS + Generative AI Prohibited Use Policy).

## 8. Prompt sidecar

Save `<file>.prompt.txt` next to the audio with the lyrics, sound description, model, session URL and date, so a v2 can start from it.

## Rules

- Generate only what the user asked for; no imitation of real singers or copyrighted lyrics.
- Report honestly if generation or download failed; close the tab you opened.
