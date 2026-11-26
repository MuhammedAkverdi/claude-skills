<#
  Owner dashboard + run statistics.
  status-board.ps1 [-Orch orchestrator] [-NoHtml]
  Prints a terminal summary and writes orchestrator/dashboard.html (auto-refresh 30 s; open it in a browser):
  agents, tasks progress, cooling models, worktrees, OWNER-waiting items from the handoff, metrics per model and
  recurring failure reasons (for lessons.md).
#>
param([string]$Orch = (Join-Path (Get-Location).Path 'orchestrator'), [switch]$NoHtml, [switch]$LeadPacket)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\lib.ps1"
[Console]::OutputEncoding = $script:Utf8
$Orch = (Resolve-Path -LiteralPath $Orch).Path
function ConvertTo-HtmlText([string]$t) { [System.Net.WebUtility]::HtmlEncode($t) }

$agents = @(Get-StatusList $Orch | Sort-Object started -Descending)
$tasks = @(); $td = Read-Json (Join-Path $Orch 'tasks.json'); if ($td) { $tasks = @($td.tasks) }
$quota = Read-Json (Join-Path $Orch 'status\quota.json')
$cooling = @(); if ($quota) { $quota.PSObject.Properties | ForEach-Object { if ($_.Value.until -and [datetime]$_.Value.until -gt (Get-Date)) { $cooling += [pscustomobject]@{ model = $_.Name; until = $_.Value.until; reason = $_.Value.reason } } } }
$wts = @(); $w = Read-Json (Join-Path $Orch 'worktrees.json'); if ($w) { $wts = @($w) }
$metrics = @(); $mf = Join-Path $Orch 'metrics.jsonl'
if (Test-Path -LiteralPath $mf) { $metrics = @([IO.File]::ReadAllLines($mf, $script:Utf8) | Where-Object { $_ } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} }) }
$owner = @()
$ho = Join-Path $Orch 'lead-ops-handoff.md'
if (Test-Path -LiteralPath $ho) {
  $in = $false
  foreach ($l in [IO.File]::ReadAllLines($ho, $script:Utf8)) {
    if ($l -match '^##\s') { $in = $l -match 'OWNER' ; continue }
    if ($in -and $l.Trim() -match '^- .{2,}') { $owner += $l.Trim().Substring(2) }
  }
}
# finished runs newer than the last handoff update = not yet reviewed by the lead (survives compaction)
$hoTime = if (Test-Path -LiteralPath $ho) { (Get-Item -LiteralPath $ho).LastWriteTime } else { [datetime]::MinValue }
$unreviewed = @($agents | Where-Object { $_.state -ne 'running' -and $_.ended -and [datetime]$_.ended -gt $hoTime })
$perModel = @($metrics | Group-Object model | ForEach-Object {
  $g = $_.Group
  [pscustomobject]@{ model = $_.Name; runs = $g.Count; done = @($g | Where-Object state -eq 'done').Count
    gatePass = @($g | Where-Object gate -eq 'pass').Count; avgMin = [Math]::Round((($g | Measure-Object durationSec -Average).Average) / 60, 1)
    avgTurns = [Math]::Round((($g | ForEach-Object { [double]$_.turns } | Where-Object { $_ -gt 0 } | Measure-Object -Average).Average), 0)
    kTokIn = [Math]::Round((($g | ForEach-Object { [double]$_.tokensIn } | Measure-Object -Sum).Sum) / 1000, 0); kTokOut = [Math]::Round((($g | ForEach-Object { [double]$_.tokensOut } | Measure-Object -Sum).Sum) / 1000, 0)
    wasted = @($g | Where-Object { $_.state -in @('loop','budget','denied','incomplete','failed') }).Count } })
$reasons = @($metrics | Where-Object { $_.state -ne 'done' -and $_.reason } | Group-Object { ($_.state + ': ' + ($_.reason -replace '\d+', 'N')) } | Sort-Object Count -Descending | Select-Object -First 8)
$cu = Get-ClaudeUsage $Orch

# ---- lead packet: ONE compact read at session start / after compaction (instead of opening 7 files)
if ($LeadPacket) {
  "=== LEAD PACKET $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  if (Test-Path -LiteralPath $ho) {
    $act = @(); foreach ($l in [IO.File]::ReadAllLines($ho, $script:Utf8)) { if ($l -match '^---\s*$' -or $l -match '^##\s*G.nl.k') { break }; if ($l.Trim() -and $l -notmatch '^>') { $act += $l } }
    "--- handoff (active part)"; $act | Select-Object -First 40
  }
  $ev = Join-Path $Orch 'events.md'
  if (Test-Path -LiteralPath $ev) { "--- last events (automatic journal)"; Get-Content -LiteralPath $ev -Encoding UTF8 -Tail 10 | Where-Object { $_ -like '- *' } }
  if ($unreviewed) { "--- UNREVIEWED runs ($($unreviewed.Count); newest 8)"; foreach ($u in ($unreviewed | Select-Object -First 8)) { $sum = ''; if (Test-Path -LiteralPath $u.report) { $sum = (Get-Content -LiteralPath $u.report -Encoding UTF8 | Where-Object { $_ -match '^\s*[-*]' } | Select-Object -First 2 | ForEach-Object { $_.Trim().Substring(0, [Math]::Min(110, $_.Trim().Length)) }) -join ' | ' }; "- $($u.name) [$($u.role)] $($u.state) gate=$($u.gate) $($u.reason) :: $sum" } }
  $running = @($agents | Where-Object state -eq 'running'); if ($running) { "--- running: " + (($running | ForEach-Object { "$($_.name)[$($_.role), $([int]((Get-Date)-[datetime]$_.started).TotalMinutes)m, turns $($_.turns)]" }) -join ', ') }
  if ($tasks) { "--- tasks: " + (($tasks | Group-Object status | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ') }
  if ($cooling) { "--- cooling: " + (($cooling | ForEach-Object { "$($_.model) until $($_.until)" }) -join '; ') }
  if ($cu) { "--- claude account: 5h " + $cu.five_hour.utilization + " / 7d " + $cu.seven_day.utilization + " (at $($cu.at))" }
  if ($wts) { "--- worktrees: " + (($wts | ForEach-Object { "$($_.name)=$($_.branch)" }) -join ', ') }
  $repo = Split-Path -Parent $Orch
  $gl = (Invoke-Git $repo @('log','--oneline','-3')).out | Where-Object { $_ -and $_ -notmatch '^(warning|fatal)' }; if ($gl) { "--- git: " + ($gl -join ' | ') }
  "--- read on demand only: decisions.md, acceptance.md, lessons.md, team.json, plan.md, reports/<name>.md (inspect-run.ps1 first)"
  return
}

# ---- terminal
if ($unreviewed) { "=== UNREVIEWED (finished after the last handoff update)"; $unreviewed | ForEach-Object { "- $($_.name): $($_.state) gate=$($_.gate) $($_.reason)" } }
"=== AGENTS"; $agents | Select-Object -First 15 name, role, model, state, gate, started, reason | Format-Table -AutoSize | Out-String -Width 220
if ($tasks) { "=== TASKS: " + (($tasks | Group-Object status | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  ') }
if ($cooling) { "=== COOLING"; $cooling | Format-Table -AutoSize | Out-String -Width 200 }
if ($owner) { "=== WAITING FOR OWNER"; $owner | ForEach-Object { "- $_" } }
if ($perModel) { "=== MODELS"; $perModel | Format-Table -AutoSize | Out-String -Width 200 }
if ($reasons) { "=== RECURRING PROBLEMS (add lessons to lessons.md)"; $reasons | ForEach-Object { "$($_.Count)x $($_.Name)" } }

if ($NoHtml) { return }
$css = 'body{font:14px system-ui,Segoe UI,sans-serif;margin:24px;background:#fafafa;color:#222}h1{font-size:20px}h2{font-size:16px;margin-top:28px}table{border-collapse:collapse;width:100%;background:#fff}td,th{border-bottom:1px solid #e5e5e5;padding:6px 8px;text-align:left;vertical-align:top}th{background:#f0f0f0}.running{color:#0a58ca}.done{color:#18794e}.failed,.denied,.stalled,.auth,.loop{color:#c62828}.limited,.timeout,.incomplete,.budget{color:#b26a00}.small{color:#777;font-size:12px}'
$rows = ($agents | Select-Object -First 30 | ForEach-Object {
  $age = if ($_.ended) { '' } else { [int]((Get-Date) - [datetime]$_.started).TotalMinutes }
  "<tr><td>$(ConvertTo-HtmlText $_.name)</td><td>$(ConvertTo-HtmlText $_.role)</td><td>$(ConvertTo-HtmlText $_.model)</td><td class='$(ConvertTo-HtmlText $_.state)'>$(ConvertTo-HtmlText $_.state)$(if($age -ne ''){" ($age min)"})</td><td>$(ConvertTo-HtmlText $_.gate)</td><td>$(ConvertTo-HtmlText $_.started)</td><td>$(ConvertTo-HtmlText $_.reason)</td></tr>" }) -join ''
$taskRows = ($tasks | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.id)</td><td>$(ConvertTo-HtmlText $_.title)</td><td>$(ConvertTo-HtmlText $_.type)</td><td>$(ConvertTo-HtmlText $_.status)</td><td>$(ConvertTo-HtmlText (@($_.deps) -join ', '))</td><td>$(ConvertTo-HtmlText $_.agent)</td></tr>" }) -join ''
$doneCount = @($tasks | Where-Object status -eq 'accepted').Count
$html = @"
<!doctype html><html lang='tr'><head><meta charset='utf-8'><meta http-equiv='refresh' content='30'><title>Orkestrasyon panosu</title><style>$css</style></head><body>
<h1>Orkestrasyon panosu</h1><div class='small'>$(ConvertTo-HtmlText (Split-Path -Parent $Orch)) - guncellendi $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - 30 sn'de bir yenilenir</div>
<h2>Lider incelemesi bekleyen calismalar</h2>$(if($unreviewed){'<ul>' + (($unreviewed | ForEach-Object { "<li>$(ConvertTo-HtmlText $_.name): $(ConvertTo-HtmlText $_.state) kapi=$(ConvertTo-HtmlText $_.gate)</li>" }) -join '') + '</ul>'}else{'<p class=small>yok</p>'})
<h2>OWNER kararini bekleyenler</h2>$(if($owner){'<ul>' + (($owner | ForEach-Object { "<li>$(ConvertTo-HtmlText $_)</li>" }) -join '') + '</ul>'}else{'<p class=small>yok</p>'})
<h2>Ajanlar</h2><table><tr><th>Ad</th><th>Rol</th><th>Model</th><th>Durum</th><th>Kapi</th><th>Baslangic</th><th>Not</th></tr>$rows</table>
<h2>Gorevler ($doneCount / $($tasks.Count) kabul)</h2><table><tr><th>ID</th><th>Gorev</th><th>Tur</th><th>Durum</th><th>Bagimlilik</th><th>Ajan</th></tr>$taskRows</table>
<h2>Kota / bekleyen modeller</h2>$(if($cooling){'<table><tr><th>Model</th><th>Acilis</th><th>Neden</th></tr>' + (($cooling | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.model)</td><td>$(ConvertTo-HtmlText $_.until)</td><td>$(ConvertTo-HtmlText $_.reason)</td></tr>" }) -join '') + '</table>'}else{'<p class=small>tum modeller acik</p>'})
<h2>Worktree'ler</h2>$(if($wts){'<table><tr><th>Ad</th><th>Dal</th><th>Yol</th></tr>' + (($wts | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.name)</td><td>$(ConvertTo-HtmlText $_.branch)</td><td>$(ConvertTo-HtmlText $_.path)</td></tr>" }) -join '') + '</table>'}else{'<p class=small>kayit yok</p>'})
<h2>Model istatistikleri</h2>$(if($perModel){'<table><tr><th>Model</th><th>Calisma</th><th>Basarili</th><th>Kapi gecti</th><th>Bosa giden</th><th>Ort. dk</th><th>Ort. tur</th><th>Token giris/cikis (bin)</th></tr>' + (($perModel | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.model)</td><td>$($_.runs)</td><td>$($_.done)</td><td>$($_.gatePass)</td><td>$($_.wasted)</td><td>$($_.avgMin)</td><td>$($_.avgTurns)</td><td>$($_.kTokIn) / $($_.kTokOut)</td></tr>" }) -join '') + '</table>'}else{'<p class=small>henuz veri yok</p>'})
<h2>Tekrarlayan sorunlar</h2>$(if($reasons){'<ul>' + (($reasons | ForEach-Object { "<li>$($_.Count)x $(ConvertTo-HtmlText $_.Name)</li>" }) -join '') + '</ul>'}else{'<p class=small>yok</p>'})
</body></html>
"@
$out = Join-Path $Orch 'dashboard.html'
Write-Text $out $html
"DASHBOARD: $out"
