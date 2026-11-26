# claude-skills

Claude Code için medya ve arayüz skill'leri: fotoğraf, video, müzik, Türkçe dış ses, uçtan uca Instagram Reels, "AI gibi görünmeyen" arayüz tasarımı ve bir projeyi birkaç AI ajanıyla yürüten orkestrasyon.
Hepsi **kendi aboneliklerinizle** çalışır (Google AI Pro, ElevenLabs). Ücretli API anahtarı gerekmez; Claude işi sizin Chrome'unuzda, giriş yapılmış hesaplarınızla yapar.

*English summary below.*

## Skill'ler

| Skill | Ne yapar | Nerede üretir |
|---|---|---|
| **gemini-image** | Fotoğraf, logo, kapak, poster üretir ve düzenler. Instagram/Story/YouTube boyutları, şeffaf PNG | Google Flow (Nano Banana Pro, 0 kredi), yedek: Gemini sohbet |
| **gemini-video** | 10 sn'lik AI video klipleri, fotoğraftan video, klip birleştirme. 5 saatlik kotayı takip eder | Gemini (Veo), yedek: Flow Video (kredi, onayla) |
| **gemini-music** | Şarkı, enstrümantal, fon müziği, jingle; Türkçe sözlü şarkılar | Google Flow Music (Lyria 3.5, şarkı başı ~5 kredi) |
| **elevenlabs-tts** | Türkçe dış ses + kelime kelime zaman damgası (altyazı için) | ElevenLabs REST API (ücretsiz plan çalışır) |
| **gemini-reels** | Baştan sona dikey video: senaryo → 9:16 görseller → Veo hareket → dış ses → müzik → montaj, kelime kelime altyazı, kapak, Instagram açıklaması | Yukarıdaki 4 skill + ffmpeg |
| **ui-design** | Şablon gibi durmayan arayüzler: tasarım tezi, "AI-slop" testi, gerçek tarayıcıda masaüstü/mobil kontrol, P0–P3 düzeltme | Claude'un tarayıcısı veya Claude in Chrome |
| **orchestration** | Bir projeyi birkaç AI ajanıyla yürütür: Claude lider olur (planlar, brief yazar, ölçer, hakemlik yapar, birleştirir; ürün kodu yazmaz), işi rollere dağıtır. Arka planda ajan başlatma + izleme, otomatik kalite kapısı, kota takibi ve yedek modele geçiş, görev grafiği, worktree yönetimi, merge treni, panel (dashboard). Tüm durum `orchestrator/*.md` dosyalarında, bağlam dolsa da kaybolmaz | agy CLI (Gemini Neon/Hydrogen/Carbon) + Claude Code CLI (Sonnet) + git |

Her skill önce **kısa sorular sorar** (kullanım yeri, stil, süre, ses…), kredi veya kota harcamadan önce **onay alır** ve sonucu teslim etmeden önce kendisi kontrol eder.

## Gereksinimler

- [Claude Code](https://claude.com/claude-code) (masaüstü uygulaması veya CLI)
- **Claude in Chrome** eklentisi; Chrome'da Google hesabınız açık olmalı
- **Google AI Pro** aboneliği (Gemini, Flow, Flow Music)
- **ffmpeg / ffprobe** PATH'te (video, ses ve montaj için)
- `elevenlabs-tts` ve `gemini-reels` için **ElevenLabs API anahtarı** (ücretsiz plan yeterli)
- `orchestration` için **git**, **agy** (Google Antigravity CLI, giriş yapılmış) ve **claude** CLI PATH'te; agy'nin `~/.gemini/antigravity-cli/settings.json` dosyasında `"allowNonWorkspaceAccess": true`
- Windows + PowerShell üzerinde test edildi (komutlar PowerShell 5.1 uyumlu)

## Kurulum

```powershell
git clone https://github.com/MuhammedAkverdi/claude-skills.git
cd claude-skills
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` skill'leri `%USERPROFILE%\.claude\skills\` klasörüne kopyalar. Aynı isimde bir skill varsa önce yedeğini alır (`skills-backup-<tarih>`). Sadece bazılarını kurmak için:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Only gemini-image,gemini-music
```

macOS / Linux: `cp -r skills/* ~/.claude/skills/`. PowerShell örneklerini kendi kabuğunuza uyarlamanız gerekir.

**ElevenLabs anahtarı** (bir kez, kendi PowerShell'inizde; yazdığınız görünmez):

```powershell
$k = Read-Host "ElevenLabs anahtari" -AsSecureString; [Environment]::SetEnvironmentVariable('ELEVENLABS_API_KEY',[Net.NetworkCredential]::new('',$k).Password,'User')
```

İsteğe bağlı: `~/.claude/CLAUDE.md` dosyanıza "fotoğraf gerekince gemini-image, video gerekince gemini-video kullan…" gibi kısa bir not eklerseniz Claude bu skill'leri kendiliğinden seçer.

## Kullanım örnekleri

- "Karadeniz'de sisli bir sabah fotoğrafı yap, story için" → `gemini-image`
- "Bu fotoğrafı drone çekimi gibi 10 sn'lik videoya çevir" → `gemini-video`
- "Kızım için Türkçe sözlü bir doğum günü şarkısı yap" → `gemini-music`
- "60 saniyelik bir çocuk masalı reels'i yap, kadın anlatıcı olsun" → `gemini-reels`
- "Kafem için landing page tasarla" → `ui-design`
- "Bu projede lider ol, işi ajanlara dağıt" → `orchestration`

## Güvenlik ve maliyet kuralları (skill'lerin içinde)

- Şifre, kart veya API anahtarı **asla** Claude tarafından yazılmaz; anahtar ortam değişkeninden okunur, hiçbir yere yazdırılmaz.
- Kredi harcayan her adım (Flow Video, müzik videosu, 4K yükseltme, kredi satın alma) **önce maliyet söylenip onay alınmadan** yapılmaz; plan yükseltme düğmelerine hiç basılmaz.
- Hiçbir şey sizin adınıza yayınlanmaz; dosyalar size teslim edilir.

## Öğrenilmiş dersler

`gemini-reels/SKILL.md` içinde ilk testlerden çıkan kurallar var: anlatıcı sesinin müziğin en az 8 dB üstünde olması (ölçülerek), içeriğe uygun ses seçimi ve örnek dinletme, masallarda yavaş okuma, her sahnenin gerçek video olması, kelime kelime altyazı ve zamanlama doğrulaması, ortalanmış başlık.

---

## English summary

Media, UI and multi-agent orchestration skills for Claude Code. The media skills run on **your own subscriptions** (Google AI Pro, ElevenLabs) through your signed-in Chrome — no paid API keys.

- **gemini-image** — images in Google Flow (Nano Banana Pro, 0 credits), sizing for social formats, transparent PNG.
- **gemini-video** — Veo clips via Gemini, image-to-video, joining clips with ffmpeg, rolling 5-hour quota tracking.
- **gemini-music** — songs/instrumentals in Google Flow Music (Lyria 3.5).
- **elevenlabs-tts** — narration with character timestamps for exact subtitles.
- **gemini-reels** — end-to-end vertical Reels: script → 9:16 keyframes → Veo motion → voiceover → music → ffmpeg assembly with word-by-word subtitles, cover and caption.
- **ui-design** — anti-slop UI design with a two-pass design thesis and a real-browser desktop/mobile gate.
- **orchestration** — multi-agent project lead: Claude plans, briefs, measures, referees and merges while agy (Gemini) and Claude Code CLI agents do the work by role; background launcher + watcher, quality gate, quota ledger with fallback, task DAG scheduler, worktrees, merge train, dashboard; all state in `orchestrator/*.md`. Needs git, agy and the claude CLI.

Install: clone and run `install.ps1` (copies into `~/.claude/skills`, backs up existing ones). Requires Claude Code, the Claude in Chrome extension, Google AI Pro, ffmpeg, and an ElevenLabs API key for narration. Tested on Windows/PowerShell.

Not affiliated with Google, ElevenLabs or Anthropic. Follow each service's terms and content policies. MIT licensed.
