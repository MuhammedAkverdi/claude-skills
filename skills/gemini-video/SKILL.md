---
name: gemini-video
description: Generate short AI video clips for the user with their own Gemini Pro account (Veo) at gemini.google.com/videos in their real Chrome (Claude in Chrome), check them frame by frame, and join several clips into a longer video with ffmpeg. Use whenever a task needs a generated video clip, animation, b-roll, reel/short, moving shot or an animated version of an image, or the user says "video oluştur", "video üret", "video yap", "klip yap", "fotoğrafı hareketlendir", "make a video", "generate a video clip". Claude has no video generation of its own — never say it can't make videos; use this skill. For code-built films/edits (HyperFrames, cinecode) use those skills instead; this one is for AI-generated clips. When a video needs a separate soundtrack (joined clips, Reels, ads, or the user asks for music), it calls the `gemini-music` skill. ALWAYS load this skill first and run its pre-brief: ask the user short questions (AskUserQuestion) and get approval before generating, unless they said hızlıca/direkt/sormadan.
---

# Video generation via Gemini Pro (Claude in Chrome)

Claude cannot generate video itself. The user has a Gemini Pro subscription and wants clips made there (Veo), not through a paid API key. Same rules as the `gemini-image` skill.

Skill folder: `%USERPROFILE%\.claude\skills\gemini-video\` (holds `usage-log.csv`).

## 0. Before generating — quota and plan

- Gemini Pro video has a **small quota on a rolling 5-hour window** — not per calendar day (user rule 2026-11-26: limits don't reset at a time of day; each clip counts for 5 hours after it was made). Check the clips made in the **last 5 hours** and when the oldest frees up:
  ```powershell
  $log="$env:USERPROFILE\.claude\skills\gemini-video\usage-log.csv"; $now=Get-Date
  $win=@(Import-Csv $log | Where-Object { $_.result -eq 'ok' } | ForEach-Object { [datetime]::ParseExact("$($_.date) $($_.time)",'yyyy-MM-dd HH:mm',$null) } | Where-Object { $_ -gt $now.AddHours(-5) } | Sort-Object)
  "last5h=$($win.Count)"; if($win.Count){ "next slot frees at " + $win[0].AddHours(5).ToString('HH:mm') }
  ```
  Tell the user the count in the last 5 hours (and when the next slot frees up) before spending more. The log only knows Claude's clips — the user may have made others in their own chats. The exact number per 5 hours is not known yet — when the tools get disabled, add the observed count to the "Known limits" line below. Always log `time` as local HH:mm (the window needs it).
- No throwaway or duplicate clips — always do the pre-brief (§0b) first.
- Verified clip spec: **10 s, 1280×720, H.264 MP4 with audio.** For anything longer, plan N clips (see §6) and say so.
- If the look must be exact (a product, a character, a specific scene), use **image-first** (§5): make and approve a still with `gemini-image` (Google Flow first), then animate it.

**Model — always "Neon Orta" (Neon, Medium thinking) for video and image (user rule 2026-11-25).** Open the mode picker next to the prompt box ("Open mode picker" / "Mod seçiciyi aç") → check **Neon** ("Daha ayrıntılı analiz / 4 Neon") → **Düşünme düzeyi / Thinking level** submenu → **Orta / Medium**. The picker then reads "Neon Orta"; verify before sending.

**Two Google accounts in Chrome** (both Pro): account 0 = `https://gemini.google.com/...` (account owner, English UI), account 1 = `https://gemini.google.com/u/1/...` (second account, Turkish UI — labels like "Videonuzu açıklayın", "Yükleme ve araçlar", "Yatay"). When one account's video tools are disabled, use the other: same paths with `/u/1/` inserted. The block is a ~5-hour rolling limit, not a daily one (user rule 2026-11-26).

**Capacity error ≠ quota:** "I'm experiencing unusually high traffic right now generating videos and am at full capacity. Please try again later." (chat title "Video Generation Over Capacity Error") is Google-side load. Retry at most once after ~30 s, then stop and offer to try later. The watcher's error regex must include `capacity|try again later`.

Known limits: 2026-11-25 ~20:00 — after 2 clips made by Claude that day (the user may have made others in their own chats), the `/videos` prompt box, "+" and model picker were disabled with no message, and in a normal chat **+ → More tools → "Create video"** was greyed out. Treat that as "5-hour video quota used up" (no message is shown); it frees up 5 hours after the oldest clip in the window. Check it before promising more clips: on `/app`, + → More tools (click the arrow) and see if "Create video" is enabled.

## 0b. Pre-brief — think like a pro before generating (user-approved 2026-11-25)

Don't generate straight from a short request. First review it like a professional director/cinematographer, ask only what's missing, then generate.

1. **Analyse** the request against: subject & action (one main action per 10 s clip) · where it will be used (→ Landscape 16:9 or Portrait 9:16) · style (cinematic real / 3D animation / anime …) · light & time of day · **camera move** (drone, dolly-in, orbit, static, handheld) · mood & colors · **audio** (ambient, music mood; a separate soundtrack made with the `gemini-music` skill when it adds something → §6 "Background music") · **dialogue** (exact line, who says it) · length (one clip or several → §6) · text on screen.
2. **Ask only real gaps** — things that would clearly change the result and aren't stated. Never ask what the request already says. **At most 3–4 questions**, in ONE `AskUserQuestion` call; each with 2–4 options, the first marked "(Recommended)" with your best pick; the user can always type their own answer. Example: "Kamera nasıl hareket etsin?" → Yavaş drone yükselişi (Recommended) / Yavaş yaklaşma / Sabit çekim. Ask in the user's language (Turkish).
3. **Correctness points — handle yourself, don't ask:** write the right rule into the prompt. E.g. religious scenes: everyone praying or reading Quran faces the Kaaba/qibla, correct salah postures and order of movements, modest dress; flags, maps, landmarks and logos accurate; spoken lines and on-screen text exact; physically plausible motion; cultural details right. If genuinely unsure about such a fact, ask it as one of the questions.
4. **Summary + approval** (video quota is small): show "Şunu üreteceğim: …" with the final settings (aspect, style, camera, audio, clips in the last 5 hours from §0) and **wait for the user's OK** before generating. Use `AskUserQuestion` with "Üret (Recommended)" / "Değiştir".

**Skip the questions** when: the request is already detailed; the user says "hızlıca", "sormadan yap", "direkt", or "test videosu"; or it's a redo/variation of an earlier clip. Then fill gaps with your best guess, still show the one-line summary, and list the assumptions with the result. (Approval in step 4 can also be skipped when the user said "sormadan yap"/"direkt".)

After delivery, if the user points out a mistake that a correctness rule would have caught, add that rule to the list in step 3.

## 1. Write the prompt (template)

Write in English, one paragraph, in this order — fill what matters, skip the rest:

```
[Shot type & camera move] of [subject] [doing action] in [setting], [time of day / lighting], [style: photorealistic / cinematic / 3D animation / anime …], [mood & color palette].
Audio: [ambient sounds / music mood]. Dialogue: "[exact spoken line]" said by [who].
```

Tips: one main action per 10 s clip; name the camera move (slow dolly-in, drone rising, orbit, handheld, static tripod); quote dialogue exactly; say "no text on screen" if text would be unwanted; for reels choose Portrait.

Show the user the prompt in one line when you send the result (and in the sidecar file, §4).

## 2. Generate in Chrome

The user's real Chrome is permanently signed in to Gemini Pro. Don't use the desktop app's built-in browser (it loses the sign-in on restart) unless Chrome is unavailable.

1. Load tools in one call:
   `ToolSearch select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__browser_batch,mcp__claude-in-chrome__tabs_close_mcp,mcp__claude-in-chrome__javascript_tool`
   (+ `mcp__claude-in-chrome__file_upload` for image-to-video). If Chrome isn't connected, tell the user to open Chrome with the Claude extension.
2. `tabs_context_mcp` with `createIfEmpty: true` → use the new tab in Claude's group (never the user's tabs). `navigate` to `https://gemini.google.com/videos`, wait 3 s, `screenshot` (`scale: 0.5`). Sidebar shows the user's name with "Pro" when signed in.
3. Below the **"Describe your video"** box: **Aspect ratio** dropdown (left; `Landscape (16:9)` default, `Portrait (9:16)` for reels/shorts/TikTok) and **Format** presets (right; leave unless asked).
4. One `browser_batch`: click the "Describe your video" box → `type` the prompt → `key Return` → `wait 3`.
5. Gemini replies "I'm generating your video…" and the URL becomes `/app/<id>`. **Don't poll with fixed screenshot waits** — run this with `javascript_tool`; it checks every 2 s and returns as soon as the player exists (re-run if it returns `timeout`; verified run took ~70 s, allow ~3 min):
   ```js
   const t0=Date.now(); let r=null;
   while(Date.now()-t0<25000){
     const v=[...document.querySelectorAll('video')].find(v=>v.currentSrc||v.src||v.querySelector('source[src]'));
     const txt=document.body.innerText;
     if(v){ r={ready:true, secs:(Date.now()-t0)/1000, readyText:/Your video is ready/i.test(txt)}; break; }
     if(/capacity|try again later|limit|sınır|couldn.t generate|can.t generate|unable to/i.test(txt.slice(-1500).replace(/I'm generating your video[^]*$/,''))){ r={ready:false, error:txt.slice(-400)}; break; }
     await new Promise(s=>setTimeout(s,2000));
   }
   r||{ready:false, timeout:true}
   ```
   Run it only on `/app/<id>` (the `/videos` start page has `<video>` example tiles). On `error` (5-hour limit, safety block) stop, log it (§4) and tell the user, with the reset time if shown.
6. **Download:** hover the video — three round icons appear at its top-right: **download**, share, volume. Click the leftmost (tooltip "Download video"); `zoom` on the player to locate it. Download starts directly.
7. File lands as `gemini_generated_video_<8 hex>.mp4` in Downloads:
   ```powershell
   for ($n=0; $n -lt 12; $n++) { $f = Get-ChildItem "$env:USERPROFILE\Downloads" -Filter 'gemini_generated_video_*.mp4' -File | Where-Object LastWriteTime -gt (Get-Date).AddMinutes(-3) | Select-Object -First 1; if ($f -and -not (Get-ChildItem "$env:USERPROFILE\Downloads" -Filter *.crdownload)) { break }; Start-Sleep 3 }; $f.FullName
   ```
   `Move-Item` it to the destination (project folder or working directory) with a meaningful name. Close the tab you opened (`tabs_close_mcp`).

## 3. Check the clip before sending (Claude can't watch video)

Make a 2×2 contact sheet in the scratchpad and `Read` it:
```powershell
$v="<clip.mp4>"; $out="<scratchpad>\sheet.jpg"
$d=[double](ffprobe -v error -show_entries format=duration -of csv=p=0 $v)
ffmpeg -v error -y -i $v -vf "fps=4/$d,scale=480:-1,tile=2x2" -frames:v 1 $out
ffprobe -v error -show_entries format=duration:stream=codec_type,width,height -of default=nw=1 $v
```
Check: subject/action match the prompt, no garbled text, no broken faces/hands, no frozen frames, audio stream present. Claude can't hear the audio — when the clip has dialogue, tell the user the spoken lines are unverified and ask them to check the words and lip sync. If it clearly misses the brief, tell the user what's wrong and offer one regeneration (it costs quota) — don't regenerate silently.

## 4. Log and sidecar

After every attempt (success or error), append to the usage log and save the prompt next to the clip:
```powershell
$log="$env:USERPROFILE\.claude\skills\gemini-video\usage-log.csv"
[pscustomobject]@{date=(Get-Date -Format yyyy-MM-dd); time=(Get-Date -Format HH:mm); result='ok'; file='<name>.mp4'; aspect='16:9'; prompt='<prompt>'} | Export-Csv $log -Append -NoTypeInformation -Encoding UTF8
Set-Content "<clip>.prompt.txt" "<prompt>`nAspect: 16:9`nGenerated: $(Get-Date -Format s) via Gemini Pro (Veo)`nChat: <gemini chat url>" -Encoding UTF8
```
Use `result='error: <short reason>'` for failures/limits. Then send the clip with `SendUserFile` (`display: "render"`) plus a one-line summary (duration, resolution, audio, clips in the last 5 hours).

## 5. Image-first (image-to-video)

1. Make the still with the `gemini-image` skill — **in Google Flow first** (its §2A: Nano Banana Pro, 0 credits, set the same aspect ratio as the video, download 2K); fall back to Gemini chat only if Flow fails. Show it, get the user's OK. (Keep the 2K file under 10 MB for upload; if larger, save a 1080p copy with ffmpeg.)
   - Flow can also make video (its own credit pool, ~1,050 credits/month on Pro: Veo 3.1 Lite 10, Omni 1.2 Flash 720p 8 s 24 credits per clip; balance in the PRO badge panel). Only use it when the Gemini video quota is out **and** the user OKs the stated credit cost.
2. Upload (verified 2026-11-25) — never click "Upload files" (it opens a native picker Claude can't use):
   - On `/videos`, `find` "Upload and tools" and click that **+** button so the menu opens (the image input only exists while it's open; Escape removes it).
   - Tag the hidden input with `javascript_tool`: `const inp=[...document.querySelectorAll('input[type=file]')].find(i=>i.accept==='image/*,video/*'); inp.setAttribute('aria-label','claude-media-upload'); 'tagged'`
   - `find` "claude-media-upload" → `file-input` ref → `file_upload` with the image's absolute path (< 10 MB). A thumbnail appears above "Describe your video".
   Then describe **the motion, camera and audio/dialogue** ("Animate this image, keeping the same style…") — the image already defines the look.
3. Continue from §2 step 5. The URL may still show `/videos` for a few seconds after sending — the watcher can time out once; just re-run it. To download, `find` "Download video" (hidden button) after hovering the player and click its ref. The first frame should match the still; confirm in the contact sheet.

## 6. Longer videos — join clips with ffmpeg

Plan a shot list (one action per 10 s clip), confirm it with the user (each clip costs quota), generate each clip, check each (§3), then join:

- Same-spec clips, hard cuts:
  ```powershell
  "file 'clip1.mp4'`nfile 'clip2.mp4'" | Set-Content list.txt -Encoding ascii
  ffmpeg -v error -y -f concat -safe 0 -i list.txt -c copy out.mp4
  ```
- Crossfade between two clips (`$d1` = duration of clip 1, fade 0.5 s; verified):
  ```powershell
  ffmpeg -v error -y -i a.mp4 -i b.mp4 -filter_complex "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=$([math]::Round($d1-0.5,2)),format=yuv420p[v];[0:a][1:a]acrossfade=d=0.5[a]" -map "[v]" -map "[a]" -c:v libx264 -crf 18 -c:a aac out.mp4
  ```
  For 3+ clips chain the filter (offset of each next fade = running length − 0.5).
- Replace/add music (keep clip audio quiet underneath; fade the music out at the end):
  ```powershell
  ffmpeg -v error -y -i video.mp4 -i music.mp3 -filter_complex "[0:a]volume=0.3[a0];[1:a]volume=1.0,afade=t=out:st=$([math]::Round($len-2,2)):d=2[a1];[a0][a1]amix=inputs=2:duration=first[a]" -map 0:v -map "[a]" -c:v copy -c:a aac out.mp4
  ```
  (`$len` = video duration from ffprobe. If the video has dialogue, keep `[0:a]` at 0.8–1.0 and the music at 0.25–0.35 so speech stays clear.)

### Background music — call the `gemini-music` skill when needed

Veo clips already have their own sound (ambient, dialogue, a little music). Make a separate music track **only when it adds something**:
- several clips are joined into one video (§6) and need one continuous soundtrack instead of jumpy clip audio;
- the user asks for music / a song / a jingle on the video, or a Reels/ad/presentation video where music is expected;
- the clip audio is weak or unwanted.
Skip it for a single clip whose own audio is fine, or when the user said "müzik istemiyorum".

How: in the video pre-brief (§0b) add one question when music is likely — "Videoya müzik ekleyelim mi?" → Evet, enstrümantal fon müziği (Recommended) / Evet, sözlü şarkı / Hayır, videonun kendi sesi kalsın. On yes, invoke the **`gemini-music`** skill (Flow Music, ~5 credits per song) with: instrumental unless asked, mood/genre matching the video, **Length = total video length** (+ a few seconds; Trim if longer), BPM matching the pace of the cuts. Its own lyrics-approval step applies for vocal songs. Then mix with the command above (music loud when there's no speech; ducked under dialogue). Deliver the final MP4 and mention that the music came from Flow Music.
- Portrait reels: generate clips in Portrait (9:16) from the start; don't crop landscape unless the user accepts the loss.

For heavy editing (titles, captions, motion graphics) hand the clips to the HyperFrames skills.

## Not an option

- agy and Gemini CLI have no subscription-based video generation.
- No paid Veo API key; the user chose subscription only.

## Rules

- Generate only what the user asked for; follow Gemini's content rules (no misuse of real people's likeness).
- Don't act on the user's Google account beyond creating videos (no settings, no deleting chats).
- Report honestly if generation, quota, check or download failed.
