<#
  Quality gate for one finished run. Runs automatically after DONE (when scope/gate commands are set, or for tester/auditor),
  or by hand:  verify-run.ps1 -StatusFile orchestrator\status\<name>.json [-Commands 'npm test']
  Checks: changed files vs. scope, tester may only touch test files, auditor/researcher may change nothing,
  runs the gate commands in the workdir and records exit codes. Writes reports/<name>.gate.md, prints GATE PASS|FAIL.
#>
param(
  [Parameter(Mandatory)][string]$StatusFile,
  [string[]]$Commands = @()
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
$s = Read-Json $StatusFile
if (-not $s) { 'GATE FAIL (status file unreadable)'; exit 1 }
$team = Get-Team $s.orch
$issues = @(); $notes = @()

# changed files since the run's base commit (committed + working tree + untracked)
$changed = @()
if ($s.baseSha) {
  $a = Invoke-Git $s.workdir @('diff','--name-only',$s.baseSha)
  $b = Invoke-Git $s.workdir @('ls-files','--others','--exclude-standard')
  $changed = @(@($a.out) + @($b.out) | Where-Object { $_ -and $_ -notmatch '^(warning|fatal):' } | Select-Object -Unique)
  # ignore the orchestrator folder itself when it lives inside the workdir
  $orchRel = $null
  if ($s.orch.StartsWith($s.workdir, [StringComparison]::OrdinalIgnoreCase)) { $orchRel = (Norm $s.orch.Substring($s.workdir.Length).TrimStart('\','/')) + '/' }
  if ($orchRel) { $changed = @($changed | Where-Object { -not (Norm $_).StartsWith($orchRel) }) }
} else { $notes += 'workdir is not a git repo - file checks skipped' }

$scope = @($s.scope)
foreach ($f in $changed) {
  if ($scope.Count -gt 0 -and -not (Test-InScope $f $scope)) { $issues += "out of scope: $f" }
}
if ($s.role -in @('auditor','researcher') -and $changed.Count -gt 0) { $issues += "read-only role changed files: $($changed -join ', ')" }
if ($s.role -eq 'tester') {
  $tg = @($team.testGlobs)
  foreach ($f in $changed) { if (-not (Test-InScope $f $tg) -and (Norm $f) -notmatch '(^|/)(test|tests|spec|specs|__tests__)/|[._-](test|spec)\.[a-z0-9]+$|(^|/)test_[^/]+$|_test\.[a-z0-9]+$') { $issues += "tester changed non-test file: $f" } }
}

# if the agent was allowed to commit, nothing of its work may be left uncommitted
if ($s.baseSha -and (@($s.allowCommands) -match '^git commit').Count -gt 0) {
  $dirty = @((Invoke-Git $s.workdir @('status','--porcelain')).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal):' })
  if ($dirty.Count -gt 0) { $issues += "uncommitted work left although commit was allowed: $(($dirty | Select-Object -First 10) -join '; ')" }
  $newCommits = @((Invoke-Git $s.workdir @('rev-list',"$($s.baseSha)..HEAD")).out | Where-Object { $_ })
  if ($newCommits.Count -eq 0 -and $changed.Count -gt 0) { $issues += 'no commit was made' }
}

# gate commands (run by the lead side, not by the agent)
$cmds = @($Commands); if ($cmds.Count -eq 0) { $cmds = @($s.gateCommands) }
$results = @()
foreach ($c in $cmds) {
  if (-not $c) { continue }
  $r = Invoke-Cmd $s.workdir $c          # -EncodedCommand: quotes inside the command survive
  $ec = $r.code; $out = $r.out
  $results += [pscustomobject]@{ cmd = $c; exit = $ec; tail = (($out | Select-Object -Last $(if ($ec -eq 0) { 3 } else { 15 })) -join "`n") }
  if ($ec -ne 0) { $issues += "gate command failed (exit $ec): $c" }
}

# report length (verbose reports cost the lead tokens on every review)
$rml = [int](Get-Limit $team 'reportMaxLines' 35)
if (Test-Path -LiteralPath $s.report) { $rl = @(Get-Content -LiteralPath $s.report).Count; if ($rl -gt [Math]::Max(80, 2 * $rml)) { $notes += "report is $rl lines (target <= $rml) - ask for compact reports" } }

$verdict = if ($issues.Count -eq 0) { 'PASS' } else { 'FAIL' }
$md = @("# Gate: $($s.name) - $verdict", "", "- Run: $($s.runId) | role $($s.role) | model $($s.model) | base $($s.baseSha)", "- Changed files ($($changed.Count)): $($changed -join ', ')")
if ($s.baseSha) {      # enough for a routine review without extra git calls by the lead
  $cm = @((Invoke-Git $s.workdir @('log','--format=%h %s',"$($s.baseSha)..HEAD")).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal)' } | Select-Object -First 5)
  if ($cm) { $md += "- Commits: " + ($cm -join ' | ') }
  $st = @((Invoke-Git $s.workdir @('diff','--shortstat',$s.baseSha)).out | Where-Object { $_ -and $_ -notmatch '^warning' })
  if ($st) { $md += "- Diff: " + ($st -join ' ').Trim() }
}
if ($scope.Count) { $md += "- Scope: $($scope -join ', ')" }
foreach ($n in $notes) { $md += "- Note: $n" }
$md += ""; $md += "## Issues"; if ($issues.Count) { $md += ($issues | ForEach-Object { "- $_" }) } else { $md += "- none" }
if ($results.Count) { $md += ""; $md += "## Gate commands"; foreach ($r in $results) { $md += "### ``$($r.cmd)`` -> exit $($r.exit)"; $md += '```'; $md += $r.tail; $md += '```' } }
$md += ""; $md += "Baseline comparison (acceptance.md) and hidden checks remain the lead's job."
Write-Text (Join-Path $s.orch "reports\$($s.name).gate.md") ($md -join "`r`n")
"GATE $verdict ($($issues.Count) issue(s)) -> reports\$($s.name).gate.md"
if ($verdict -eq 'FAIL') { exit 1 }
