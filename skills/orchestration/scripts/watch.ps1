<#
  Watch orchestrator/status/*.json and exit on the first change, so the lead (running this with run_in_background) is woken.
  watch.ps1 [-Orch orchestrator] [-PollSec 10] [-HeartbeatMin 45]
  Prints:  EVENT <name> <STATE> [gate=pass|fail] [reason]   (DONE, INCOMPLETE, DENIED, LOOP, BUDGET, FAILED, LIMITED, AUTH, TIMEOUT, STALLED)
           Events finishing within limits.coalesceSec of each other are reported together (one wake-up).
           RUNNING: a, b     HEARTBEAT a[12m, idle 3m]     IDLE (no running agents)
  STALLED = runner gone, never started, no output for limits.idleMin (once output has started), or > timeoutMin + 5;
  a live hung runner is killed with its whole process tree (taskkill /T /F). The runner's own watchdog also enforces the timeout.
  Note: .seen.json marks events as reported; after a compaction check status-board.ps1 ("UNREVIEWED" runs) too.
#>
param(
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'),
  [int]$PollSec = 10,
  [int]$HeartbeatMin = 45
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
[Console]::OutputEncoding = $script:Utf8
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$team = Get-Team $Orch
$idleMin = [int](Get-Limit $team 'idleMin' 10)
$coalesceSec = [int](Get-Limit $team 'coalesceSec' 15); $coalesced = $false
$seenFile = Join-Path $Orch 'status\.seen.json'
$seen = @{}
$sj = Read-Json $seenFile
if ($sj) { $sj.PSObject.Properties | ForEach-Object { $seen[$_.Name] = $_.Value } }
$start = Get-Date

while ($true) {
  $all = @(Get-StatusList $Orch)
  $events = @()
  foreach ($s in $all) {
    if ($s.state -eq 'running') {
      $alive = Test-Alive $s
      $age = ((Get-Date) - [datetime]$s.started).TotalMinutes
      $idle = if ($s.lastOutput) { ((Get-Date) - [datetime]$s.lastOutput).TotalMinutes } else { 0 }
      $why = $null
      if ($alive -eq $false) { $why = 'runner process gone' }
      elseif ($null -eq $alive -and $age -gt 2) { $why = 'runner never started' }
      elseif ($s.lastOutput -and $idle -gt $idleMin) { $why = "no output for $([int]$idle) min" }
      elseif ($age -gt ($s.timeoutMin + 5)) { $why = "running $([int]$age) min > timeout" }
      if ($why) {
        $fresh = Read-Json $s._file                  # re-read: the runner may have just finished (race)
        if ($fresh -and $fresh.state -eq 'running' -and $fresh.runId -eq $s.runId) {
          if ($alive -eq $true) { & taskkill.exe /PID $s.pid /T /F 2>&1 | Out-Null; $why += ' - process tree killed' }
          $fresh.state = 'stalled'; $fresh.reason = $why; $fresh.ended = (Get-Date).ToString('s')
          Write-Json $fresh $s._file
          $s.state = 'stalled'; $s.reason = $why
        } elseif ($fresh) { $s.state = $fresh.state; $s.reason = $fresh.reason; $s.gate = $fresh.gate }
      }
    }
    $key = "$($s.runId):$($s.state):$($s.gate)"
    if ($s.state -ne 'running' -and $seen[$s.name] -ne $key) {
      $g = if ($s.gate) { "gate=$($s.gate) " } else { '' }
      $events += ("EVENT $($s.name) $($s.state.ToUpperInvariant()) $g$($s.reason)").Trim()
    }
  }
  # coalesce: if other agents are still running, wait a few seconds so near-simultaneous finishes wake the lead once
  if ($events.Count -gt 0 -and -not $coalesced -and $coalesceSec -gt 0 -and @($all | Where-Object { $_.state -eq 'running' }).Count -gt 0) {
    $coalesced = $true; Start-Sleep -Seconds $coalesceSec; continue
  }
  if ($events.Count -gt 0) {
    foreach ($s in $all) { $seen[$s.name] = "$($s.runId):$($s.state):$($s.gate)" }
    Write-Json $seen $seenFile
    $events
    'RUNNING: ' + (($all | Where-Object { $_.state -eq 'running' } | ForEach-Object { $_.name }) -join ', ')
    exit 0
  }
  $running = @($all | Where-Object { $_.state -eq 'running' })
  if ($running.Count -eq 0) { 'IDLE (no running agents)'; exit 0 }
  if (((Get-Date) - $start).TotalMinutes -ge $HeartbeatMin) {
    'HEARTBEAT ' + (($running | ForEach-Object {
      $age = [int]((Get-Date) - [datetime]$_.started).TotalMinutes
      $idle = if ($_.lastOutput) { [int]((Get-Date) - [datetime]$_.lastOutput).TotalMinutes } else { '?' }
      "$($_.name)[$($age)m, idle $($idle)m]" }) -join ', ')
    exit 0
  }
  Start-Sleep -Seconds $PollSec
}
