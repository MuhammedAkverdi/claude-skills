# Installs the claude-skills into %USERPROFILE%\.claude\skills (backs up any skill with the same name first).
# Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Only gemini-image,gemini-music] [-Target <folder>]
param(
    [string[]]$Only,
    [string]$Target = (Join-Path $env:USERPROFILE '.claude\skills')
)
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'skills'
$names = Get-ChildItem $src -Directory | Select-Object -ExpandProperty Name
if ($Only) {
    $Only = $Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }   # "-File" passes "a,b" as one string
    $names = $names | Where-Object { $Only -contains $_ }
}
if (-not $names) { throw "No matching skills in $src" }

New-Item -ItemType Directory -Force $Target | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path (Split-Path $Target -Parent) "skills-backup-$stamp"

foreach ($n in $names) {
    $dst = Join-Path $Target $n
    if (Test-Path $dst) {
        New-Item -ItemType Directory -Force $backup | Out-Null
        [System.IO.Directory]::Move($dst, (Join-Path $backup $n))   # .NET move also works with 8.3 short paths
        Write-Host "backed up existing $n -> $backup"
    }
    Copy-Item (Join-Path $src $n) $dst -Recurse
    Write-Host "installed $n"
}

$missing = @()
foreach ($tool in 'ffmpeg', 'ffprobe') { if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool } }
if ($missing) { Write-Warning "Not found on PATH: $($missing -join ', ') (needed for video/audio/Reels)." }
if (($names -contains 'elevenlabs-tts') -and -not ([Environment]::GetEnvironmentVariable('ELEVENLABS_API_KEY', 'User') -or $env:ELEVENLABS_API_KEY)) {
    Write-Warning "ELEVENLABS_API_KEY is not set (only needed for elevenlabs-tts; local-tts is free). See README."
}
if ($names -contains 'orchestration') {
    $noCli = @('agy', 'claude', 'git') | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
    if ($noCli) { Write-Warning "orchestration: not found on PATH: $($noCli -join ', ') (agents run through the agy and claude CLIs)." }
}
if ($names -contains 'local-tts') {
    if (-not (Test-Path (Join-Path $env:USERPROFILE '.local-tts\venv\Scripts\python.exe'))) {
        Write-Host "local-tts: run once to install the free voices (~1.5 GB): powershell -ExecutionPolicy Bypass -File `"$Target\local-tts\scripts\setup.ps1`" -Warmup"
    }
}
Write-Host "Done. Restart Claude Code so it picks up the new skills."
