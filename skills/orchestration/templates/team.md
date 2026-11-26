# Ekip (roster)

Bu dosya insan için; betikler `team.json`'u okur — ikisini birlikte güncelle.
Son değişiklik: <YYYY-MM-DD> — <neden>

| Rol (`-Role`) | Motor | Model | Mod | Görev |
|---|---|---|---|---|
| Lider | Claude Code (bu oturum) | Opus 5.5 medium — OWNER isteyince değişir | — | Yönetir, ölçer, hakemlik yapar, birleştirir. Ürün kodu yazmaz |
| İşçi (`worker`) | agy | `gemini-4-neon-medium` | accept-edits | Ürün kodu ve normal işler |
| İşçi 2 (`worker2`) | Claude Code CLI | `claude-sonnet-5-5`, effort medium | acceptEdits | İşçiyle aynı kapsam; **paralel** işler için (yedek değil) |
| Test (`tester`) | agy | `gemini-4-hydrogen-high` | accept-edits | Test yazar/çalıştırır. Ürün kodunu değiştirmez |
| Hakem / bağımsız denetim (`auditor`) | agy | `gemini-4-hydrogen-high` | plan (salt okunur) | Bağımsız denetim, hakem kararı |
| Mimar (`architect`) | agy | `gemini-4-carbon-medium` | accept-edits | Mimari kararlar, çok zor kod |
| Araştırmacı (`researcher`) | agy | `gemini-4-hydrogen-xhigh` | plan (salt okunur) | Araştırma, karşılaştırma, kök neden |

Not: agy'de `--mode auto` yok; `accept-edits` veya `plan`.

## Yönlendirme (`-TaskType`, team.json `routing`)
- code → worker → (2. deneme) architect · hardcode/design → architect · test → tester · audit/referee → auditor · research → researcher
- Paralel kod işleri `scheduler.ps1` ile worker ve worker2 arasında dönüşümlü dağıtılır.

## Yedek modeller (kota defteri soğumadaysa otomatik)
- İşçi → `gemini-4-neon-low` · Test/hakem → `gemini-4-hydrogen-medium` · Mimar → `claude-opus-5-5-medium` (agy) · Araştırmacı → `gemini-4-hydrogen-high` · İşçi 2 → yok (Claude Code limiti dolarsa işi worker'a ver)

## İzinler
- Ajanlar yalnızca **birebir** izinli komutları çalıştırır (`-AllowCommands`, `-Profiles`; `commandProfiles` team.json'da).
- `-SkipPermissions` (tüm komutlar serbest): <kullanılmıyor | OWNER onayı: tarih>

## Sınırlar (team.json `limits`)
- maxParallel 3 · bir worktree'de tek ajan · cooldownMin 300 · idleMin 10 · defaultTimeoutMin 60
