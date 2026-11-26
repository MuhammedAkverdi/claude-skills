---
name: gemini-image
description: Generate, edit and refine photos/images for the user with their own Google AI Pro account — first in Google Flow (flow.google.com, Nano Banana Pro, 0 credits), else in Gemini chat at gemini.google.com — in their real Chrome (Claude in Chrome), check them visually, and deliver them in the right size/format (Instagram, story, YouTube thumbnail, WebP, transparent PNG). Use whenever a task needs a picture, photo, illustration, logo, icon, cover, poster, thumbnail or any generated image, or an edit of an existing photo (change background, remove/add objects, restore, restyle), or the user says "fotoğraf oluştur", "resim üret", "görsel yap", "foto lazım", "fotoğrafı düzenle", "arka planı değiştir", "logo yap", "make an image", "edit this photo". Claude has no image generation of its own — never say it can't make images; use this skill. ALWAYS load this skill first and run its pre-brief: ask the user 3–4 short questions (AskUserQuestion) before generating, unless they said hızlıca/direkt/sormadan or it is a v2 fix.
---

# Images via Google Flow / Gemini Pro (Claude in Chrome)

Claude cannot generate images itself. The user has a Gemini Pro subscription and wants images made there, not through a paid API key.

## Why Chrome, not the built-in browser

The user's real Chrome is permanently signed in to Gemini Pro, so no login is ever needed. The desktop app's built-in browser (`mcp__Claude_Browser__*`) loses the Google sign-in after an app restart — use it only if Chrome is unavailable (fallback below).

## 0. Pre-brief — think like a pro before generating (user-approved 2026-11-25)

Don't generate straight from a short request. First review it like a professional photographer/art director, ask only what's missing, then generate.

1. **Analyse** the request against: subject & action · where it will be used (→ format/aspect) · style (photo / illustration / 3D …) · light & time of day · composition & camera angle · mood & colors · text in the image (exact wording) · people (age, clothing, count).
2. **Ask only real gaps** — things that would clearly change the result and aren't stated. Never ask what the request already says. **At most 3–4 questions**, in ONE `AskUserQuestion` call; each with 2–4 options, the first marked "(Recommended)" with your best pick; the user can always type their own answer. Example: "Nerede kullanılacak?" → Instagram gönderisi (Recommended) / Story / YouTube küçük resmi / Sadece arşiv. Ask in the user's language (Turkish).
3. **Correctness points — handle yourself, don't ask:** write the right rule into the prompt. E.g. religious scenes: everyone praying or reading Quran faces the Kaaba/qibla, correct salah postures, modest dress; flags, maps, landmarks and logos accurate; text spelled exactly; correct number of people/fingers; cultural details (Turkish signage, clothing) right. If genuinely unsure about such a fact, ask it as one of the questions.
4. **One-line summary**, then generate: "Şunu üreteceğim: …" — for images, show it and generate right away (fixes happen in the same chat, §5).

**Skip the questions and generate directly** only when: the request already answers every point in step 1 (a one- or two-sentence request never does); the user says "hızlıca", "sormadan yap", "direkt", or "test fotosu"; or it's a refinement of an earlier image (v2, v3). Then fill gaps with your best guess and list the assumptions you made in the message with the result.

After delivery, if the user points out a mistake that a correctness rule would have caught, add that rule to the list in step 3.

## 0c. Route, model and account

- **Route A — Google Flow first (user rule 2026-11-25):** generate every new image in Google Flow (§2A). It costs **0 credits** on the Pro plan (Nano Banana Pro and 2.1), gives up to 4 variants per prompt and downloads in 2K. Full test 2026-11-25: Turkish text ("ÇAY SAATİ", "Her gün 17:00") spelled right in 4/4 variants; edit-in-place kept layout and text; green-screen logo → transparent PNG via §7 worked. If the result is good, keep working in Flow; if Flow fails, is limited, or the result is clearly worse than needed, switch to Route B (Gemini chat, §2) and say so.
- **Route B — Gemini chat** (§2): fallback, and the first choice for multi-turn chat refinements when Flow can't do the edit.
- In Gemini chat **always use "Neon Orta" (Neon, Medium thinking)** — user rule 2026-11-25. Before sending: open the mode picker next to the prompt box → **Neon** → **Düşünme düzeyi / Thinking level** → **Orta / Medium**; the picker then reads "Neon Orta".
- Chrome has two Pro accounts: `gemini.google.com/app` (account 0, English UI) and `gemini.google.com/u/1/app` (second account, Turkish UI). If one is limited or failing, use the other.

## 1. Write the prompt (template)

English, one paragraph, in this order — fill what matters:

```
Create an image: [subject + what it's doing], [setting/background], [composition: close-up / wide / centered / rule of thirds, camera angle], [lighting & time of day], [lens/camera feel e.g. 35mm, shallow depth of field — for photos], [style: photorealistic / watercolor / flat vector / 3D render / anime …], [color palette & mood], aspect ratio [16:9 | 9:16 | 1:1 | 4:5 | 3:4].
Text in image: "[exact text]" in [font style, position]   — or: no text, no watermark.
```

- Always state an aspect ratio matching the final use (see §6), so cropping loses little.
- Put any wanted text in quotes; check its spelling afterwards (Turkish characters ç ğ ı İ ö ş ü often break — keep text short).
- For logos/icons wanting transparency, add: `on a solid pure green (#00FF00) background, no shadows on the background` (see §7).

## 2A. Generate in Google Flow (Route A — default)

Verified live 2026-11-25 (account shows "PRO", Turkish UI; first-visit welcome + privacy-policy screens already accepted).

1. Load the Chrome tools (same call as §2 step 1, plus `find`, `read_page`). `tabs_context_mcp` `createIfEmpty: true`, then `navigate` to `https://labs.google/fx/tools/flow` (redirects to `https://flow.google.com/`).
2. Open a project: home page → **"Yeni proje"** (or reuse the project URL `https://flow.google.com/project/<id>` from an earlier image for refinements). If a "Flow Agent" intro dialog appears: click the → arrow until **"Başlayın"**, then click it.
3. **Turn the Flow Agent off** for direct generation: if the bottom bar says "Hedefinizi tarif edin" and the right agent panel is open, close the panel ("Kapat") and click the spark toggle next to the → button (tooltip "Flow ajanını etkinleştir" = off). The bar then reads "Ne oluşturmak istiyorsunuz?" with a chip like `Nano Banana Pro ▭ x2`.
4. Click the chip → settings popover: **Resim** (not Video) · aspect ratio **16:9 / 4:3 / 1:1 / 3:4 / 9:16** (pick per §6) · model dropdown → **Nano Banana Pro** (best quality; "Nano Banana 2.1" has Düşük/Orta/Yüksek thinking, "2 Lite" is fastest) · count **x1–x4** (x2 default). The footer must read "Üretme işlemi için **0 kredi** kullanılır"; if it shows credits > 0, tell the user before generating. `Escape` closes it.
   Settings persist per project (model, ratio, count, agent off) — still check the chip text before sending. **Never leave the popover on "Video"**: video costs credits (below).
5. One `browser_batch`: click the prompt box (`find` "Ne oluşturmak istiyorsunuz" → ref; coordinates move when the grid scrolls) → `type` the English prompt from §1 (drop the "Create an image:" prefix and the aspect-ratio words — the chip sets the ratio) → `key Return` → `wait 3` → this watcher (verified 2026-11-25): a tile is still generating while it shows "%N" or has a `blur(…)` overlay; the blur lingers a few seconds after the % disappears.
   ```js
   const busy=()=>[...document.querySelectorAll('main *')].filter(e=>(e.children.length===0&&/^%\d{1,3}$|^\d{1,3}%$/.test(e.textContent.trim()))||/blur\(/.test(getComputedStyle(e).filter)).length;
   const t0=Date.now(); let r=null; await new Promise(s=>setTimeout(s,2000));
   while(Date.now()-t0<40000){ if(busy()===0){ r={ready:true,secs:(Date.now()-t0)/1000}; break; } await new Promise(s=>setTimeout(s,1500)); }
   r||{ready:false,timeout:true}
   ```
   **Baseline first (fix 2026-11-26):** some pages keep a permanent blur element, so the watcher above can time out although the images are done. Before sending the prompt run `window.__b0=[...document.querySelectorAll('main *')].filter(e=>/blur\(/.test(getComputedStyle(e).filter)).length` and in the watcher treat `busy()<=window.__b0` (and no %N text) as ready. If it still times out, take a `screenshot` — sharp tiles mean done.
   **Keep every `javascript_tool` call under ~40 s** — the extension aborts a call after 45 s ("CDP … timed out") — so run the watcher with a 40 s cap and repeat it if it returns `timeout`, instead of one long loop. Then `screenshot`. Measured: Nano Banana Pro x2 ~25 s, Pro x4 (9:16) ~20–30 s, 2.1 edit ~15 s, 2 Lite x1 ~30 s (Lite is not faster in practice). Counting `<img>` tags does NOT work (blurred previews are already real images).
6. Pick the best variant (§3 check on the screenshot/zoom). Two ways to download:
   - **Quick, 1K original:** the grid is grouped by prompt; the **İndir** (↓) icon in the right-hand info column of that group downloads immediately (1024×1024 for 1:1, ~370 KB). For x1 groups only — with several variants use the tile menu.
   - **2K (default for delivery):** hover the tile → top-right **⋮ (Diğer seçenekler)** → **İndir** → **2K (Yükseltilmiş)**. Toast "Resminiz yükseltiliyor…", download starts by itself in ~5 s. 1K = original. **4K shows "Yükselt" = plan upgrade — never click it** (it leads to buying a higher plan).
7. Collect the file — Chrome saves `<Title_words>_<hex>_2K.jpg` (e.g. `Ginger_cat_sitting_on_windowsill_37d55576_2K.jpg`, 2752×1536 for 16:9):
   ```powershell
   for ($n=0; $n -lt 15; $n++) { $f = Get-ChildItem "$env:USERPROFILE\Downloads" -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-3) -and $_.Extension -in '.jpg','.png','.jpeg','.webp' } | Sort-Object LastWriteTime | Select-Object -Last 1; if ($f -and -not (Get-ChildItem "$env:USERPROFILE\Downloads" -Filter *.crdownload)) { break }; Start-Sleep 2 }; $f.FullName
   ```
   `Move-Item` it to the destination with a meaningful name.
8. **Edit / refine (verified):** click a tile → editor at `/project/<id>/edit/<imageId>` with the box **"Neyi değiştirmek istiyorsunuz?"**. Type the change ("Make it night … keep the same layout and the exact same text") → Return → ~15–25 s. It kept composition and text perfectly. History of versions is on the right ("Geçmişi gizle" toggles it); top bar has ♡, share, delete, **↓ download (1K/2K)**, **Bitti** (back to grid); left has a crop tool. If the edit box shows a small attached thumbnail you didn't intend, remove it with its ✕ first. Tile ⋮ also has "İsteme ekle" (use as reference in a new prompt), "İstemi yinele" (re-run), "Animasyon ekle" (video — costs credits).
9. **Upload the user's own photo (verified end to end 2026-11-25):** the native file picker must not open, so intercept it first with `javascript_tool`:
   ```js
   if(!window.__patched){ const o=HTMLInputElement.prototype.click; HTMLInputElement.prototype.click=function(){ if(this.type==='file'){ this.setAttribute('aria-label','claude-media-upload'); this.style.cssText='position:fixed;left:0;top:0;width:10px;height:10px;opacity:0.01;z-index:99999'; document.body.appendChild(this); return; } return o.call(this); }; window.__patched=true; } 'ok'
   ```
   (If `window.__patched` is set from an older version of this snippet, the patch is still active.) Then top-bar **+ (Medya menüsü ekle)** → **Yükle** → `find` "claude-media-upload" → `file_upload` with the absolute path (accepts png/jpg/webp/gif/heic and mp4/mov; < 10 MB per call). Flow then shows **"Bu resmin kullanım hakları"** (confirm you have the rights) with **İptal / Kabul ediyorum** — this is an attestation: confirm with the user in chat before clicking "Kabul ediyorum" (the user approved it once on 2026-11-25; ask again in a new session unless they said to always accept). The photo then uploads (tile shows %, ~10 s), appears under **Yüklemeler** in the sidebar with the label "Yüklenen resim"; click it → editor (step 8) → type the change → ~20 s. Verified: a stormy lighthouse photo turned into a sunny summer afternoon with the lighthouse and rocks kept; 2K download is named `<original-file-name>_<hex>_2K.jpg`. If anything fails, use Route B §4.
10. Other Flow features: **Karakterler** (save a character for consistent faces across images), **Sahneler**, **Kitaplık** collections, top-bar + → "Karakter oluştur". Not needed for single images.
11. Note the project URL for refinements, close the tab you opened.

**Credits (account panel: click the PRO badge):** images = **0 credits** with every Nano Banana model, x1–x4. Video in Flow costs credits: Omni 1.2 Flash 720p 8 s = 24, Veo 3.1 Lite = 10 per clip; the Pro plan has ~1,050 credits per month (reset date shown in the panel). Never start a video here without the user's OK and the cost stated.

If Flow shows an error, a limit/credit message, or produces nothing in 60 s: retry once, then switch to Route B (§2) and tell the user.

## 2. Generate in Gemini chat (Route B — fallback)

1. Load tools in one call:
   `ToolSearch select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__browser_batch,mcp__claude-in-chrome__tabs_close_mcp,mcp__claude-in-chrome__javascript_tool`
   (+ `mcp__claude-in-chrome__find,mcp__claude-in-chrome__file_upload` for editing, §4). If Chrome isn't connected, tell the user to open Chrome with the Claude extension, or use the fallback.
2. `tabs_context_mcp` with `createIfEmpty: true` → use the new tab in Claude's group (never the user's tabs). `navigate` to `https://gemini.google.com/app` — or, to refine an earlier image, to that image's chat URL (§5). `screenshot` (`scale: 0.5`): the sidebar shows the user's name with "Pro" when signed in.
3. One `browser_batch`: click the "Ask Gemini" box (center of a new chat; bottom on an existing chat) → `type` the prompt → `key Return` → `wait 3`.
4. Wait with this `javascript_tool` watcher instead of fixed waits — it checks every 1.5 s and returns once the new image has loaded (images take < 20 s):
   ```js
   const before = window.__imgCount ?? 0;
   const t0=Date.now(); let r=null;
   while(Date.now()-t0<25000){
     const imgs=[...document.querySelectorAll('img')].filter(i=>i.complete && i.naturalWidth>=512 && /googleusercontent|blob:/.test(i.src));
     const txt=document.body.innerText;
     if(imgs.length>before){ r={ready:true, secs:(Date.now()-t0)/1000, count:imgs.length, w:imgs.at(-1).naturalWidth}; break; }
     if(/capacity|try again later|limit|sınır|couldn.t generate|can.t generate|unable to/i.test(txt.slice(-1500))){ r={ready:false, error:txt.slice(-300)}; break; }
     await new Promise(s=>setTimeout(s,1500));
   }
   r||{ready:false, timeout:true}
   ```
   On a chat that already has images (refinements, variants), first run `window.__imgCount=[...document.querySelectorAll('img')].filter(i=>i.complete&&i.naturalWidth>=512&&/googleusercontent|blob:/.test(i.src)).length` **before** sending the prompt, so the watcher waits for the *new* one. Run the watcher only once the URL is `/app/<id>`. On `timeout` run once more, then `screenshot`. If Gemini replied with text, resend with clearer "Create an image of …" wording. (Verified on a live generation 2026-11-25: ready in 9 s. If it ever misfires, fall back to `wait 10` ×2 + `screenshot` and fix it here.)
5. `screenshot` once to locate the image, click the **download icon** at its top-right ("Download full size"; for the newest image when there are several), wait for the "Image downloaded" toast.
6. Collect the file — Chrome saves `Gemini_Generated_Image_<id>.jpg`:
   ```powershell
   for ($n=0; $n -lt 10; $n++) { $f = Get-ChildItem "$env:USERPROFILE\Downloads" -Filter 'Gemini_Generated_Image_*' -File | Where-Object LastWriteTime -gt (Get-Date).AddMinutes(-3) | Sort-Object LastWriteTime | Select-Object -Last 1; if ($f -and -not (Get-ChildItem "$env:USERPROFILE\Downloads" -Filter *.crdownload)) { break }; Start-Sleep 2 }; $f.FullName
   ```
   `Move-Item` it to the destination (project folder or working directory) with a meaningful name.
7. Note the chat URL (tab context) for §5 and §8, then close the tab you opened (`tabs_close_mcp`).

## 3. Check before sending (always)

`Read` the downloaded image (or a 1600-px copy in the scratchpad for very large files) and check:
- it matches the prompt (subject, composition, style, aspect ratio);
- any text is spelled exactly as asked;
- no broken hands/faces/extra limbs, melted objects or unwanted watermark/text.

If it clearly misses, refine in the same chat (§5) once and say so; if still wrong, show it and tell the user what's off. Report the resolution with `ffprobe -v error -show_entries stream=width,height -of csv=p=0 <file>`.

## 4. Edit an existing photo

Gemini edits uploaded photos: change/replace background, remove or add objects, restore/colorize old photos, change style, adjust lighting/season.

1. On a new chat (`/app`) — never click "Upload files" (it opens a native picker Claude can't use). Same technique verified on the videos page 2026-11-25: `find` "Upload and tools" and click that **+** so the menu stays open; tag the hidden image input with `javascript_tool`: `const inp=[...document.querySelectorAll('input[type=file]')].find(i=>/image\//.test(i.accept)); inp.setAttribute('aria-label','claude-media-upload'); 'tagged'`; `find` "claude-media-upload" → `file_upload` with the absolute path (< 10 MB). A thumbnail appears in the prompt box.
2. Prompt with only the change and what to keep: `Edit this photo: replace the background with a sunset beach. Keep the person, pose, face and clothing exactly the same.`
3. Continue with §2 steps 4–7 and §3; compare against the original.

Upload verified on the videos page; on `/app` not yet — if the accept filter differs there, adjust the selector here. Only edit photos the user provides or owns; follow Gemini's rules on real people.

## 5. Refine in the same chat

For changes to an image already made ("warmer", "move the fox left", "remove the text", "same style, now at night"), `navigate` to that image's chat URL (from §8's sidecar or this conversation) and ask there — Gemini keeps the look consistent. Start a new chat only for an unrelated image. Name refinements `name-v2.jpg`, `name-v3.jpg`, never overwrite earlier versions.

## 6. Size and format for the final use

Gemini output: 16:9 ≈ 2752×1536 (other ratios differ). Resize/crop with ffmpeg (verified). Center "cover" crop to an exact size:

```powershell
ffmpeg -v error -y -i in.jpg -vf "scale=W:H:force_original_aspect_ratio=increase,crop=W:H" -q:v 2 out.jpg
```

| Use | W×H | Generate at |
|---|---|---|
| Instagram post (portrait) | 1080×1350 | 4:5 or 3:4 |
| Instagram square / profile photo | 1080×1080 | 1:1 |
| Story / Reels / TikTok cover | 1080×1920 | 9:16 |
| YouTube thumbnail | 1280×720 | 16:9 |
| Twitter/X & LinkedIn post | 1600×900 / 1200×627 | 16:9 |
| Website hero | 1920×1080 | 16:9 |

- WebP for the web: `ffmpeg -v error -y -i in.jpg -vf "scale=1600:-1" -c:v libwebp -quality 82 out.webp`
- PNG: `ffmpeg -v error -y -i in.jpg out.png`
- Smaller JPEG: raise `-q:v` (2 = best … 5 = smaller).
If the crop would cut the subject, regenerate at the right ratio instead (say why). Keep the full-size original next to resized copies.

## 7. Transparent background (logos, icons, stickers)

Gemini can't output real transparency. Generate on solid pure green (§1), then key it out (verified):

```powershell
ffmpeg -v error -y -i in.jpg -vf "colorkey=0x00FF00:0.3:0.1,format=rgba" out.png
```

Check the result (`Read` it): if green fringes remain, raise similarity (0.3→0.35); if parts of the subject vanish (green in the logo), regenerate on pure magenta `#FF00FF` and key `0xFF00FF`. Optionally trim: add `,crop=...` after checking bounds.

## 8. Variants for important work

For logos, covers, posters, thumbnails, ads: generate 2–3 different interpretations (separate prompts in the same chat, each with a distinct idea), download all, show them side by side and let the user choose:

```powershell
ffmpeg -v error -y -i a.jpg -i b.jpg -i c.jpg -filter_complex "[0]scale=-1:400[a];[1]scale=-1:400[b];[2]scale=-1:400[c];[a][b][c]hstack=inputs=3" -q:v 3 variants.jpg
```

Then refine only the chosen one (§5). For quick one-off images, one generation is enough.

## 9. Prompt sidecar

Save next to every delivered image:

```powershell
Set-Content "<image>.prompt.txt" "<prompt>`nGenerated: $(Get-Date -Format s) via Gemini Pro`nChat: <gemini chat url>`nOutputs: <files incl. resized copies>" -Encoding UTF8
```

Then send with `SendUserFile` (`display: "render"`; several files together for variants or size sets) plus a one-line summary (resolution, what was checked).

## Fallback 1: built-in browser

Same steps with `mcp__Claude_Browser__*` (`preview_start` url `https://gemini.google.com/app`). If it shows "Oturum aç", call `tabs_context`; if the pane is hidden ask for **Ctrl+Shift+B**, then ask the user to sign in (never type credentials). Downloads land in `Downloads` as `<guid>.tmp` (a complete JPEG) — rename to `.jpg`.

## Fallback 2: agy CLI

```powershell
agy -p "Generate an image: <prompt>. Save it as a PNG at <absolute path>. Reply with only the saved path." --model gemini-4-neon-medium --mode accept-edits --print-timeout 300s
```

agy's image backend (`gemini-3.1-flash-image`) often fails with `HTTP 503 No capacity available` (Google-side, widely reported Nov 2026). Retry at most once — a 503 can still use quota.

## Not an option

- Gemini CLI (`gemini`, installed) cannot generate images with subscription login.
- The nanobanana extension needs a Gemini API key; the user chose not to use one.

## Rules

- Generate only what the user asked for; follow Gemini's content rules (no misuse of real people's likeness).
- Don't act on the user's Google account beyond creating/editing images (no settings, no deleting chats).
- Report honestly if generation, check or download failed.
