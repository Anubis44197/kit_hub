# Tam Aktifleşme Planı — 2026-09-18 başlangıç

**Amaç:** Yarı aktif/pasif durumdaki tüm bileşenleri (Observer, Hafıza, codebase-memory, OmniRoute, Headroom) gerçek, kanıtlı şekilde tam aktif hâle getirmek.

## DEVAM KURALI (bu dosyayı okuyan ajana/kişiye)

1. Aşağıdaki **"Nereden devam ediliyor"** satırına bak → oradaki gün/adımdan başla.
2. Her adımın durumu: `[BEKLİYOR]` / `[DEVAM]` / `[TAMAM]` / `[ENGELLI: sebep]`.
3. Bir adım bitince durumu güncelle + dosyanın en altındaki **Durum Günlüğü**'ne tarihli satır ekle.
4. Engel çıkarsa adımı `[ENGELLI: ...]` yap, çözüm notunu yanına yaz, sıradaki bağımsız güne geç.

**Nereden devam ediliyor → PLAN TAMAMLANDI (2026-09-19):** Gün 1–6'nın tüm adımları kapandı; 6.3 temiz commit kullanıcı onayıyla yapıldı. OmniRoute sağlayıcı bağlaması (Gün 4) hariç — o hâlâ kullanıcı kararı bekliyor.

---

## GÜN 1 (2026-09-18) — Observer'ı görev koşularına bağla `[TAMAM]`

- [x] 1.1 `scripts/capture_observer_snapshot.ps1`: adapter config okuyan, `status --json` + `usage --json --since 30d` alan (timeout'lu), `runtime/agent-runs/<runId>/observer.jsonl`'a yazan, **fail-open** betik. — `[TAMAM]` (DB boşken usage atlanır: `observer_db_empty`; `KITHUB_OBSERVER_FORCE_USAGE=1` ile zorlanır)
- [x] 1.2 `scripts/run_task_provider.ps1`: doğrulamadan sonra snapshot çağrısı (hata görevi düşürmez). — `[TAMAM]` (aynı süreçte `exit` tuzağına karşı verifier+snapshot ayrı alt süreçte çağrılır)
- [x] 1.3 e2e (`scripts/ci/studio_task_e2e_test.ps1`) ile gerçek koşuda `observer.jsonl` kanıtı. — `[TAMAM]` (e2e PASS: "observer snapshot: 2 kayıt"; e2e artık runner'ın son adımlarını bekliyor + temp projeye `runtime/adapters` kopyalanıyor + snapshot binary'si repo köküne fallback yapıyor)
- [x] 1.4 `runtime/adapters/observer.json` → `enabled: true`. — `[TAMAM]`
- **Kabul kriteri:** Görev koşusu `runtime/agent-runs/<runId>/observer.jsonl` üretir (status snapshot en az); görev başarısı etkilenmez. — **KARŞILANDI**

## GÜN 2 (2026-09-19) — Hafıza motoru (claude-mem uyarlaması) `[TAMAM]`

- [x] 2.1 SQLite mevcudiyet kararı. — `[TAMAM]` sqlite3.exe ve .NET SDK yok → **jsonl_compat depo** (`runtime/memory/records.jsonl`, tek satır = tek kayıt; şema alanları birebir, ileride SQLite'a taşınabilir)
- [x] 2.2 `scripts/save_memory_record.ps1`. — `[TAMAM]` verification kaydı üretir; zorunlu/yasak alan kontrolü + bağımsız doğrulayıcı; decision alanı artifact özetlerinden çıkar. Not: doğrulayıcı başarıda açık `exit 0` yazmadığından karar JSON `valid` alanından okunur (`$LASTEXITCODE` tuzağı)
- [x] 2.3 runner bağlama (şema ihlali görevi düşürmez, kanıt kaybı loglanır) + `build_context_pack.ps1` artık `same_project_same_book_relevant_phase` seçicisiyle hafıza kayıtlarını pack'e ekliyor + prompt önizlemesinde `memory` bölümü. — `[TAMAM]`
- [x] 2.4 e2e kanıtı. — `[TAMAM]` 2 koşulu senaryo: 1. koşu kayıt bırakır, 2. koşunun context-pack'i o kaydı taşır ("hafiza zinciri OK")
- **Kabul kriteri:** Görev koşusu hafıza kaydı bırakır; doğrulayıcı pass; ikinci koşuda bağlam artar. — **KARŞILANDI**

## GÜN 3 (2026-09-20) — codebase-memory-mcp DACL engeli `[TAMAM]`

**Kök neden KESİNLEŞTİ (2026-09-18):**

- Binary'nin tam hata metni: `exact executable identity could not be verified (cache-private) - C:\Users\90535: DACL entry 0 grants mutation rights 0x00010152 to untrusted identity (other S-1-5-21-3623384205-1531654273-3415129787-3908196827)`.
- Şikâyet edilen SID bu makineye **ait değil**: yerel hesap uzayı `S-1-5-21-449668404-…`, o SID `S-1-5-21-3623384205-…` → başka makine/sandbox kalıntısı. Hiçbir hesaba çözülemiyor, ProfileList'te kaydı yok → **yetim (orphan) ACE**; kaldırılması hiçbir hesabı etkilemez.
- `icacls` ile kaldırılamıyor: exit **1332** (ERROR_NONE_MAPPED) — çözülemeyen SID'i işleyemiyor.
- `Set-Acl` ile kaldırılamıyor: profil kökünde **1 SACL (denetim) kuralı** var; `Set-Acl` SACL'i de yazmaya çalıştığı için **yönetici olsa bile** `PrivilegeNotHeldException` (SeSecurityPrivilege) veriyor.
- **Çözüm hazır:** `scripts/ci/remove_orphan_profile_ace.ps1` — SDDL'den DACL'i ayıklayıp **yalnızca DACL** yazar (`SetNamedSecurityInfo`, `DACL_SECURITY_INFORMATION=0x4`). Sahipliğe ve SACL'e dokunmaz → **yönetici GEREKMEZ**. Yerel API yöntemi zararsız klasörde test edildi: durum 0, anında.
- Betik `-WhatIfOnly` ile doğrulandı: 5 ACE'nin **yalnızca 1'i** hedefleniyor; SYSTEM, Administrators, kullanıcı ve kabiliyet SID'i (`S-1-15-3-*`) korunuyor.


- [x] 3.1 Takılı süreç kendiliğinden bitti; **ACL cerrahisine gerek KALMADI** (aşağıdaki çözüm). `remove_orphan_profile_ace.ps1` yalnızca teşhis aracı olarak duruyor, önerilen yol değil. — `[TAMAM]`
- [x] 3.2 **ÇÖZÜM:** `scripts/install_codebase_memory.ps1` — hash doğrulama + temiz-zincir kurulumu + ata zinciri denetimi + sonda. Kanonik yol: `%LOCALAPPDATA%\Programs\codebase-memory-mcp\`. **Kullanıcı klasörlerinin ACL'lerine hiç dokunulmadı.** — `[TAMAM]`
- [x] 3.3 `scripts/ci/codebase_memory_stdio_probe.ps1` → **PASS** (`ok:true`, 0.11.0, **17 araç**, init 5,3 sn). Sonda olay-tabanlı okumaya çevrildi. — `[TAMAM]`
- [x] 3.4 `scripts/ci/codebase_memory_fixture_test.ps1` → gerçek indeksleme + arama **PASS**: `index_repository` 10 düğüm/15 kenar, `index_status: ready`, `search_graph` → `kithub-cbm-fixture.src.util.greet` (`src/util.js` 1-3), `delete_project` ile temizlik. — `[TAMAM]`
- [x] 3.5 `runtime/adapters/codebase-memory-mcp.json` → `enabled: true` + `binary_resolution` + kanıt yolları. Envanter: `binary_present:true`, `version: 0.11.0`, SHA doğrulandı; sözleşme testi: **enabled with evidence**. — `[TAMAM]`
- [x] 3.6 **Kabul kriteri:** `scripts/query_codebase_graph.ps1` + `build_context_pack.ps1 -IncludeCodebaseContext` → pakette `codebase.status: ok`, `source: codebase-memory-mcp`, 6000 bayt gerçek grafik (2883 düğüm/5102 kenar, 7 sn). Varsayılan kapalı + fail-open; kapatınca paket parmak izi değişmiyor. — **KARŞILANDI**

**Çözümün kanıtlanmış gerekçesi (eskik yaklaşım neden gereksizdi):**

- Binary, exe yolunun **ata zincirinde** "güvenilmeyen" kimliğe mutasyon hakkı veren ACE arıyor. Proje `Desktop` altında olduğu için zincir kirli: `Desktop`'ta 5 yabancı kayıt (biri gerçek hesap `CodexSandboxUsers`, dördü başka makinelere ait yetim SID), `kit_hub-main`'de 3 yabancı + 1 yetim, `Temp`'te 6. **Aynı binary temiz zincirde sorunsuz çalışıyor** → ACL temizliği gereksiz çıktı.
- Eski yaklaşım kullanıcı profilinin ACL'ini değiştirmeyi gerektiriyordu: `icacls` çözülemeyen SID'i işleyemiyor (1332), `Set-Acl` profil kökündeki SACL yüzünden **yöneticide bile** `SeSecurityPrivilege` istiyor. Artık hiçbiri gerekmiyor.
- Binary zincir yürüyüşünü **profil kökünde durduruyor**; `C:\` üzerindeki `Authenticated Users` gibi OS varsayılanlarını sorun saymıyor (kanıt: exe Desktop'tayken yalnızca `C:\Users\90535` ve `Desktop` şikâyet edildi).
- Ölümcül teşhis hatası düzeltildi: eski sonda `Peek()` ile yokluyordu ve daemon günlüğü `method=tools/list status=ok` derken sonda "yanıt yok" diyordu; artık çıktılar olay tabanlı okunuyor (`scripts/ci/lib_mcp_stdio.ps1`).
- Sınır: repo içindeki `.tools` kopyası bu yüzden **başlatılamaz**; adaptör kurulum yolunu kullanır (aynı hash `7edcd38…`, kanıt: `runtime/fixture-reports/codebase-memory-install.json`).
- **Not:** `AppData\Local\Temp` gibi alt dizinlerde de birden çok yetim SID var (7 adet, çeşitli makine SID'leri). Binary yalnızca exe'nin **ata zincirini** denetlediği için önce profil kökü yeterli olabilir; gerekirse aynı betik `-ProfilePath` ile o dizinlere de uygulanır.

## GÜN 4 (2026-09-21) — OmniRoute tam aktif `[BEKLİYOR — kullanıcı kararı]`

- [ ] 4.1 **KULLANICI KARARI:** OmniRoute dashboard'dan sağlayıcı bağlama (OpenAI anahtarı var ama kredi 0; Ollama upstream alternatifi dashboard kurulumu istiyor)
- [ ] 4.2 `scripts/ci/omniroute_propose_fixture.ps1` PASS (gerçek completion)
- [ ] 4.3 `runtime/adapters/omniroute.json` → `enabled: true` + canary regresyonu
- **Kabul kriteri:** propose fixture gerçek model yanıtı döndürür.
- Not: 4.1 olmadan bu gün kilitli; otomatik yapılabilecek her şey 4.2 öncesi hazırdır.

## GÜN 5 (2026-09-22) — Headroom gerçek motor (pilot) `[TAMAM]`

- [x] 5.1 `scripts/headroom_reduce.ps1` — deterministik motor. `repeated_log` (JSON-lines gruplama: değişken alanlar maskelenir, `_headroom_count` + `_headroom_last_<alan>`), düz metin (birebir tekrar toplama), `large_json`/JSON `tool_output` (4096+ string kırpma, 300+ dizide ilk 150 + son 150, atlanan aralıklar `_headroom_elided`). `preserve_fields` **değeri taşıyan elemanlar asla atlanmaz**. Her hata/yetersiz kazanç → **fail-open `raw_content`**. — `[TAMAM]`
- [x] 5.2 Pilot A/B (gerçek depo dosyaları, `-Force` yok, gerçek politika): `102 KB log → 54 KB (%48)`, `59 KB integrity raporu → 28 KB (%53)`, `52 KB deepcheck → 11 KB (%78)`; `23 KB rapor` boyut eşiği altında → fallback (doğru). Bütünlük: çıktı JSON'ları parse edilebilir + `preserve_fields` denetimi geçti. Kanıt: `runtime/fixture-reports/headroom-pilot.json`. — `[TAMAM]`
- [x] 5.3 `enabled: true`; `max_input_bytes` 1 MiB → **32 KiB** (gerçek log/rapor boyutları 20–100 KiB olduğu için 1 MiB eşiği katmanı hiç devreye sokmuyordu). Kitap metni/sözleşme/bağlam paketi/kanıt `excluded` kaldı. — `[TAMAM]`
- [x] 5.4 Bonus: `headroom_policy_check.ps1` eşikleri artık yapılandırmadan okuyor (eskiden 1048576 sabit kodluydu ve `min_reduction_ratio` raporlanmıyordu). — `[TAMAM]`
- **Kabul kriteri:** En az bir girdide ölçülmüş ≥%15 kısaltma (3 vakada %48–%78), hiçbir yasak içerik tipine dokunulmaz (kapı testi: `creative_text` → `eligible:false, reason:content_type_excluded`). — **KARŞILANDI**
- **Not (dürüst sınır):** Kitap koşusu içinde modele giden tüm içerik tipleri (sözleşme, bağlam paketi, yaratıcı metin) politikayla `excluded`. Bu nedenle Headroom aracı/log/JSON çıktılarında devrede; kitap metnine asla dokunmaz. Bu tasarım gereği, eksiklik değil.

## GÜN 6 (2026-09-23) — Final regresyon + rapor + commit `[DEVAM]`

- [x] 6.1a Adapter kanıt kapıları: `adapter_inventory_contract_test.ps1` **PASS** (yeni kural: "kanıtsız adapter açılamaz" — eski "hiçbiri açılmamalı" varsayımı yerine). Çıktı: codebase-memory + omniroute `disabled (fail-closed)`, observer + headroom `enabled with evidence`. — `[TAMAM]`
- [x] 6.1b `adapter_canary_report.ps1`: Headroom bölümü artık pilot kanıtını raporluyor → `status: enabled_pilot_proven`, `best_reduction_ratio: 0.7799`, `creative_text_eligible: false`; `rollout: evidence_gated_activation`. — `[TAMAM]`
- [x] 6.1c Kalan regresyon turu — **hepsi PASS**: `studio_task_e2e_test.ps1` (gerçek Ollama qwen2.5:3b, 2 koşu: artifact + `observer snapshot: 2 kayıt` + `hafiza zinciri OK` + verifier `pass` + görev `completed`), `npm run test:typography` PASS, `memory_isolation_test.ps1` PASS (selected=1, conflicts=2), `final_readiness_check.ps1` PASS (skill-standard 13, skill-evals 3, agent-governance), `task_engine_runtime_test.ps1` PASS, `adapter_canary_report.ps1` (headroom `enabled_pilot_proven`, best 0.7799). — `[TAMAM]`
- [x] 6.2 `docs/2026-09-18_TAM_AKTIFLESME_RAPORU.md` — Observer + Hafıza + Headroom + codebase-memory kanıtlarıyla toplu rapor; `README.md`'deki eski "DACL engelli / hepsi kapalı" ifadeleri güncellendi. — `[TAMAM]`
- [x] 6.3 Temiz commit — **TAMAM** (2026-09-19, kullanıcı onaylı tek commit; 126 dosya: story_state hikâye hafızası + planın birikmiş tüm çıktıları; üretilmiş raporlar ve records.jsonl .gitignore'a alındı, schema.json versiyonlandı)

---

## Engel / Karar Notları

- **OpenAI API kredisi 0** (credit_balance_exhausted) — kullanıcı "sonraya bakarız" dedi; model sağlayıcı konusu bu plandan bağımsız bekliyor.
- **OmniRoute upstream** dashboard/DB kurulumu istiyor (kullanıcı onaylı adım).
- **DACL** yalnızca yükseltilmiş izinle çözülür; plan Gün 3'te onay akışına bağlı.

## Durum Günlüğü

- **2026-09-18:** Plan oluşturuldu. Gün 1 başladı. Devam noktası: Gün 1 / Adım 1.1.
- **2026-09-18:** Gün 1 TAMAM. `capture_observer_snapshot.ps1` yazıldı (fail-open, 1 sn), runner'a bağlandı (verifier/snapshot ayrı alt süreçte — `exit` tüm süreci öldürür tuzağı düzeltildi), e2e PASS: run `run-a23aa58cc16e4bc596600d1927fcbba9` → `_workspace/01_proposals.md` + `observer.jsonl` (2 kayıt) + verifier pass + görev completed. `observer.json` `enabled:true`. E2e'ye eklenenler: runner-bitiş bekleme döngüsü, temp projeye adapters kopyası, observer kanıt doğrulaması. Devam noktası: Gün 2 / Adım 2.1.
- **2026-09-18:** Gün 2 TAMAM. jsonl_compat depo kararı; `save_memory_record.ps1` + runner bağlama + context-pack hafıza entegrasyonu + prompt `memory` bölümü. E2e 2-koşulu senaryo PASS: "hafiza kaydi (1. kosu): 1" → "hafiza kaydi (2. kosu): 2" → "hafiza zinciri OK: 2. kosu baglami 1 kayit tasiyor". Düzeltmeler: e2e temp projeye memory şeması kopyalanıyor; doğrulayıcı kararı JSON `valid` alanından okunuyor. Devam noktası: Gün 3 / Adım 3.1 (yükseltilmiş izin gerekir).
- **2026-09-18 (devam 2):** **Gün 5 TAMAM.** Headroom'un eksik motoru yazıldı (`scripts/headroom_reduce.ps1`), gerçek veride ölçüldü: log %48, integrity raporu %53, deepcheck %78 kısaltma; `enabled: true` (boyut eşiği 32 KiB). Bu iş sırasında üç GERÇEK hata bulunup düzeltildi: (1) dosya sonundaki boş satır JSON-lines gruplamayı tamamen devre dışı bırakıyordu, (2) `preserve_fields` denetimi `OrderedDictionary`'yi anahtarlar yerine .NET üyeleri üzerinden gezdiği için hem yanlış alarm hem sahte "geçti" üretiyordu, (3) politika kapısı eşiği sabit kodluydu (1048576). Ayrıca envanter testi "kanıtsız adapter açılamaz" kuralına çevrildi ve canary raporu pilot kanıtını gösteriyor. Devam noktası: Gün 6 / 6.1c.
- **2026-09-18 (devam):** Gün 3 kök nedeni kesinleşti ve **yönetici gerektirmeyen çözüm yazıldı** (`scripts/ci/remove_orphan_profile_ace.ps1`, DACL-only). `icacls` (1332) ve `Set-Acl` (SeSecurityPrivilege/SACL) neden çalışmadığı kanıtlandı; yeni yöntem zararsız klasörde test edildi (durum 0). Engel: 12:30'daki yükseltilmiş denemeden kalan takılı süreç (PID 6644/15004) profil kökünü kilitliyor; yönetici onayı bekliyor (onay isteği zaman aşımına düştü). Devam noktası: Gün 3 / Adım 3.1, sonra Gün 5 paralel ilerletilebilir.
- **2026-09-18 (devam 3) — GÜN 3 TAMAM, ACL cerrahisi GEREKSİZ ÇIKTI:** Takılı yükseltilmiş süreç kendiliğinden bitti. Yeni teşhis: sonda `Peek()` ile yokluyordu ve daemon günlüğü `tools/list status=ok` derken sonda "yanıt yok" diyordu (ölümcül teşhis hatası). Sonda olay-tabanlı okumaya çevrildi (`scripts/ci/lib_mcp_stdio.ps1`) ve binary `%LOCALAPPDATA%\Programs\codebase-memory-mcp\` (temiz zincir) yolundan çalıştırıldı → **PASS: 0.11.0, 17 araç**. Yeni araçlar: `scripts/install_codebase_memory.ps1` (hash+zincir+sonda kanıtı), `scripts/ci/codebase_memory_fixture_test.ps1` (gerçek indeksleme+arama), `scripts/query_codebase_graph.ps1` (adaptörün gerçek kullanım noktası). `build_context_pack.ps1` artık `-IncludeCodebaseContext` ile MCP kaynaklı `codebase` bölümü ekliyor (varsayılan kapalı, fail-open). Adaptör `enabled: true`; sözleşme testi: enabled with evidence. **Kullanıcı klasörlerinin ACL'lerine dokunulmadı.**
- **2026-09-19:** `build_context_pack.ps1` book_id uyumsuzluğu düzeltildi: seçiciye sabit `default-book` gönderiliyordu, oysa `save_memory_record.ps1` book_id'yi brief başlığından türetiyordu → başlıklı gerçek projede hafıza zinciri sessizce 0 kayda düşerdi. Artık ikisi aynı türetmeyi kullanıyor (brief başlığı slug → `default-book`). Kanıt: başlıklı sahte projede context-pack `memory_count=1` (BOOK_ID_MATCH_OK); `memory_isolation_test.ps1` PASS. Devam noktası: Gün 6 / 6.3.
- **2026-09-19 (devam) — HİKÂYE HAFIZASI BAĞLANDI (story_state):** Kullanıcı onayıyla hafıza zinciri artık hikâye durumunu da taşıyor. `runtime/memory/schema.json` → `record_types`'a `story_state` eklendi + `story_selector: same_project_same_book_recent_story_state`, `story_state_recent_count: 3`. Yeni `scripts/save_story_state_record.ps1`: bölüm/koşu sonunda `revision/_state/character-state.json` (karakter@konum+durum), `plot-ledger.json` (son 5 olay), `continuity-ledger.json` (son 3 ihlal) özetini şema-uyumlu kayda çevirir (fail-open, ~600 karakter). `select_memory_records.ps1`: aynı proje+kitabın **son N story_state kaydını fazdan bağımsız** seçer (eski faz seçimi aynen korunur; kitaplar arası izolasyon korunur). `build_context_pack.ps1`: pakete `story_state` bölümü eklendi. `run_task_provider.ps1`: doğrulama sonrası story_state kaydı yazar (fail-open). Yeni CI: `scripts/ci/story_state_memory_test.ps1` — 5 kanıt (kayıt üretimi, book_id türetme, faz-dışı seçim, pack bölümü, kitap izolasyonu) **PASS**. Regresyonlar: memory_isolation PASS, task_engine_runtime PASS, typography PASS, **tam e2e PASS** (gerçek Ollama qwen2.5:3b; 1. koşu 2 kayıt → 2. koşu 4 kayıt: zincir büyüyor). Sınır: defterler mevcut değilse kayıt yine yazılır ama özet 'Durum defterleri bos/okunamadi' olur (fail-open); defter doldurucu ajan entegrasyonu sonraki planın işi. Devam noktası: Gün 6 / 6.3 (commit).
- **2026-09-19 (devam 2) — 6.3 TAMAM, PLAN KAPANDI:** Kullanıcı onayıyla tek temiz commit: `93a30b4` (126 dosya, +11080/−409). Kapsam: story_state hikâye hafızası + Gün 1–6'nın tüm birikmiş çıktıları (Observer, hafıza, Headroom, codebase-memory, task engine, bridge, CI). .gitignore düzeltmesi: `runtime/memory/records.jsonl` yok sayılıyor, sözleşme (`schema.json`) versiyonlanıyor; `run-integrity-report.json` + `state-consistency-report.json` üretilmiş rapor olarak eklendi. Kalan tek açık madde: Gün 4 OmniRoute sağlayıcı bağlaması (kullanıcı kararı).
- **2026-09-18 (devam 3) — GÜN 6 regresyonu:** e2e (gerçek Ollama, 2 koşu) PASS; typography, memory isolation, final readiness, task engine runtime, adapter canary — hepsi PASS. Devam noktası: **Gün 6 / 6.3 (temiz commit hazırlığı, kullanıcı onayı)**.
