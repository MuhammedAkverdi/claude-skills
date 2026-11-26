<#
  Task DAG scheduler over orchestrator/tasks.json.
  scheduler.ps1 [next]                     # ready tasks for the free slots, conflict-free, with suggested launch commands
  scheduler.ps1 set -Id T3 -Status running -Agent w-T3     # statuses: pending running review accepted rejected cancelled
  scheduler.ps1 show                       # whole table
  A task is ready when status=pending and all deps are accepted. Two tasks whose "files" globs overlap never run together.
  "code" tasks are balanced between worker (Neon) and worker2 (Sonnet) for parallel work.
#>
param(
  [Parameter(Position = 0)][ValidateSet('next','set','show')][string]$Action = 'next',
  [string]$Id, [string]$Status, [string]$Agent,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator')
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$f = Join-Path $Orch 'tasks.json'
if (-not (Test-Path -LiteralPath $f)) { Copy-Item -LiteralPath (Join-Path $script:SkillRoot 'templates\tasks.json') -Destination $f }
$doc = Read-Json $f; if (-not $doc) { throw "tasks.json is not valid JSON" }
$tasks = @($doc.tasks)
$team = Get-Team $Orch

if ($Action -eq 'set') {
  if (-not ($tasks | Where-Object { $_.id -eq $Id })) { throw "Unknown task $Id" }
  Set-TaskStatus $Orch $Id $Status $Agent
  $t = @((Read-Json $f).tasks) | Where-Object { $_.id -eq $Id } | Select-Object -First 1
  "SET $Id status=$($t.status) agent=$($t.agent)"; return
}
if ($Action -eq 'show') { $tasks | Select-Object id, title, type, status, priority, @{n='deps';e={$_.deps -join ','}}, @{n='files';e={$_.files -join ','}}, agent | Format-Table -AutoSize | Out-String -Width 200; return }

# next
$byId = @{}; foreach ($t in $tasks) { $byId[$t.id] = $t }
$active = @($tasks | Where-Object { $_.status -eq 'running' })
$liveAgents = @(Get-StatusList $Orch | Where-Object { $_.state -eq 'running' -and (Test-Alive $_) -ne $false })
$w1Cool = Get-Cooldown $Orch $team.roles.worker.model $team
$w2Cool = Get-Cooldown $Orch $team.roles.worker2.model $team
# Claude reserve: keep the lead's Claude account alive - no worker2 while the account is above (100 - reserve)%
$reserve = [int](Get-Limit $team 'claudeReservePct' 30); $cu = Get-ClaudeUsage $Orch
if ($cu) { foreach ($w in @($cu.five_hour, $cu.seven_day)) { if ($w -and $w.utilization -ne $null -and [double]$w.utilization -ge (1 - $reserve / 100.0) -and (-not $w.resetsAt -or [datetime]$w.resetsAt -gt (Get-Date))) { $w2Cool = [datetime]$w.resetsAt } } }
$free = [int](Get-Limit $team 'maxParallel' 3) - [Math]::Max($active.Count, $liveAgents.Count)
$ready = @($tasks | Where-Object {
  $_.status -eq 'pending' -and (@($_.deps | Where-Object { $_ -and $byId[$_].status -ne 'accepted' }).Count -eq 0)
} | Sort-Object @{e={[int]$_.priority}; Descending=$true}, id)
$blocked = @($tasks | Where-Object { $_.status -eq 'pending' -and $ready.id -notcontains $_.id })

$picked = @(); $taken = @($active)
$codeTurn = @($liveAgents | Where-Object { $_.role -eq 'worker' }).Count -gt @($liveAgents | Where-Object { $_.role -eq 'worker2' }).Count
foreach ($t in $ready) {
  if ($picked.Count -ge $free) { break }
  $clash = $taken | Where-Object { Test-GlobOverlap @($_.files) @($t.files) } | Select-Object -First 1
  if ($clash) { continue }
  $role = if ($t.role) { $t.role } elseif ($t.type -eq 'code') { if ($codeTurn) { 'worker2' } else { 'worker' } } else { $null }
  if ($role -eq 'worker2' -and $w2Cool -and -not $w1Cool) { $role = 'worker' }     # cooling model -> the other worker
  elseif ($role -eq 'worker' -and $w1Cool -and -not $w2Cool) { $role = 'worker2' }
  if ($t.type -eq 'code' -and -not $t.role) { $codeTurn = -not $codeTurn }
  $picked += [pscustomobject]@{ task = $t; role = $role }; $taken += $t
}
"FREE SLOTS: $free | READY: $($ready.Count) | PICKED: $($picked.Count) | BLOCKED: $($blocked.Count)"
foreach ($p in $picked) {
  $t = $p.task
  $roleArg = "-TaskType $($t.type)" + $(if ($p.role) { " -Role $($p.role)" } else { '' })      # both: role first, routing kept for -rN
  $label = if ($p.role) { $p.role } else { $t.type }
  $scope = if ($t.files) { " -Scope " + ((@($t.files) | ForEach-Object { "'$_'" }) -join ',') } else { '' }
  "NEXT $($t.id) [$($t.type), prio $($t.priority)] $($t.title)"
  "  launch-agent.ps1 -Name $($t.id.ToLower())-$label -TaskId $($t.id) $roleArg -Brief orchestrator\briefs\brief-$($t.id.ToLower()).md$scope"
}
foreach ($t in $blocked) { $w = @($t.deps | Where-Object { $_ -and $byId[$_].status -ne 'accepted' }); if ($w) { "WAIT $($t.id) on $($w -join ',')" } else { "WAIT $($t.id) (file overlap or no free slot)" } }
