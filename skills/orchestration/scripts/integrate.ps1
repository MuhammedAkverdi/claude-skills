<#
  Merge train: merges accepted branches one by one onto an integration branch in its own worktree,
  runs the regression commands after each merge, and stops at the first conflict or failure.
  integrate.ps1 -Topic <name> -Branches feat/a,feat/b [-Base main] [-TestCommands 'npm test'] [-FinalTestCommands 'npm run test:all']
                [-Repo .] [-Orch orchestrator]
  - -TestCommands (fast) run after EVERY merge; -FinalTestCommands (expensive, wide) run ONCE on the final tip.
    If the final run fails, the script re-runs it on each earlier merge commit to name the first failing branch
    (quota-friendly: the wide suite runs once when all is well, never N times).
  - Integration worktree: ..\wt-int-<topic> on branch int/<topic> (created from -Base if missing).
  - Conflict: the merge is aborted (nothing half-merged stays) and orchestrator/briefs/brief-conflict-<topic>-<branch>.md
    is written for a worker (conflicting files + binding decisions). The lead never resolves conflicts itself.
  - Never pushes; never touches main. Fast-forwarding main stays a separate OWNER-approved step.
#>
param(
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Topic,
  [Parameter(Mandatory)][string[]]$Branches,
  [string]$Base = 'main',
  [string[]]$TestCommands = @(),
  [string[]]$FinalTestCommands = @(),
  [string]$Repo = (Get-Location).Path,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator')
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$top = Invoke-Git $Repo @('rev-parse','--show-toplevel'); if ($top.code -ne 0) { throw "Not a git repository: $Repo" }
$Repo = ($top.out | Select-Object -First 1).Trim().Replace('/', '\')
$intBranch = "int/$Topic"
$wt = Join-Path (Split-Path -Parent $Repo) "wt-int-$Topic"

if (-not (Test-Path -LiteralPath $wt)) {
  $exists = (Invoke-Git $Repo @('rev-parse','--verify','--quiet',"refs/heads/$intBranch")).code -eq 0
  if ($exists) { throw "Branch $intBranch exists but its worktree is missing - add it: git worktree add `"$wt`" $intBranch" }
  & "$PSScriptRoot\worktree.ps1" new -Name "int-$Topic" -Branch $intBranch -Base $Base -Repo $Repo -Orch $Orch
}
$cur = ((Invoke-Git $wt @('rev-parse','--abbrev-ref','HEAD')).out | Select-Object -First 1)
if ("$cur".Trim() -ne $intBranch) { throw "Integration worktree $wt is on '$cur', expected '$intBranch'." }
if (@((Invoke-Git $wt @('status','--porcelain')).out | Where-Object { $_ -and $_ -notmatch '^warning:' }).Count -gt 0) { throw "Integration worktree $wt is dirty - clean it first." }
foreach ($b in $Branches) { if ((Invoke-Git $Repo @('rev-parse','--verify','--quiet',"$b^{commit}")).code -ne 0) { throw "Unknown branch/commit: $b" } }

$log = @("# Merge train $intBranch ($(Get-Date -Format s))", ""); $mergeShas = @()
foreach ($b in $Branches) {
  $before = ((Invoke-Git $wt @('rev-parse','HEAD')).out | Select-Object -First 1).Trim()
  $m = Invoke-Git $wt @('merge','--no-ff','--no-edit',$b)
  if ($m.code -ne 0) {
    $conf = @((Invoke-Git $wt @('diff','--name-only','--diff-filter=U')).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal):' })
    Invoke-Git $wt @('merge','--abort') | Out-Null
    if ($conf.Count -eq 0) { $log += "- MERGE FAILED for $b (no conflicts - see git output): $($m.out -join ' ')"; Write-Text (Join-Path $Orch "reports\merge-train-$Topic.md") ($log -join "`r`n"); $log; exit 1 }
    $decisions = ''
    $dec = Join-Path $Orch 'decisions.md'; if (Test-Path -LiteralPath $dec) { $decisions = (Select-String -LiteralPath $dec -Pattern '^## (ADR|R)-' | ForEach-Object { "- " + $_.Line.TrimStart('#',' ') }) -join "`r`n" }
    $safe = $b -replace '[^A-Za-z0-9._-]', '-'
    $briefPath = Join-Path $Orch "briefs\brief-conflict-$Topic-$safe.md"
    Write-Text $briefPath (@(
      "# Brief: resolve merge conflict - $b into $intBranch - $(Get-Date -Format yyyy-MM-dd)",
      "Rol: worker - Workdir: $wt - Dal: $intBranch - HEAD: $before",
      "Commit et (yalniz cakisan dosyalari adlariyla ekle).", "",
      "## Yapilacak", "Run: git merge --no-ff $b . Resolve the conflicts below: keep both sides' rules in one consistent implementation; do not change agreed values or confidence/threshold numbers.", "",
      "## Cakisan dosyalar", ($conf | ForEach-Object { "- $_" }) -join "`r`n", "",
      "## Baglayici kararlar", $decisions, "",
      "## Izinli komutlar (lider ayni satirlari -AllowCommands ile verir)", "- git merge --no-ff $b", "- git add $($conf -join ' ')", "- git commit --no-edit", "",
      "## Rapor", "Write the report to the absolute report path given in the launch prompt.") -join "`r`n")
    $log += "- CONFLICT merging $b ($($conf.Count) file(s)); merge aborted. Brief: $briefPath"
    Write-Text (Join-Path $Orch "reports\merge-train-$Topic.md") ($log -join "`r`n")
    Add-Event $Orch "MERGE-TRAIN int/$Topic CONFLICT on $b ($($conf.Count) files) - brief written"; $log; exit 2
  }
  $log += "- merged $b"
  $mergeShas += [pscustomobject]@{ branch = $b; sha = ((Invoke-Git $wt @('rev-parse','HEAD')).out | Select-Object -First 1).Trim() }
  foreach ($c in $TestCommands) {
    $r = Invoke-Cmd $wt $c; $out = $r.out; $ec = $r.code
    if ($ec -ne 0) {
      $log += "  - FAIL after merging $b : $c (exit $ec) - $b (or its interaction with earlier branches) introduced it. Integration HEAD left at the merge commit; reset is the lead's decision."
      $log += '```'; $log += ($out | Select-Object -Last 20); $log += '```'
      Write-Text (Join-Path $Orch "reports\merge-train-$Topic.md") ($log -join "`r`n")
      Add-Event $Orch "MERGE-TRAIN int/$Topic TEST FAIL after $b"; $log; exit 3
    }
    $log += "  - $c : ok"
  }
}
$head = ((Invoke-Git $wt @('rev-parse','HEAD')).out | Select-Object -First 1).Trim()
# wide suite ONCE on the tip; on failure find the first failing merge (still never more than N+1 wide runs)
foreach ($c in $FinalTestCommands) {
  $r = Invoke-Cmd $wt $c
  if ($r.code -eq 0) { $log += "- final: $c : ok"; continue }
  $log += "- FINAL FAIL on tip: $c (exit $($r.code)) - searching the first failing merge..."
  $culprit = $null
  try {
    foreach ($ms in $mergeShas) {
      Invoke-Git $wt @('checkout','--quiet','--detach',$ms.sha) | Out-Null
      $rr = Invoke-Cmd $wt $c
      if ($rr.code -ne 0) { $culprit = $ms; break }
    }
  } finally { Invoke-Git $wt @('checkout','--quiet',$intBranch) | Out-Null }
  if ($culprit) { $log += "  - first failing after merging $($culprit.branch) ($($culprit.sha.Substring(0,8)))" } else { $log += "  - no single merge fails alone - interaction only visible on the tip" }
  $log += '```'; $log += ($r.out | Select-Object -Last 20); $log += '```'
  Write-Text (Join-Path $Orch "reports\merge-train-$Topic.md") ($log -join "`r`n")
  Add-Event $Orch "MERGE-TRAIN int/$Topic FINAL FAIL$(if ($culprit) { " - first failing: $($culprit.branch)" })"; $log; exit 4
}
Add-Event $Orch "MERGE-TRAIN int/$Topic ALL MERGED ($($Branches -join ', ')) @ $($head.Substring(0,8))"
$log += ""; $log += "ALL MERGED - $intBranch @ $head. Next: independent audit + lead measurement on this SHA; fast-forward main only with OWNER's OK."
Write-Text (Join-Path $Orch "reports\merge-train-$Topic.md") ($log -join "`r`n")
$log
