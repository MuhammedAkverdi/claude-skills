# One-time setup for local-tts: a separate Python venv with yazgi-tts-1, Supertonic 3 and faster-whisper (CPU only).
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1 [-Warmup]
#   -Warmup  also downloads the models now (~0.6 GB yazgi + ~0.4 GB Supertonic + ~0.5 GB whisper small)
param([switch]$Warmup, [string]$Root = (Join-Path $env:USERPROFILE ".local-tts"))
$ErrorActionPreference = "Stop"

$venv = Join-Path $Root "venv"
$py = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $py)) {
    $base = Get-Command python -ErrorAction SilentlyContinue
    if (-not $base) { throw "Python 3.11-3.12 not found on PATH (install it from python.org)." }
    $ver = & $base.Source -c "import sys; print('%d.%d' % sys.version_info[:2])"
    if ([version]$ver -lt [version]"3.11") { throw "Python $ver found; 3.11 or newer is needed." }
    New-Item -ItemType Directory -Force $Root | Out-Null
    & $base.Source -m venv $venv
}
& $py -m pip install -q --upgrade pip
& $py -m pip install -q torch --index-url https://download.pytorch.org/whl/cpu
& $py -m pip install -q "yazgi-tts[hub] @ https://huggingface.co/erkamk/yazgi-tts-1/resolve/main/dist/yazgi_tts-0.1.0-py3-none-any.whl" supertonic faster-whisper soundfile numpy
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Write-Warning "ffmpeg/ffprobe not on PATH - needed for MP3 output and timings." }

if ($Warmup) {
    $env:PYTHONIOENCODING = "utf-8"
    & $py -c "from yazgi_tts import YazgiTTS; YazgiTTS(); from supertonic import TTS; TTS(auto_download=True); from faster_whisper import WhisperModel; WhisperModel('small', device='cpu', compute_type='int8'); print('models ready')"
}
Write-Host "local-tts ready: $py"
