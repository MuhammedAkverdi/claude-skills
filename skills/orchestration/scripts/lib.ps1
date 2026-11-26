# Shared helpers for the orchestration scripts. Dot-source:  . "$PSScriptRoot\lib.ps1"
# ASCII only (Windows PowerShell 5.1 reads BOM-less scripts as ANSI).

$script:Utf8 = New-Object System.Text.UTF8Encoding $false
$script:SkillRoot = Split-Path -Parent $PSScriptRoot
try { [Console]::OutputEncoding = $script:Utf8 } catch {}       # native UTF-8 output (git paths with non-ASCII chars)

function Read-Json([string]$Path) {
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  for ($i = 0; $i -lt 5; $i++) {
    try { return ([IO.File]::ReadAllText($Path, $script:Utf8) | ConvertFrom-Json) } catch { Start-Sleep -Milliseconds 100 }
  }
  return $null
}
function Write-Json($Obj, [string]$Path) {          # atomic, unique temp, UTF-8 without BOM, arrays kept as arrays
  $tmp = "$Path.$PID.$([guid]::NewGuid().ToString('N').Substring(0,8)).tmp"
  $json = ConvertTo-Json -InputObject $Obj -Depth 10
  if ($null -eq $json -or $json -eq '') { $json = '[]' }
  [IO.File]::WriteAllText($tmp, $json, $script:Utf8)
  for ($i = 0; $i -lt 10; $i++) { try { Move-Item -LiteralPath $tmp -Destination $Path -Force -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 100 } }
  Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
  throw "Could not write $Path"
}
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $script:Utf8) }
function Use-Lock([string]$Name, [scriptblock]$Body) {   # cross-process lock for shared files (quota.json, metrics.jsonl, tasks.json)
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Name.ToLowerInvariant()))).Replace('-', '')
  $sha.Dispose()
  $m = New-Object System.Threading.Mutex -ArgumentList $false, "Global\orch-$hash"
  [void]$m.WaitOne(10000)
  try { & $Body } finally { try { $m.ReleaseMutex() } catch {}; $m.Dispose() }
}
function Add-Line([string]$Path, [string]$Line) { Use-Lock $Path { [IO.File]::AppendAllText($Path, $Line + "`r`n", $script:Utf8) } }
function Q([string]$s) { "'" + $s.Replace("'", "''") + "'" }

function Test-Alive($s) {
  if (-not $s -or -not $s.pid) { return $null }
  $p = Get-Process -Id $s.pid -ErrorAction SilentlyContinue
  if (-not $p) { return $false }
  if ($s.pidStart) { try { return ($p.StartTime.ToString('o') -eq $s.pidStart) } catch { return $true } }
  return $true
}

function Get-Team([string]$Orch) {
  $f = Join-Path $Orch 'team.json'
  if (-not (Test-Path -LiteralPath $f)) { Copy-Item -LiteralPath (Join-Path $script:SkillRoot 'templates\team.json') -Destination $f }
  $t = Read-Json $f
  if (-not $t) { throw "team.json is not valid JSON: $f" }
  return $t
}
function Get-Limit($Team, [string]$Key, $Default) { if ($Team.limits -and $null -ne $Team.limits.$Key) { return $Team.limits.$Key } else { return $Default } }

function Get-StatusList([string]$Orch) {
  $dir = Join-Path $Orch 'status'
  $list = @()
  Get-ChildItem -LiteralPath $dir -Filter *.json -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '.*' -and $_.Name -notlike '*.settings.json' -and $_.Name -ne 'quota.json' } |
    ForEach-Object { $s = Read-Json $_.FullName; if ($s -and $s.name) { $s | Add-Member -NotePropertyName _file -NotePropertyValue $_.FullName -Force; $list += $s } }
  return $list
}

# ---- quota ledger: orchestrator/status/quota.json  { "<model>": { "until": iso|null, "reason": "", "limitedAt": iso } }
function Get-QuotaFile([string]$Orch) { Join-Path $Orch 'status\quota.json' }
# quota group of a model (team.json "quotaGroups": { "agy-neon": ["gemini-4-neon-*"], ... }) - limits hit whole families
function Get-QuotaGroup($Team, [string]$Model) {
  if ($Team -and $Team.quotaGroups) {
    foreach ($p in $Team.quotaGroups.PSObject.Properties) { foreach ($pat in @($p.Value)) { if ($Model -like $pat) { return "group:$($p.Name)" } } }
  }
  return $null
}
function Get-Cooldown([string]$Orch, [string]$Model, $Team = $null) {
  $q = Read-Json (Get-QuotaFile $Orch)
  if (-not $q) { return $null }
  $keys = @($Model); $g = Get-QuotaGroup $Team $Model; if ($g) { $keys += $g }
  $best = $null
  foreach ($k in $keys) {
    if ($q.$k -and $q.$k.until) { $u = [datetime]$q.$k.until; if ($u -gt (Get-Date) -and (-not $best -or $u -gt $best)) { $best = $u } }
  }
  return $best
}
# Claude account utilization from rate_limit_event (five_hour / seven_day), stored by run-agent.ps1
function Get-ClaudeUsage([string]$Orch) { $q = Read-Json (Get-QuotaFile $Orch); if ($q -and $q.'claude-usage') { return $q.'claude-usage' } else { return $null } }
function Set-Cooldown([string]$Orch, [string]$Model, [datetime]$Until, [string]$Reason) {
  $f = Get-QuotaFile $Orch
  Use-Lock $f {
    $q = Read-Json $f; if (-not $q) { $q = New-Object psobject }
    $entry = [pscustomobject]@{ until = $Until.ToString('s'); reason = $Reason; limitedAt = (Get-Date).ToString('s') }
    $q | Add-Member -NotePropertyName $Model -NotePropertyValue $entry -Force
    Write-Json $q $f
  }
}
function Clear-Cooldown([string]$Orch, [string]$Model, $Team = $null) {
  $f = Get-QuotaFile $Orch
  $keys = @($Model); $g = Get-QuotaGroup $Team $Model; if ($g) { $keys += $g }
  Use-Lock $f { $q = Read-Json $f; $ch = $false; foreach ($k in $keys) { if ($q -and $q.$k) { $q.PSObject.Properties.Remove($k); $ch = $true } }; if ($ch) { Write-Json $q $f } }
}
function Set-QuotaValue([string]$Orch, [string]$Key, $Value) {
  $f = Get-QuotaFile $Orch
  Use-Lock $f { $q = Read-Json $f; if (-not $q) { $q = New-Object psobject }; $q | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force; Write-Json $q $f }
}

# Zero-token digest of one run's stream-json log (used by inspect-run.ps1 and resume-agent.ps1)
function Get-RunDigest($s) {
  $d = [ordered]@{ turns = 0; tools = @{}; toolErrors = 0; denials = @(); errors = @(); lastText = @(); tokensIn = 0; tokensOut = 0; logKB = 0 }
  if (-not (Test-Path -LiteralPath $s.log)) { return [pscustomobject]$d }
  $d.logKB = [int]((Get-Item -LiteralPath $s.log).Length / 1KB)
  $text = New-Object System.Text.StringBuilder
  foreach ($l in [IO.File]::ReadLines($s.log)) {
    if ($l -notmatch '^\s*\{') { if ($l.Trim()) { $d.errors += $l.Trim() }; continue }
    try { $o = $l | ConvertFrom-Json } catch { continue }
    if ($o.type -eq 'assistant' -and $o.message) {
      $d.turns++
      foreach ($c in @($o.message.content)) {
        if ($c.type -eq 'tool_use') { $n = [string]$c.name; if ($c.input.command) { $n = "$n($($c.input.command))" }; $d.tools[$n] = 1 + [int]$d.tools[$n] }
        elseif ($c.type -eq 'text') { [void]$text.Append($c.text + "`n") }
      }
    } elseif ($o.type -eq 'user' -and $o.message) {
      foreach ($c in @($o.message.content)) { if ($c.type -eq 'tool_result' -and $c.is_error) { $d.toolErrors++ } }
    } elseif ($o.type -eq 'result') {
      if ($o.usage) { $d.tokensIn = [int]$o.usage.input_tokens + [int]$o.usage.cache_read_input_tokens + [int]$o.usage.cache_creation_input_tokens; $d.tokensOut = [int]$o.usage.output_tokens }
      foreach ($pd in @($o.permission_denials)) { if ($pd) { $d.denials += [string]$(if ($pd.tool_input.command) { $pd.tool_input.command } else { $pd.tool_name }) } }
    } elseif ($o.event -eq 'step_update' -and $o.step_update) {
      $su = $o.step_update
      if ($su.step_type -eq 'agent_response' -and $su.text_delta) { [void]$text.Append($su.text_delta) }
      elseif ($su.state -eq 'DONE' -and $su.step_type -and $su.step_type -notin @('user_input','agent_response','unknown')) { $d.tools[$su.step_type] = 1 + [int]$d.tools[$su.step_type] }
      if ($su.state -eq 'DONE' -and $su.step_type -and $su.step_type -ne 'user_input') { $d.turns++ }
      if ($su.usage) { $d.tokensIn += [int]$su.usage.input_tokens; $d.tokensOut += [int]$su.usage.output_tokens }
    } elseif ($o.event -eq 'result' -and $o.result) {
      if ($o.result.usage) { $d.tokensIn = [int]$o.result.usage.input_tokens; $d.tokensOut = [int]$o.result.usage.output_tokens }
      if ($o.result.response) { $text.Clear() | Out-Null; [void]$text.Append([string]$o.result.response) }
    }
  }
  $d.lastText = @(($text.ToString() -split "`n") | Where-Object { $_.Trim() } | Select-Object -Last 10)
  $d.errors = @($d.errors | Select-Object -Last 5)
  return [pscustomobject]$d
}

# Automatic event journal (orchestrator/events.md): written by the SCRIPTS, so project history survives even if the
# lead forgets to update the handoff before a context reset. status-board -LeadPacket shows the latest entries.
function Add-Event([string]$Orch, [string]$Text) {
  try {
    $f = Join-Path $Orch 'events.md'
    if (-not (Test-Path -LiteralPath $f)) { Write-Text $f "# Events (automatic - written by the orchestration scripts, newest last)`r`n" }
    Add-Line $f ("- " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " " + $Text)
  } catch {}
}

# Run a PowerShell command string safely (quotes preserved) in a directory; returns exit code + output
function Invoke-Cmd([string]$Dir, [string]$Command) {
  $wrapped = "`$ErrorActionPreference='Continue'; $Command; exit `$LASTEXITCODE"
  $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapped))
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  Push-Location -LiteralPath $Dir
  try { $out = & powershell.exe -NoProfile -NonInteractive -EncodedCommand $b64 2>&1 | ForEach-Object { "$_" }; $code = $LASTEXITCODE }
  finally { Pop-Location; $ErrorActionPreference = $prev }
  return [pscustomobject]@{ code = $code; out = $out }
}

# Update one task in orchestrator/tasks.json under a lock
function Set-TaskStatus([string]$Orch, [string]$TaskId, [string]$Status, [string]$Agent) {
  if (-not $TaskId) { return }
  $f = Join-Path $Orch 'tasks.json'
  if (-not (Test-Path -LiteralPath $f)) { return }
  Use-Lock $f {
    $doc = Read-Json $f
    $t = @($doc.tasks) | Where-Object { $_.id -eq $TaskId } | Select-Object -First 1
    if ($t) {
      if ($Status) { $t.status = $Status }
      if ($Agent) { $t | Add-Member -NotePropertyName agent -NotePropertyValue $Agent -Force }
      $t | Add-Member -NotePropertyName updated -NotePropertyValue (Get-Date).ToString('s') -Force
      Write-Json $doc $f
      Add-Event $Orch "TASK $TaskId -> $($t.status)$(if ($Agent) { " ($Agent)" })"
    }
  }
}

# ---- security scan for briefs / context files
function Find-Secrets([string]$Text) {
  $hits = @()
  $patterns = @{
    'private hidden-checks folder' = 'orchestrator-private'
    'OpenAI/Anthropic-style key'   = '\b(sk|sk-ant)-[A-Za-z0-9_-]{20,}'
    'AWS access key'               = '\bAKIA[0-9A-Z]{16}\b'
    'Google API key'               = '\bAIza[0-9A-Za-z_-]{35}\b'
    'GitHub token'                 = '\bgh[pousr]_[A-Za-z0-9]{30,}'
    'private key block'            = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'password assignment'          = '(?i)\b(password|passwd|pwd)\s*[:=]\s*\S{4,}'
  }
  foreach ($k in $patterns.Keys) { if ($Text -match $patterns[$k]) { $hits += $k } }
  return $hits
}

# ---- simple glob helpers (forward slashes, case-insensitive)
function Norm([string]$p) { ($p.Replace('\', '/') -replace '^(\./)+', '').ToLowerInvariant() }
function Test-InScope([string]$File, [string[]]$Globs) {
  if (-not $Globs -or $Globs.Count -eq 0) { return $true }
  $f = Norm $File
  foreach ($g in $Globs) { $gg = Norm $g; if ($f -like $gg -or $f -like "$gg/*" -or $f -like ($gg.TrimEnd('*').TrimEnd('/') + '/*')) { return $true } }
  return $false
}
function Get-GlobPrefix([string]$g) { $n = Norm $g; $i = $n.IndexOfAny([char[]]'*?['); if ($i -ge 0) { $n.Substring(0, $i) } else { $n } }
function Test-GlobOverlap([string[]]$A, [string[]]$B) {
  if (-not $A -or -not $B) { return $true }              # unknown files -> assume overlap (safe)
  foreach ($a in $A) { foreach ($b in $B) {
    $pa = Get-GlobPrefix $a; $pb = Get-GlobPrefix $b
    if ($pa.StartsWith($pb) -or $pb.StartsWith($pa)) { return $true }
  } }
  return $false
}

function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
  # PS 5.1: native stderr + 2>&1 raises NativeCommandError under ErrorActionPreference=Stop -> run with Continue
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $out = & git -c core.quotepath=false -C $Dir @GitArgs 2>&1 | ForEach-Object { "$_" }; $code = $LASTEXITCODE }
  finally { $ErrorActionPreference = $prev }
  return [pscustomobject]@{ code = $code; out = $out }
}
