<#
  Zero-token digest of one run for the lead - read this INSTEAD of raw logs or full diffs.
  inspect-run.ps1 -Name <run> [-Orch orchestrator] [-File <path in workdir>] [-MaxDiffLines 120]
  Prints (<= ~40 lines): state, gate, duration, turns, tokens, log size, tools used (counts), denials, last errors,
  last answer lines, report line count, git diff --stat since the run's base; with -File a bounded -U3 diff of that file.
#>
param(
  [Parameter(Mandatory)][string]$Name,
  [string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'),
  [string]$File,
  [int]$MaxDiffLines = 120
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
$Orch = (Resolve-Path -LiteralPath $Orch).Path
$s = Read-Json (Join-Path $Orch "status\$Name.json"); if (-not $s) { "No status for $Name"; exit 1 }
$d = Get-RunDigest $s
$dur = if ($s.ended) { [int](([datetime]$s.ended - [datetime]$s.started).TotalMinutes) } else { [int]((Get-Date) - [datetime]$s.started).TotalMinutes }
"RUN $Name [$($s.role) / $($s.model)] state=$($s.state) gate=$($s.gate) exit=$($s.exit) ${dur}min turns=$($d.turns) tokens=$($d.tokensIn)/$($d.tokensOut) log=$($d.logKB)KB"
if ($s.reason) { "REASON: $($s.reason)" }
if ($d.tools.Count) { "TOOLS: " + (($d.tools.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object { "$($_.Key) x$($_.Value)" }) -join '; ') }
if ($d.toolErrors) { "TOOL ERRORS: $($d.toolErrors)" }
if ($d.denials.Count) { "DENIED: " + (($d.denials | Select-Object -Unique) -join '; ') }
if ($d.errors.Count) { "STDERR (last):"; $d.errors | ForEach-Object { "  $($_.Substring(0, [Math]::Min(200, $_.Length)))" } }
"LAST ANSWER LINES:"; $d.lastText | ForEach-Object { "  $($_.Substring(0, [Math]::Min(200, $_.Length)))" }
if (Test-Path -LiteralPath $s.report) { "REPORT: $(@(Get-Content -LiteralPath $s.report).Count) lines -> $($s.report)" } else { "REPORT: missing" }
$gate = Join-Path $Orch "reports\$Name.gate.md"; if (Test-Path -LiteralPath $gate) { "GATE REPORT: $gate" }
if ($s.baseSha) {
  "DIFF --stat since $($s.baseSha.Substring(0,8)):"
  (Invoke-Git $s.workdir @('diff','--stat',$s.baseSha)).out | Where-Object { $_ -and $_ -notmatch '^warning:' } | Select-Object -Last 15 | ForEach-Object { "  $_" }
  $log1 = (Invoke-Git $s.workdir @('log','--oneline',"$($s.baseSha)..HEAD")).out | Where-Object { $_ } | Select-Object -First 5
  if ($log1) { "COMMITS:"; $log1 | ForEach-Object { "  $_" } }
  if ($File) {
    "DIFF $File (-U3, max $MaxDiffLines lines):"
    (Invoke-Git $s.workdir @('diff','-U3',$s.baseSha,'--',$File)).out | Select-Object -First $MaxDiffLines
  }
}
