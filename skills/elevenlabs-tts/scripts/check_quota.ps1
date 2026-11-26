param(
    [int]$MaxVoices = 25
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

$apiKey = Resolve-ElevenLabsKey
$headers = @{
    "xi-api-key" = $apiKey
    "Accept"     = "application/json"
}

$sub = Invoke-RestMethod -Method Get -Uri "https://api.elevenlabs.io/v1/user/subscription" -Headers $headers
$voicesResp = Invoke-RestMethod -Method Get -Uri "https://api.elevenlabs.io/v1/voices" -Headers $headers

$remaining = [int]$sub.character_limit - [int]$sub.character_count
$voices = $voicesResp.voices | Select-Object -First $MaxVoices | ForEach-Object {
    [pscustomobject]@{
        voice_id    = $_.voice_id
        name        = $_.name
        category    = $_.category
        gender      = $_.labels.gender
        accent      = $_.labels.accent
        age         = $_.labels.age
        description = $_.labels.description
    }
}

[pscustomobject]@{
    subscription = [pscustomobject]@{
        tier            = $sub.tier
        character_count = $sub.character_count
        character_limit = $sub.character_limit
        remaining       = $remaining
    }
    voices       = $voices
} | ConvertTo-Json -Depth 4
