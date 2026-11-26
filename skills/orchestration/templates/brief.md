# Brief: <görev> — <YYYY-MM-DD>
Rol: <worker|worker2|tester|auditor|architect|researcher> · Ajan adı: <name> · Workdir/worktree: `<yol>` · Dal: `<branch>` · HEAD: `<sha>`
<Commit et (yalnız kendi dosyalarını adlarıyla ekle) | Commit etme>

## Bağlam
- Bağlayıcı kararlar: <decisions.md'den ADR-/R- numaraları ve tek satır özetleri>
- Önceki ajanlardan bağlam (salt okunur, `-Context` ile verilir): <artifacts/... dosyaları>
- İlgili dersler (lessons.md): <varsa 1–2 satır>

## Kapsam (yalnız bu dosyalar değişebilir; lider `-Scope` ile aynısını verir, kapı kontrol eder)
- `<ör. src/login/*>`
- `<ör. test/login*>`

## Kanıt (sorun)
<ölçülen sorun, sayılarla; somut örnek `dosya:satır`>

## Yapılacak
<genel kural/özellik + açık sınır durumları ve emin değilsen güvenli tarafta kal (fail-closed) davranışı>

## Zorunlu negatif testler
- <en az 2 / kural>

## İzinli komutlar (birebir; başkası reddedilir)
- `<ör. npm test -- login>`
- `<ör. git add src/login.js test/login.test.js>`
- `<ör. git commit -m "login: ...">`
(Lider aynı satırları `-AllowCommands` ile verir. Komut yoksa: yalnız dosya düzenle, çalıştırılması gereken komutları rapora yaz.)

## Kabul
- Odaklı testler: yukarıdaki komutlar
- Geniş regresyon: en fazla bir kez, en sonda. Tam ölçüm: lider.

## Yasaklar
- Gizli kabul testleri / beklenen çıktılar, kapsam dışı dosyalar
- `--amend`, `reset --hard`, `clean`, force-push, başka worktree'ye dokunma (`git push` ve paket kurma serbest: izinli komutlar listesine birebir yazılır)

## Rapor
Başlatma mesajında verilen **mutlak rapor yoluna** yaz (salt okunur rolde yalnız `BEGIN_REPORT` / `END_REPORT` arasında) — başlıklar:
- Özet (en fazla 10 satır) · Değişen dosyalar + commit SHA · Çalıştırılan komutlar + sonuçları
- Üretilen belgeler (artifacts) · Değişen arayüzler · Açık sorular · Sonraki ajan için bağlam
Sonra dur.

<!-- DEVAM (kesinti sonrası, yeni adla <name>-r2 başlatılırken eklenir): worktree durumu, commit edilmemiş iş, yarım merge -->
