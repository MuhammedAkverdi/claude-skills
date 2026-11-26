# Lead ops handoff — <proje adı>

> Yeni/sıkıştırılmış oturum: önce bu dosya, sonra team.md, team.json, plan.md, tasks.json, decisions.md, acceptance.md, lessons.md;
> sonra status-board.ps1 -NoHtml ("UNREVIEWED" = bu dosyadan sonra biten, incelenmemiş çalıştırmalar);
> sonra status/*.json + okunmamış reports/*.md; sonra `git status`, `git log --oneline -5`, `git worktree list`.
> Çalışan ajan varsa watch.ps1'i arka planda yeniden başlat. Genel görünüm: status-board.ps1 (dashboard.html).
> Sıradaki işler: scheduler.ps1 next · Worktree'ler: worktree.ps1 list · Dersler: lessons.md
> Son güncelleme: <YYYY-MM-DD HH:MM> — lider: <model>

## Hedef
<1–3 satır: amaç ve "bitti" tanımı>

## Şu anki durum
- Ana dal / HEAD: `<branch>` @ `<sha>`
- Entegrasyon dalı: `<int/...>` @ `<sha>` (varsa)
- Son kabul edilen aday: `<sha>` — ölçüm: <özet sayılar>
- Gizli kontroller: `%USERPROFILE%\.claude\orchestrator-private\<proje>\`

## Worktree'ler
| Yol | Dal | HEAD | Sahibi (ajan) | Commit edilmemiş iş |
|---|---|---|---|---|

## Çalışan ajanlar
| Ad | Rol | Model | Worktree | Başlangıç | Durum |
|---|---|---|---|---|---|

## Son doğrulanan çalıştırma
- `<ajan adı>` (`<runId>`) — <DONE, doğrulandı/reddedildi, neden>

## Aktif yedek modeller / sınırlar
- <ör. worker → gemini-4-neon-low (Neon 5 sa limit, ~HH:MM açılır)>

## Son ölçümler (lider)
| Tarih | Aday SHA | Test/ölçüm | Sonuç | Not |
|---|---|---|---|---|

## Kuyruk
1. 

## Açık riskler / OWNER kararı bekleyenler
- 

## Sonraki adım
<tek cümle>

---
## Günlük (en yeni üstte)
- <YYYY-MM-DD HH:MM> <olay>
