param(
    [string]$Text,
    [string]$TextFile,
    [Parameter(Mandatory = $true)][string]$VoiceId,
    [Parameter(Mandatory = $true)][string]$OutPath,
    [string]$ModelId = "eleven_multilingual_v2",
    [double]$Stability = 0.45,
    [double]$SimilarityBoost = 0.78,
    [double]$Style = 0.35,
    [string]$OutputFormat = "mp3_44100_128",
    [double]$Speed = 1.0
)

$ErrorActionPreference = "Stop"

function Resolve-ElevenLabsKey {
    if ($env:ELEVENLABS_API_KEY) { return $env:ELEVENLABS_API_KEY.Trim() }
    $userKey = [Environment]::GetEnvironmentVariable("ELEVENLABS_API_KEY", "User")
    if ($userKey) { return $userKey.Trim() }
    $envFile = Join-Path (Split-Path -Parent $PSScriptRoot) ".env"
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile -Encoding UTF8) {
            if ($line -match '^\s*ELEVENLABS_API_KEY\s*=\s*(.+?)\s*$') {
                return $Matches[1].Trim('"', "'")
            }
        }
    }
    throw "ELEVENLABS_API_KEY is not set. Set it via [Environment]::SetEnvironmentVariable('ELEVENLABS_API_KEY','<KEY>','User') or in $envFile."
}

if ($TextFile) {
    if (-not (Test-Path $TextFile)) { throw "TextFile not found: $TextFile" }
    $Text = Get-Content $TextFile -Raw -Encoding UTF8
}
if ([string]::IsNullOrWhiteSpace($Text)) {
    throw "Provide -Text or -TextFile with non-empty text."
}
$Text = $Text.Trim()

$apiKey = Resolve-ElevenLabsKey
$outDir = Split-Path -Parent $OutPath
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$uri = "https://api.elevenlabs.io/v1/text-to-speech/$VoiceId/with-timestamps?output_format=$OutputFormat"
$headers = @{
    "xi-api-key" = $apiKey
    "Accept"     = "application/json"
}

if ($ModelId -eq "eleven_v3" -and ($Stability -notin @(0.0, 0.5, 1.0))) {
    $Stability = if ($Stability -lt 0.25) { 0.0 } elseif ($Stability -lt 0.75) { 0.5 } else { 1.0 }
}

$voiceSettings = @{
    stability        = $Stability
    similarity_boost = $SimilarityBoost
}
if ($ModelId -ne "eleven_v3") {
    $voiceSettings["style"] = $Style
}
if ($Speed -ne 1.0) {
    $voiceSettings["speed"] = [math]::Max(0.7, [math]::Min(1.2, $Speed))
}

$payload = @{
    text           = $Text
    model_id       = $ModelId
    voice_settings = $voiceSettings
} | ConvertTo-Json -Depth 5

$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $bodyBytes -ContentType "application/json; charset=utf-8"

if (-not $response.audio_base64) {
    throw "ElevenLabs response missing audio_base64."
}

$audioBytes = [Convert]::FromBase64String($response.audio_base64)
[IO.File]::WriteAllBytes($OutPath, $audioBytes)

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$alignPath = "$OutPath.alignment.json"
$alignObj = if ($response.alignment) { $response.alignment } else { $response.normalized_alignment }
if ($null -eq $alignObj) {
    Write-Warning "ElevenLabs response returned no alignment data; writing empty JSON object."
    $alignJson = "{}"
} else {
    $alignJson = $alignObj | ConvertTo-Json -Depth 6
}
[IO.File]::WriteAllText($alignPath, $alignJson, $utf8NoBom)

$sidecarPath = "$OutPath.prompt.txt"
$sidecar = @"
VoiceId: $VoiceId
ModelId: $ModelId
OutputFormat: $OutputFormat
Stability: $Stability
SimilarityBoost: $SimilarityBoost
Style: $Style
Chars: $($Text.Length)
Generated: $(Get-Date -Format s) via ElevenLabs REST API (/with-timestamps)
Text:
$Text
"@
[IO.File]::WriteAllText($sidecarPath, $sidecar, $utf8NoBom)

$dur = $null
try {
    $durStr = & ffprobe -v error -show_entries format=duration -of csv=p=0 $OutPath 2>$null
    if ($durStr) { $dur = [math]::Round([double]$durStr, 3) }
} catch {}

[pscustomobject]@{
    file           = $OutPath
    duration_s     = $dur
    chars          = $Text.Length
    alignment_file = $alignPath
    sidecar_file   = $sidecarPath
} | ConvertTo-Json -Depth 3
