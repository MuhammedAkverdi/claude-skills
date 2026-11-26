<#
  Runner started by launch-agent.ps1 (hidden). Do not call directly.
  Streams the engine output into the log, keeps status.lastOutput fresh, enforces the timeout with a watchdog,
  classifies the end state, extracts the report, updates quota ledger / tasks.json / metrics, runs the gate on DONE,
  and refreshes dashboard.html.
#>
param([Parameter(Mandatory)][string]$StatusFile)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
[Console]::OutputEncoding = $script:Utf8; [Console]::InputEncoding = $script:Utf8; $OutputEncoding = $script:Utf8

$s = Read-Json $StatusFile
$s.pid = $PID; $s.pidStart = (Get-Process -Id $PID).StartTime.ToString('o'); Write-Json $s $StatusFile
$orch = $s.orch; $team = Get-Team $orch
$runStart = Get-Date
Set-Location -LiteralPath $s.workdir
[Environment]::CurrentDirectory = $s.workdir
Write-Text $s.log ''

# ---- watchdog: after timeoutMin + 2 min mark 'timeout' (if still this run) and kill the whole process tree
$wdSec = ([int]$s.timeoutMin + 2) * 60
$wd = @"
Start-Sleep -Seconds $wdSec
`$u = New-Object System.Text.UTF8Encoding `$false
try { `$j = [IO.File]::ReadAllText('$($StatusFile.Replace("'","''"))', `$u) | ConvertFrom-Json } catch { exit }
if (`$j.state -eq 'running' -and `$j.runId -eq '$($s.runId)') {
  `$j.state = 'timeout'; `$j.reason = 'watchdog: exceeded $($s.timeoutMin) min, process tree killed'; `$j.ended = (Get-Date).ToString('s')
  [IO.File]::WriteAllText('$($StatusFile.Replace("'","''"))', (ConvertTo-Json -InputObject `$j -Depth 10), `$u)
  & taskkill.exe /PID $PID /T /F | Out-Null
}
"@
$wdProc = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile','-EncodedCommand',([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wd)))

$lines = New-Object System.Collections.Generic.List[string]
$lastTouch = [datetime]::MinValue
$exe = $s.exe
# PS 5.1 does not escape embedded double quotes for native programs: escape them the CommandLineToArgvW way
$argv = @($s.argv | ForEach-Object { if ($_ -match '"') { $_ -replace '(\\*)"', '$1$1\"' } else { $_ } })

# ---- live budgets / loop detection (lesson from an earlier project: an agent spun 7 rounds on one task until its quota ended)
$mt = Get-Limit $team 'maxTurns' $null
$maxTurns = if ($mt -and $mt.($s.role)) { [int]$mt.($s.role) } elseif ($mt -is [int]) { [int]$mt } else { 60 }
$maxLogBytes = [long]([double](Get-Limit $team 'maxLogMB' 3) * 1MB)
$maxRepeat = [int](Get-Limit $team 'maxRepeatErrors' 3)
$maxDeny = [int](Get-Limit $team 'maxConsecutiveDenials' 3)
$script:bud = @{ turns = 0; bytes = 0L; deny = 0; lastErr = ''; rep = 0; kill = $null; tokIn = 0; tokOut = 0 }
function Stop-Run([string]$why) {
  if ($script:bud.kill) { return }
  $script:bud.kill = $why
  Get-CimInstance Win32_Process -Filter "ParentProcessId=$PID" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'conhost.exe' } |
    ForEach-Object { & taskkill.exe /PID $_.ProcessId /T /F 2>&1 | Out-Null }
}
function Watch-Line([string]$line) {
  $script:bud.bytes += $line.Length
  if ($line -notmatch '^\s*\{') { return }
  try { $o = $line | ConvertFrom-Json } catch { return }
  $errSig = $null; $edited = $false
  if ($o.type -eq 'assistant' -and $o.message) {
    $script:bud.turns++
    foreach ($c in @($o.message.content)) { if ($c.type -eq 'tool_use' -and $c.name -in @('Edit','Write','MultiEdit','NotebookEdit')) { $edited = $true } }
  } elseif ($o.type -eq 'user' -and $o.message) {
    foreach ($c in @($o.message.content)) {
      if ($c.type -eq 'tool_result' -and $c.is_error) {
        $t = [string]$(if ($c.content -is [string]) { $c.content } else { ($c.content | ForEach-Object { $_.text }) -join ' ' })
        if ($t -match '(?i)permission|requires approval|not allowed|denied') { $script:bud.deny++ } else { $errSig = ($t -replace '\d+', 'N' -replace '\s+', ' ').Substring(0, [Math]::Min(160, $t.Length)) }
      } elseif ($c.type -eq 'tool_result') { $script:bud.deny = 0 }
    }
  } elseif ($o.event -eq 'step_update' -and $o.step_update) {
    $su = $o.step_update
    if ($su.state -eq 'DONE' -and $su.step_type -and $su.step_type -ne 'user_input') { $script:bud.turns++ }   # every finished agent/tool step
    if ($su.usage) { $script:bud.tokIn += [int]$su.usage.input_tokens; $script:bud.tokOut += [int]$su.usage.output_tokens }
    if ($su.state -eq 'ERROR' -or $su.error) { $errSig = ("$($su.step_type) $($su.error)" -replace '\d+', 'N').Trim() }
    if ($su.state -eq 'DONE' -and $su.step_type -match '(?i)edit|write|replace|create') { $edited = $true }
  } elseif ($o.type -eq 'result' -and $o.usage) {
    $script:bud.tokIn = [int]$o.usage.input_tokens + [int]$o.usage.cache_read_input_tokens + [int]$o.usage.cache_creation_input_tokens; $script:bud.tokOut = [int]$o.usage.output_tokens
  }
  if ($edited) { $script:bud.rep = 0; $script:bud.lastErr = '' }
  if ($errSig) { if ($errSig -eq $script:bud.lastErr) { $script:bud.rep++ } else { $script:bud.lastErr = $errSig; $script:bud.rep = 1 } }
  if ($script:bud.turns -gt $maxTurns) { Stop-Run "budget: more than $maxTurns turns" }
  elseif ($script:bud.bytes -gt $maxLogBytes) { Stop-Run "budget: log larger than $([int]($maxLogBytes / 1MB)) MB (output hygiene ignored?)" }
  elseif ($script:bud.deny -ge $maxDeny) { Stop-Run "denied: $maxDeny denied tool calls in a row" }
  elseif ($script:bud.rep -ge $maxRepeat) { Stop-Run "loop: same error $maxRepeat times without an edit - $($script:bud.lastErr)" }
}

& $exe @argv 2>&1 | ForEach-Object {
  $line = "$_"
  $lines.Add($line)
  Add-Line $s.log $line
  Watch-Line $line
  if (((Get-Date) - $lastTouch).TotalSeconds -ge 15) {
    $lastTouch = Get-Date
    $cur = Read-Json $StatusFile
    if ($cur -and $cur.state -eq 'running') { $cur.lastOutput = $lastTouch.ToString('s'); $cur | Add-Member -NotePropertyName turns -NotePropertyValue $script:bud.turns -Force; Write-Json $cur $StatusFile }
  }
}
$code = $LASTEXITCODE
if ($wdProc) { Stop-Process -Id $wdProc.Id -Force -ErrorAction SilentlyContinue }

# ---- parse engine result (assistant text only; plain = non-JSON lines such as CLI errors)
$answer = ''; $engineError = $null; $resetAt = $null; $limitedHint = $false; $denials = @(); $claudeUsage = $null
$plain = New-Object System.Collections.Generic.List[string]
foreach ($l in $lines) {
  if ($l -notmatch '^\s*\{') { $plain.Add($l); continue }
  try { $o = $l | ConvertFrom-Json } catch { continue }
  if ($s.engine -eq 'claude') {
    if ($o.type -eq 'result') {
      $answer = [string]$o.result
      if ($o.is_error) { $engineError = "$($o.subtype) $($o.result)" }
      if ($o.permission_denials) { $denials += @($o.permission_denials | ForEach-Object { if ($_.tool_input.command) { "Bash($($_.tool_input.command))" } else { [string]$_.tool_name } }) }
    }
    elseif ($o.type -eq 'rate_limit_event' -and $o.rate_limit_info) {
      $ri = $o.rate_limit_info
      if ($ri.resetsAt) { $resetAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$ri.resetsAt).LocalDateTime }
      if ($ri.status -eq 'rejected') { $limitedHint = $true; $engineError = "rate limit $($ri.rateLimitType) rejected" }
      if ($ri.unifiedWindows) {      # remember account utilization for the Claude reserve rule
        $uw = [ordered]@{ at = (Get-Date).ToString('s') }
        foreach ($wn in 'five_hour','seven_day') { $w = $ri.unifiedWindows.$wn; if ($w) { $uw[$wn] = [ordered]@{ utilization = $w.utilization; status = $w.status; resetsAt = $(if ($w.resetsAt) { [DateTimeOffset]::FromUnixTimeSeconds([long]$w.resetsAt).LocalDateTime.ToString('s') } else { $null }) } } }
        $claudeUsage = $uw
      }
    }
  } else {
    if ($o.event -eq 'result' -and $o.result) {
      $answer = [string]$o.result.response
      if ($o.result.status -and $o.result.status -ne 'SUCCESS') { $engineError = "$($o.result.status) $($o.result.error)" }
    }
  }
}
$errText = (@($engineError) + @($plain | Select-Object -Last 40)) -join "`n"

# ---- report: file written this run, else an anchored BEGIN/END block from the assistant answer
$rep = Get-Item -LiteralPath $s.report -ErrorAction SilentlyContinue
$fresh = $rep -and $rep.LastWriteTime -ge $runStart -and $rep.Length -gt 0
if (-not $fresh -and $answer -match '(?ms)^\s*BEGIN_REPORT\s*\r?\n(.+?)\r?\n\s*END_REPORT\s*$') { Write-Text $s.report $Matches[1]; $fresh = $true }

# ---- classify (patterns only against engine errors + non-JSON output, never against the agent's own text)
$state = 'done'; $reason = $null
if ($claudeUsage) { Set-QuotaValue $orch 'claude-usage' $claudeUsage }
if ($script:bud.kill) {
  $k = $script:bud.kill
  $state = if ($k -like 'loop:*') { 'loop' } elseif ($k -like 'denied:*') { 'denied' } else { 'budget' }
  $reason = $k
}
elseif ((Get-Content -LiteralPath $StatusFile -Raw -ErrorAction SilentlyContinue) -match '"state":\s*"timeout"') { $state = 'timeout'; $reason = 'watchdog timeout' }
elseif ($code -eq 0 -and $fresh -and -not $engineError) { }
elseif ($errText -match '(?i)required the "([a-z_]+)" permission that headless mode cannot prompt') { $state = 'denied'; $reason = "tool '$($Matches[1])' auto-denied (allow the exact command or change the brief)" }
elseif ($denials.Count -gt 0 -and -not $fresh) { $state = 'denied'; $reason = "denied: " + (($denials | Select-Object -Unique) -join ', ') }
elseif ($limitedHint) { $state = 'limited'; $reason = $engineError }
elseif ($errText -match '(?i)(Authentication required|not authenticated|login required|unauthenticated|invalid api key|please run /login)') { $state = 'auth'; $reason = $Matches[1] }
elseif ($errText -match '(?i)(RESOURCE_EXHAUSTED|MODEL_CAPACITY_EXHAUSTED|No capacity available|OWN_ACCOUNT_LIMITED|rate.?limit.?(exceeded|reached)|usage limit|quota (exceeded|exhausted)|HTTP 429|code 429|HTTP 503|code 503|full capacity)') { $state = 'limited'; $reason = $Matches[1] }
elseif ($errText -match '(?i)(print-timeout|deadline exceeded|timed out waiting)') { $state = 'timeout'; $reason = $Matches[1] }
elseif ($code -ne 0 -or $engineError) { $state = 'failed'; $reason = if ($engineError) { $engineError } else { "exit $code" } }
elseif (-not $fresh) { $state = 'incomplete'; $reason = 'exit 0 but no fresh report' }
if ($state -eq 'done' -and $denials.Count -gt 0) { $reason = "note - denied during run: " + (($denials | Select-Object -Unique) -join ', ') }

# ---- quota ledger
if ($state -eq 'limited') {
  $until = if ($resetAt -and $resetAt -gt (Get-Date)) { $resetAt } else { (Get-Date).AddMinutes([int](Get-Limit $team 'cooldownMin' 300)) }
  Set-Cooldown $orch $s.model $until $reason
  $grp = Get-QuotaGroup $team $s.model; if ($grp) { Set-Cooldown $orch $grp $until "$reason (via $($s.model))" }
} elseif ($state -eq 'done') { Clear-Cooldown $orch $s.model $team }

# ---- gate
$gateResult = $null
if ($state -eq 'done' -and (@($s.scope).Count -gt 0 -or @($s.gateCommands).Count -gt 0 -or $s.role -in @('tester','auditor','researcher'))) {
  $gateOut = & "$PSScriptRoot\verify-run.ps1" -StatusFile $StatusFile 2>&1 | ForEach-Object { "$_" }
  $gateResult = if (($gateOut -join "`n") -match 'GATE (PASS|FAIL)') { $Matches[1].ToLowerInvariant() } else { 'error' }
}

# ---- final status (re-read: the watcher may have touched it)
$cur = Read-Json $StatusFile
if ($cur.state -ne 'running' -and $cur.state -ne $state) { $reason = "$reason (watcher/watchdog had marked: $($cur.state) - $($cur.reason))" }
$cur.state = $state; $cur.reason = $reason
$cur.ended = (Get-Date).ToString('s'); $cur.exit = $code; $cur.gate = $gateResult
$cur.lastOutput = (Get-Date).ToString('s')
Write-Json $cur $StatusFile

$commit = $null; if ($s.baseSha) { $commit = ((Invoke-Git $s.workdir @('log','-1','--format=%h %s',"$($s.baseSha)..HEAD")).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal)' } | Select-Object -First 1) }
Add-Event $orch ("END $($s.name) [$($s.role)] $state" + $(if ($gateResult) { " gate=$gateResult" } else { '' }) + $(if ($reason) { " - $reason" } else { '' }) + $(if ($commit) { " - commit $commit" } else { '' }))

# ---- tasks.json
if ($s.taskId) {
  $ts = if ($state -eq 'done' -and $gateResult -ne 'fail') { 'review' } else { 'pending' }
  Set-TaskStatus $orch $s.taskId $ts $s.name
}

# ---- metrics
$changed = 0
if ($s.baseSha) {
  $d = Invoke-Git $s.workdir @('diff','--name-only',$s.baseSha)
  if ($d.code -eq 0) { $changed = @($d.out | Where-Object { $_ -and -not (Norm $_).StartsWith('orchestrator/') }).Count }
}
$metric = [ordered]@{ ts = (Get-Date).ToString('s'); name = $s.name; runId = $s.runId; role = $s.role; engine = $s.engine; model = $s.model
  taskId = $s.taskId; taskType = $s.taskType; attempt = $s.attempt; state = $state; reason = $reason; gate = $gateResult
  durationSec = [int]((Get-Date) - $runStart).TotalSeconds; filesChanged = $changed
  turns = $script:bud.turns; logKB = [int]($script:bud.bytes / 1KB); tokensIn = $script:bud.tokIn; tokensOut = $script:bud.tokOut
  reportLines = $(if (Test-Path -LiteralPath $s.report) { @(Get-Content -LiteralPath $s.report).Count } else { 0 }) }
Add-Line (Join-Path $orch 'metrics.jsonl') (ConvertTo-Json -InputObject $metric -Compress)

# ---- dashboard
& "$PSScriptRoot\status-board.ps1" -Orch $orch *> $null
