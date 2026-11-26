<#
  Worktree lifecycle + registry (orchestrator/worktrees.json).
  worktree.ps1 new    -Name <id> -Branch <branch> [-Base <sha|branch>] [-Repo .] [-Orch orchestrator]   # ..\wt-<id> on a new branch
  worktree.ps1 audit  -Name <id> -Sha <sha>                                                             # clean detached worktree for an auditor
  worktree.ps1 list                                                                                     # registry + dirty state
  worktree.ps1 remove -Name <id> [-Force]                                                               # git worktree remove (refuses dirty unless -Force)
  worktree.ps1 prune                                                                                    # remove registry entries whose folder is gone
  Never deletes branches and never pushes.
#>
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet('new','audit','list','remove','prune')][string]$Action,
  [string]$Name, [string]$Branch, [string]$Base = 'HEAD', [string]$Sha,
  [string]$Repo = (Get-Location).Path,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'),
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$Repo = (Resolve-Path -LiteralPath $Repo).Path
$top = (Invoke-Git $Repo @('rev-parse','--show-toplevel')); if ($top.code -ne 0) { throw "Not a git repository: $Repo" }
$Repo = ($top.out | Select-Object -First 1).Trim().Replace('/', '\')
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$reg = Join-Path $Orch 'worktrees.json'
$list = @(); $r = Read-Json $reg; if ($r) { $list = @($r) }
function Save-Reg { Write-Json @($list) $reg }
function Path-For([string]$n) { Join-Path (Split-Path -Parent $Repo) "wt-$n" }

switch ($Action) {
  'new' {
    if (-not $Name -or -not $Branch) { throw "new needs -Name and -Branch" }
    $p = Path-For $Name
    if (Test-Path -LiteralPath $p) { throw "Folder exists: $p" }
    $rb = Invoke-Git $Repo @('rev-parse','--verify',"$Base^{commit}"); if ($rb.code -ne 0) { throw "Unknown base: $Base" }
    $baseSha = ($rb.out | Select-Object -First 1).Trim()
    $g = Invoke-Git $Repo @('worktree','add','-b',$Branch,$p,$baseSha); if ($g.code -ne 0) { throw ($g.out -join "`n") }
    $list = @($list | Where-Object { $_.name -ne $Name }) + [pscustomobject]@{ name = $Name; path = $p; branch = $Branch; baseSha = $baseSha; kind = 'work'; owner = $null; created = (Get-Date).ToString('s') }
    Save-Reg; "CREATED $p on $Branch @ $baseSha"
  }
  'audit' {
    if (-not $Name -or -not $Sha) { throw "audit needs -Name and -Sha" }
    $p = Path-For "audit-$Name"
    $g = Invoke-Git $Repo @('worktree','add','--detach',$p,$Sha); if ($g.code -ne 0) { throw ($g.out -join "`n") }
    $list = @($list | Where-Object { $_.name -ne "audit-$Name" }) + [pscustomobject]@{ name = "audit-$Name"; path = $p; branch = $null; baseSha = $Sha; kind = 'audit'; owner = $null; created = (Get-Date).ToString('s') }
    Save-Reg; "CREATED clean audit worktree $p @ $Sha"
  }
  'list' {
    $running = @(Get-StatusList $Orch | Where-Object { $_.state -eq 'running' })
    foreach ($w in $list) {
      $exists = Test-Path -LiteralPath $w.path
      $dirty = if ($exists) { @((Invoke-Git $w.path @('status','--porcelain')).out | Where-Object { $_ }).Count } else { '-' }
      $head = if ($exists) { ((Invoke-Git $w.path @('rev-parse','--short','HEAD')).out | Select-Object -First 1) } else { '-' }
      $owner = ($running | Where-Object { $_.workdir -eq $w.path } | ForEach-Object { $_.name }) -join ','
      [pscustomobject]@{ name = $w.name; kind = $w.kind; branch = $w.branch; head = $head; dirtyFiles = $dirty; runningAgent = $owner; path = $w.path; exists = $exists }
    }
  }
  'remove' {
    $w = $list | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if (-not $w) { throw "Unknown worktree '$Name'" }
    $owner = @(Get-StatusList $Orch | Where-Object { $_.state -eq 'running' -and $_.workdir -eq $w.path -and (Test-Alive $_) -ne $false })
    if ($owner.Count -gt 0 -and -not $Force) { throw "Agent '$($owner[0].name)' is running in $($w.path)." }
    $a = @('worktree','remove',$w.path); if ($Force) { $a += '--force' }
    $g = Invoke-Git $Repo $a; if ($g.code -ne 0) { throw ("git refused (uncommitted work?): " + ($g.out -join ' ')) }
    $list = @($list | Where-Object { $_.name -ne $Name }); Save-Reg; "REMOVED $($w.path) (branch $($w.branch) kept)"
  }
  'prune' {
    Invoke-Git $Repo @('worktree','prune') | Out-Null
    $before = $list.Count; $list = @($list | Where-Object { Test-Path -LiteralPath $_.path }); Save-Reg
    "PRUNED $($before - $list.Count) entr(y/ies)"
  }
}
