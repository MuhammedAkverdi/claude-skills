<#
  One-command resume of an interrupted run (limited, timeout, stalled, denied, failed, incomplete, or after a reboot).
  resume-agent.ps1 -Name <old name> [-Orch orchestrator] [-Model <id>] [-AllowCommands ...] [-NoLaunch]
  - Saves the worktree's uncommitted work as a patch (orchestrator/checkpoints/<name>-<stamp>.patch) - never resets anything.
  - Writes a run-specific brief (brief-<newName>.md) = original brief without old DEVAM blocks + ONE fresh DEVAM
    (state, reason, changed files, denials, last answer lines) - briefs do not grow with every retry.
  - Keeps the role by default. -Escalate 1 moves one step up the routing list (only after 2 genuine logic failures).
  - Relaunches as <base>-r<N+1> with the same role/mode/timeout/scope/commands/task; -AllowCommands ADDS to the old list.
    Quota cooldowns make launch-agent pick the fallback model / fallbackRole (worker2 -> worker) automatically.
  - Untracked files are copied (flat names + index.txt) to checkpoints/u-<stamp>/ (git diff does not contain them).
#>
param(
  [Parameter(Mandatory)][string]$Name,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'),
  [string]$Model,
  [string[]]$AllowCommands = @(),
  [int]$Escalate = 0,
  [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$s = Read-Json (Join-Path $Orch "status\$Name.json"); if (-not $s) { throw "No status for $Name" }
if ($s.state -eq 'running' -and (Test-Alive $s)) { throw "$Name is still running (pid $($s.pid)). Kill it first: taskkill /PID $($s.pid) /T /F" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# checkpoint
$changed = @(); $patch = $null
$st = Invoke-Git $s.workdir @('status','--porcelain')
if ($st.code -eq 0) {
  $changed = @($st.out | Where-Object { $_ })
  if ($changed.Count -gt 0) {
    $patch = Join-Path $Orch "checkpoints\$Name-$stamp.patch"
    $d = Invoke-Git $s.workdir @('diff','HEAD'); Write-Text $patch ($d.out -join "`n")
    # untracked files are not in the diff -> copy them as files
    $untracked = @((Invoke-Git $s.workdir @('ls-files','--others','--exclude-standard')).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal):' })
    foreach ($u in $untracked) {
      $src = Join-Path $s.workdir $u
      if (Test-Path -LiteralPath $src -PathType Leaf) {
        # short flat names: deep paths under C:\Users\...\orchestrator easily exceed MAX_PATH (260)
        $udir = Join-Path $Orch "checkpoints\u-$stamp"
        New-Item -ItemType Directory -Force -Path $udir | Out-Null
        $flat = $u.Replace('/', '__').Replace('\', '__')
        [IO.File]::Copy($src, (Join-Path $udir $flat), $true)
        Add-Line (Join-Path $udir 'index.txt') "$flat <= $u (run $Name)"
      }
    }
  }
}
$head = $null; $h = Invoke-Git $s.workdir @('rev-parse','--short','HEAD'); if ($h.code -eq 0) { $head = ($h.out | Select-Object -First 1) }

# last meaningful lines of the previous answer (zero-token digest)
$dg = Get-RunDigest $s
$lastLines = @($dg.lastText | Select-Object -Last 8)

$base = $Name -replace '-r\d+$', ''
$n = if ($Name -match '-r(\d+)$') { [int]$Matches[1] + 1 } else { 2 }
$newName = "$base-r$n"
while (Test-Path -LiteralPath (Join-Path $Orch "status\$newName.json")) { $n++; $newName = "$base-r$n" }

# run-specific brief = original brief WITHOUT earlier DEVAM blocks + one fresh DEVAM (no growing history: every turn re-reads it)
$orig = [IO.File]::ReadAllText($s.brief, $script:Utf8)
$cut = $orig.IndexOf("`n## DEVAM"); if ($cut -ge 0) { $orig = $orig.Substring(0, $cut) }
$devam = @("", "## DEVAM ($stamp) - previous run $Name ended: $($s.state) ($($s.reason))",
  "- Worktree: $($s.workdir) @ $head - $($changed.Count) uncommitted path(s) from the previous run are still there; continue from them, do not redo finished parts.",
  $(if ($patch) { "- Backup patch: $patch" } else { "- No uncommitted changes." }),
  "- Changed paths: $(($changed | Select-Object -First 20) -join '; ')")
if ($dg.denials.Count) { $devam += "- Denied last time: $((($dg.denials | Select-Object -Unique) -join '; '))" }
if ($lastLines.Count) { $devam += "- Last lines of the previous answer:"; $devam += ($lastLines | ForEach-Object { "  > $($_.Substring(0, [Math]::Min(200, $_.Length)))" }) }
$devam += "- Check git status first, then continue the original task above."
$newBrief = Join-Path (Split-Path -Parent $s.brief) ("brief-$newName.md")
Write-Text $newBrief ($orig.TrimEnd() + "`r`n" + ($devam -join "`r`n") + "`r`n")
"CHECKPOINT: $(if($patch){$patch}else{'none needed'}) | new brief: $newBrief"
Add-Event $Orch "RESUME $Name ($($s.state)) -> $newName$(if ($patch) { ' - checkpoint saved' })"

if ($NoLaunch) { "Relaunch later as: $newName"; return }
$p = @{ Name = $newName; Brief = $newBrief; Workdir = $s.workdir; Orch = $Orch; Attempt = $n; TimeoutMin = [int]$s.timeoutMin; AllowDirty = $true }
if ($Escalate -gt 0) { $p.Escalate = [int]$s.escalate + $Escalate } elseif ($s.escalate) { $p.Escalate = [int]$s.escalate }
if ($s.mode) { $p.Mode = $s.mode }
if ($s.taskId) { $p.TaskId = $s.taskId }
if ($s.taskType) { $p.TaskType = $s.taskType } else { $p.Role = $s.role }
if ($Model) { $p.Model = $Model }
$cmds = @(@($s.allowCommands) + @($AllowCommands) | Where-Object { $_ } | Select-Object -Unique)   # keep old + add new
if ($cmds.Count) { $p.AllowCommands = $cmds }
if (@($s.scope).Count) { $p.Scope = @($s.scope) }
if (@($s.gateCommands).Count) { $p.GateCommands = @($s.gateCommands) }
if (@($s.context).Count) { $p.Context = @($s.context) }
if ($s.skipPermissions) { $p.SkipPermissions = $true }
& "$PSScriptRoot\launch-agent.ps1" @p
