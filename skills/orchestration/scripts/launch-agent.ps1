<#
  Launch an agent (agy or Claude Code) in the background. Returns immediately.

  launch-agent.ps1 -Name <id> -Brief <path.md> ( -Role <role> | -TaskType <code|hardcode|test|audit|referee|design|research> )
     [-TaskId T3] [-Workdir <dir>] [-Orch <orchestrator dir>] [-Model <id>] [-Mode accept-edits|plan] [-Attempt <n>]
     [-AllowCommands 'npm test','git add a.js'] [-Profiles git-inspect,...] [-SkipPermissions]
     [-Scope 'src/login/*','test/login*'] [-GateCommands 'npm test'] [-GateProfiles ...] [-Context <files>]
     [-TimeoutMin 60] [-Escalate n] [-AllowDirty] [-Force]

  Roles come from orchestrator/team.json (engine agy|claude, model, effort, mode, fallback).
  -TaskType picks the role from team.json "routing"; -Escalate n starts n steps further (explicit only - a -rN retry keeps the role).
  Quota ledger (per model AND per quota group): cooling model -> role fallback -> fallbackRole/next routed role.
  Claude reserve: claude-engine roles are skipped while the Claude account is above (100 - claudeReservePct)%.
  Preflight (zero tokens): forbidden command patterns, brief size, missing context, dirty/mid-merge worktree (-AllowDirty).
  Commands: headless agents may only run EXACT allowed commands (-AllowCommands / -Profiles). -SkipPermissions only with OWNER's OK.
  Gate: with -Scope and/or -GateCommands, verify-run.ps1 runs automatically after a DONE run.
#>
param(
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Name,
  [Parameter(Mandatory)][string]$Brief,
  [string]$Role,
  [string]$TaskType,
  [string]$TaskId,
  [int]$Attempt = 0,
  [string]$Workdir = (Get-Location).Path,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'),
  [string]$Model,
  [ValidateSet('accept-edits','plan')][string]$Mode,
  [string[]]$AllowCommands = @(),
  [string[]]$Profiles = @(),
  [switch]$SkipPermissions,
  [string[]]$Scope = @(),
  [string[]]$GateCommands = @(),
  [string[]]$GateProfiles = @(),
  [string[]]$Context = @(),
  [int]$TimeoutMin = 0,
  [int]$Escalate = 0,
  [switch]$AllowDirty,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"

$Orch    = (Resolve-Path -LiteralPath $Orch).Path
$Workdir = (Resolve-Path -LiteralPath $Workdir).Path
$Brief   = (Resolve-Path -LiteralPath $Brief).Path
foreach ($d in 'status','logs','reports','briefs','artifacts','runs','checkpoints') { New-Item -ItemType Directory -Force -Path (Join-Path $Orch $d) | Out-Null }
$team = Get-Team $Orch
if ($TimeoutMin -le 0) { $TimeoutMin = [int](Get-Limit $team 'defaultTimeoutMin' 60) }
if ($Attempt -le 0) { if ($Name -match '-r(\d+)$') { $Attempt = [int]$Matches[1] } else { $Attempt = 1 } }

# ---- choose role and model (quota-aware)
# Escalation is EXPLICIT (-Escalate n = start n steps further along the routing list). A retry (-rN) keeps the role:
# limits, denials, timeouts or a forgotten commit are not a reason to spend a stronger/scarcer model.
# -Role + -TaskType: -Role first (scheduler's worker/worker2 choice), then the routing list.
$candidates = @()
if ($TaskType) {
  $route = @($team.routing.$TaskType)
  if (-not $route -or $route.Count -eq 0) { throw "No routing for task type '$TaskType' in team.json." }
  $start = [Math]::Min([Math]::Max($Escalate, 0), $route.Count - 1)
  $candidates = @($route[$start..($route.Count - 1)])
  if ($Role -and $Escalate -le 0) { $candidates = @($Role) + @($candidates | Where-Object { $_ -ne $Role }) }
} elseif ($Role) { $candidates = @($Role) }
else { throw "Give -Role or -TaskType." }
foreach ($r in @($candidates)) { $fr = $team.roles.$r.fallbackRole; if ($fr -and $candidates -notcontains $fr) { $candidates += $fr } }

# Claude reserve: worker2 must not eat the lead's Claude Code account (5h / 7d windows)
$reserve = [int](Get-Limit $team 'claudeReservePct' 30)
$cu = Get-ClaudeUsage $Orch
$claudeLow = $false
if ($cu) { foreach ($w in @($cu.five_hour, $cu.seven_day)) { if ($w -and $w.utilization -ne $null -and [double]$w.utilization -ge (1 - $reserve / 100.0) -and (-not $w.resetsAt -or [datetime]$w.resetsAt -gt (Get-Date))) { $claudeLow = $true } } }

$chosen = $null; $notes = @()
foreach ($r in $candidates) {
  $cfg = $team.roles.$r
  if (-not $cfg) { throw "Unknown role '$r' (not in team.json)." }
  if ($cfg.engine -eq 'claude' -and $claudeLow -and -not $Force) { $notes += "$r skipped: Claude account above $((100 - $reserve))% (reserve for the lead)"; continue }
  $models = @(); if ($Model) { $models += $Model } else { $models += $cfg.model; if ($cfg.fallback) { $models += $cfg.fallback } }
  foreach ($m in $models) {
    $cool = Get-Cooldown $Orch $m $team
    if ($cool -and -not $Force) { $notes += "$m cooling until $($cool.ToString('HH:mm'))"; continue }
    $chosen = @{ role = $r; cfg = $cfg; model = $m }; break
  }
  if ($chosen) { break }
}
if (-not $chosen) { throw "All candidate models are cooling down: $($notes -join '; '). Use -Force to try anyway." }
$Role = $chosen.role; $cfg = $chosen.cfg; $Model = $chosen.model
$engine = if ($cfg.engine) { $cfg.engine } else { 'agy' }
if (-not $Mode) { $Mode = $cfg.mode }
if (-not $Mode) { $Mode = 'accept-edits' }
$effort = $cfg.effort

# ---- names and files
$statusFile = Join-Path $Orch "status\$Name.json"
$logFile    = Join-Path $Orch "logs\$Name.log"
$reportFile = Join-Path $Orch "reports\$Name.md"
$runDir     = Join-Path $Orch "runs\$Name"
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
if (Test-Path -LiteralPath $statusFile) {
  $old = Read-Json $statusFile
  if ($old -and $old.state -eq 'running' -and (Test-Alive $old)) { throw "Agent '$Name' is still running (pid $($old.pid))." }
  if (-not $Force) { throw "Name '$Name' was used before (state: $($old.state)). Use resume-agent.ps1 or relaunch as '$Name-r2'." }
  foreach ($f in $logFile, $reportFile) { if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination "$f.$stamp.bak" -Force } }
} elseif (Test-Path -LiteralPath $reportFile) { Move-Item -LiteralPath $reportFile -Destination "$reportFile.$stamp.bak" -Force }

# ---- concurrency
$live = @(Get-StatusList $Orch | Where-Object { $_.state -eq 'running' -and (Test-Alive $_) -ne $false })
$busy = @($live | Where-Object { $_.workdir -eq $Workdir -and $_.name -ne $Name })
if ($busy.Count -gt 0 -and -not $Force) { throw "Workdir already used by running agent '$($busy[0].name)'. One agent per worktree." }
$maxP = [int](Get-Limit $team 'maxParallel' 3)
if ($live.Count -ge $maxP -and -not $Force) { throw "Already $($live.Count) agents running (max $maxP)." }

# ---- security scan
$briefText = [IO.File]::ReadAllText($Brief, $script:Utf8)
$hits = @(Find-Secrets $briefText)
foreach ($c in $Context) { $hits += @(Find-Secrets ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $c).Path, $script:Utf8)) | ForEach-Object { "$_ in $c" }) }
if ($hits.Count -gt 0 -and -not $Force) { throw "Security scan blocked the launch: $($hits -join ', ')" }

# ---- commands (exact strings) from -AllowCommands + profiles
$cmds = @($AllowCommands)
foreach ($p in $Profiles) { $pc = @($team.commandProfiles.$p); if (-not $pc) { throw "Unknown command profile '$p'." }; $cmds += $pc }
$gate = @($GateCommands)
foreach ($p in $GateProfiles) { $pc = @($team.commandProfiles.$p); if (-not $pc) { throw "Unknown command profile '$p'." }; $gate += $pc }
$cmds = @($cmds | Select-Object -Unique)

# ---- zero-token preflight (no agent is started for a launch that would die or waste quota)
$bad = @()
foreach ($c in @($cmds) + @($gate)) { foreach ($pat in @($team.forbiddenCommandPatterns)) { if ($pat -and $c -match $pat) { $bad += "'$c' matches forbidden pattern $pat" } } }
if ($bad.Count -gt 0 -and -not $Force) { throw "Preflight: forbidden command(s): $($bad -join '; ')" }
foreach ($c in $Context) { if (-not (Test-Path -LiteralPath $c)) { throw "Preflight: context file not found: $c" } }
$briefLines = ($briefText -split "`n").Count
$bw = [int](Get-Limit $team 'briefWarnLines' 150); $bm = [int](Get-Limit $team 'briefMaxLines' 400)
if ($briefLines -gt $bm -and -not $Force) { throw "Preflight: brief has $briefLines lines (max $bm) - every agent turn re-reads it. Shorten it (file:line references, 1-line decision summaries)." }
if ($briefLines -gt $bw) { $notes += "brief has $briefLines lines (> $bw): consider trimming" }
$gs = Invoke-Git $Workdir @('rev-parse','--git-dir')
if ($gs.code -eq 0 -and -not $AllowDirty -and -not $Force) {
  $gd = ($gs.out | Select-Object -First 1).Trim(); if (-not [IO.Path]::IsPathRooted($gd)) { $gd = Join-Path $Workdir $gd }
  foreach ($m in 'MERGE_HEAD','rebase-merge','rebase-apply','CHERRY_PICK_HEAD') { if (Test-Path -LiteralPath (Join-Path $gd $m)) { throw "Preflight: $Workdir is in the middle of a merge/rebase ($m). Use a conflict brief with -AllowDirty." } }
  $dirty = @((Invoke-Git $Workdir @('status','--porcelain')).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal):' -and $_ -notmatch 'orchestrator/' })
  if ($dirty.Count -gt 0) { throw "Preflight: $Workdir has uncommitted changes ($($dirty.Count)). Commit/clean first, or -AllowDirty (resume-agent passes it)." }
}

# ---- context artifacts (read-only copies for this run)
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$ctxFiles = @()
if ($Context.Count -gt 0) {
  $ctxDir = Join-Path $runDir 'context'; New-Item -ItemType Directory -Force -Path $ctxDir | Out-Null
  foreach ($c in $Context) { $src = (Resolve-Path -LiteralPath $c).Path; $dst = Join-Path $ctxDir (Split-Path -Leaf $src); Copy-Item -LiteralPath $src -Destination $dst -Force; $ctxFiles += $dst }
}

# ---- base SHA for the gate
$baseSha = $null
$g = Invoke-Git $Workdir @('rev-parse','HEAD'); if ($g.code -eq 0) { $baseSha = ($g.out | Select-Object -First 1).Trim() }

# ---- prompt (double quotes allowed: run-agent.ps1 escapes native arguments)
$prompt = "You are the $Role agent $Name in a lead-managed team. Your working directory (project root) is $Workdir ; every relative path in the brief is relative to it - never create project files inside the orchestrator folder. Read the brief file at $Brief completely and carry it out exactly. Stay inside the scope and the forbidden list in the brief."
if ($Scope.Count -gt 0) { $prompt += " You may only change files matching: " + ($Scope -join ', ') + "." }
if ($ctxFiles.Count -gt 0) { $prompt += " Read-only context from earlier agents: " + ($ctxFiles -join ' ; ') + "." }
if ($Mode -ne 'plan') { $prompt += " Shared outputs meant for later agents (ADR drafts, research notes) go into $Orch\artifacts ." }
if ($cmds.Count -gt 0) { $prompt += " Shell commands: ALWAYS run them with the working directory (Cwd) set to the project root $Workdir - never in the brief or orchestrator folders. ONLY these exact commands are allowed; run them exactly as written: " + ($cmds -join ' | ') + ". Any other command is denied - if you need another one, say so in the report instead of retrying." }
elseif (-not $SkipPermissions) { $prompt += " You cannot run shell commands in this run; use file tools only and list in the report which commands the lead should run." }
# output hygiene + stop-early (lesson from an earlier project: one session burned 572k tokens, 19.6 MB of it command output)
$rml = [int](Get-Limit $team 'reportMaxLines' 35)
$prompt += " TOKEN RULES: (1) Never print full test/build logs, JSON outputs or full diffs: redirect long command output to a file and look only at a summary (last 20 lines or pass/fail counts); on failure show only FAIL/ERROR lines with up to 3 lines of context, max 40 lines. (2) Read big files by line ranges after searching; do not re-read an unchanged file from the start. (3) git diff --stat first, single-file -U3 diffs only when needed. (4) Run focused tests while working; a wide test run at most once, at the end; never run full measurement/benchmark suites (the lead does). (5) STOP EARLY: if the same error or test fails 3 times for the same root cause, or a needed command is denied, stop and report the blocker instead of trying variations."
if ($Mode -eq 'plan') {
  $prompt += " This is a READ-ONLY run: do not create, edit or write ANY file (writing is denied and would abort the run). Print your final report as the last thing in your answer, between a line BEGIN_REPORT and a line END_REPORT. Then stop."
} else {
  $prompt += " When finished, write your final report to the absolute path $reportFile , then print only the single line REPORT_WRITTEN and stop (do not print the report again)."
}
$prompt += " Report format (max $rml lines, bullets only, omit empty sections): Summary; Changed files (path +A/-D) + commit SHA; Commands -> exit code and pass/fail counts; Produced artifacts; Changed interfaces; Open questions; Follow-up context (max 5 bullets)."
# double quotes are kept (exact allowlist matching); run-agent.ps1 escapes them for the native command line

# ---- engine command line
$exe = $null; $argv = @()
if ($engine -eq 'claude') {
  $exe = 'claude'
  $argv = @('-p', $prompt, '--model', $Model, '--output-format', 'stream-json', '--verbose', '--add-dir', (Split-Path -Parent $Brief), '--add-dir', (Join-Path $Orch 'reports'))
  if ($Mode -ne 'plan') { $argv += @('--add-dir', (Join-Path $Orch 'artifacts')) }
  if ($effort) { $argv += @('--effort', $effort) }
  if ($ctxFiles.Count -gt 0) { $argv += @('--add-dir', (Join-Path $runDir 'context')) }
  # token diet (measured 2026-11-25: ~49k -> ~10k context tokens per turn): no MCP servers, no skills/slash commands,
  # only the tools a worker needs. Project CLAUDE.md / AGENTS.md are still loaded (quality unchanged).
  $toolSet = @('Read','Glob','Grep'); if ($Mode -ne 'plan') { $toolSet += @('Edit','Write') }; if ($cmds.Count -gt 0 -or $SkipPermissions) { $toolSet += 'Bash' }
  $argv += @('--strict-mcp-config', '--disable-slash-commands', '--tools') + $toolSet
  if ($SkipPermissions) { $argv += '--dangerously-skip-permissions' }
  else {
    $argv += @('--permission-mode', $(if ($Mode -eq 'plan') { 'plan' } else { 'acceptEdits' }))
    $tools = @('Read','Glob','Grep'); if ($Mode -ne 'plan') { $tools += @('Edit','Write') }
    $tools += @($cmds | ForEach-Object { "Bash($_)" })
    $argv += '--allowedTools'; $argv += $tools
  }
} else {
  $exe = 'agy'
  # NO --add-dir for agy: agy runs shell commands in the first ADDED dir instead of the project root (verified).
  # Brief/report/context are reached by absolute path (needs "allowNonWorkspaceAccess": true in ~/.gemini/antigravity-cli/settings.json).
  $argv = @('-p', $prompt, '--model', $Model, '--mode', $Mode, '--output-format', 'stream-json', '--print-timeout', "$($TimeoutMin)m")
  if ($cmds.Count -gt 0) {
    $sf = Join-Path $runDir 'agy-settings.json'
    Write-Text $sf (@{ permissions = @{ allow = @($cmds | ForEach-Object { "command($_)" }) } } | ConvertTo-Json -Depth 4)
    $argv += @('--settings', $sf)
  }
  if ($SkipPermissions) { $argv += '--dangerously-skip-permissions' }
}

$runId = [guid]::NewGuid().ToString('N').Substring(0, 12)
Write-Json ([ordered]@{
  name = $Name; runId = $runId; role = $Role; engine = $engine; model = $Model; effort = $effort; mode = $Mode
  taskType = $TaskType; taskId = $TaskId; attempt = $Attempt; escalate = $Escalate; workdir = $Workdir; brief = $Brief; log = $logFile; report = $reportFile
  allowCommands = $cmds; skipPermissions = [bool]$SkipPermissions; scope = $Scope; gateCommands = $gate; context = $Context
  baseSha = $baseSha; exe = $exe; argv = $argv; orch = $Orch
  state = 'running'; started = (Get-Date).ToString('s'); ended = $null; exit = $null; reason = $null
  timeoutMin = $TimeoutMin; pid = $null; pidStart = $null; lastOutput = $null; gate = $null; notes = $notes
}) $statusFile

if ($TaskId) { Set-TaskStatus $Orch $TaskId 'running' $Name }
Add-Event $Orch ("LAUNCH $Name [$Role/$Model]" + $(if ($TaskId) { " task $TaskId" } else { '' }) + " workdir $(Split-Path -Leaf $Workdir) brief $(Split-Path -Leaf $Brief)")
Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -WorkingDirectory $Workdir -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSScriptRoot\run-agent.ps1`"",'-StatusFile',"`"$statusFile`"" | Out-Null

$cmdInfo = if ($SkipPermissions) { 'ALL (skip-permissions)' } elseif ($cmds.Count) { $cmds -join ' | ' } else { 'none' }
"LAUNCHED $Name run=$runId role=$Role engine=$engine model=$Model$(if($effort){" effort=$effort"}) mode=$Mode attempt=$Attempt commands=$cmdInfo"
if ($notes.Count) { "NOTE: " + ($notes -join '; ') }
"status: $statusFile"
"report: $reportFile"
