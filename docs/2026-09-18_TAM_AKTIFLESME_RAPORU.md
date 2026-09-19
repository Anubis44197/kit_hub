# Tam Aktifleşme Raporu — 2026-09-18

Plan: `_planlar/2026-09-18_tam-aktiflesme-plani.md` (gün gün, yarıda kalırsa dosyadan devam edilebilir).

## Durum tablosu

| Bileşen | Önce | Şimdi | Kanıt |
|---|---|---|---|
| 36 ajanlık orkestrasyon | Aktif | Aktif (değişmedi) | e2e PASS, 65/65 beceri dosyası |
| Observer | Kurulu, 0 kayıt | **Aktif** (her görev koşusunda snapshot) | `runtime/agent-runs/<runId>/observer.jsonl` → `observer snapshot: 2 kayıt` |
| Hafıza (claude-mem uyarlaması) | Şema var, motor yok | **Aktif** (jsonl_compat depo + bağlam zinciri) | 1. koşu kayıt → 2. koşu bağlamı taşıyor: `hafiza zinciri OK` |
| Headroom | Kapı var, motor yok | **Aktif (pilot)** — gerçek motor, ölçülmüş kazanç | log %48, integrity %53, deepcheck %78; `enabled_pilot_proven` (0.7799) |
| codebase-memory-mcp | DACL engelinde, fallback | **Aktif** (read-only MCP, 17 araç) | probe PASS + fixture indeksleme/arama PASS + context-pack `source: codebase-memory-mcp` |
| OmniRoute | Gateway health PASS, çağrı kapalı | Yarı aktif (tek eksik: sağlayıcı bağlama) | canary PASS; completion `401` |
| Model sağlayıcı (OpenAI) | Kredi 0 | Bekliyor (kullanıcı kararı) | `credit_balance_exhausted` |

## 1. codebase-memory-mcp — DACL engeli çözüldü (ACL cerrahisi olmadan)

**Kök neden:** binary, **exe yolunun ata zincirinde** "güvenilmeyen" kimliğe *mutasyon hakkı* veren bir `Allow` kaydı arıyor; bulursa başlamayı reddediyor:

```
exact executable identity could not be verified (cache-private)
- C:\Users\90535\Desktop: DACL entry 0 grants mutation rights ... to untrusted identity (...)
```

Proje `Desktop` altında olduğu için zincir kirli (sandbox araçlarının bıraktığı kayıtlar):
`Desktop` → 5 yabancı kayıt (biri gerçek hesap `CodexSandboxUsers`, dördü başka makinelere ait yetim SID), `kit_hub-main` → 3 yabancı + 1 yetim, `Temp` → 6.

**Çözüm (kanıtlandı):** aynı binary (aynı SHA-256) **temiz zincirli kurulum dizininden** çalıştırılıyor:
`%LOCALAPPDATA%\Programs\codebase-memory-mcp\`. Kullanıcı klasörlerinin ACL'lerine **hiç dokunulmadı**.

Neden eski yaklaşım gereksizdi: `icacls` çözülemeyen SID'i işleyemiyor (`1332`), `Set-Acl` profil kökündeki bir SACL kuralı yüzünden **yöneticide bile** `SeSecurityPrivilege` istiyordu. Ayrıca binary zincir yürüyüşünü profil kökünde durduruyor ve `C:\` üzerindeki OS varsayılanlarını sorun saymıyor (kanıt: exe Desktop'tayken yalnızca `C:\Users\90535` ve `Desktop` şikâyet edildi).

Ayrıca **ölümcül teşhis hatası** düzeltildi: eski sonda `Peek()` ile yokluyordu ve daemon günlüğü `method=tools/list status=ok` derken sonda "yanıt yok" diyordu. Artık tüm stdio çıktıları **olay tabanlı** okunuyor (`scripts/ci/lib_mcp_stdio.ps1`).

**Kanıtlar**

- `scripts/install_codebase_memory.ps1` → `runtime/fixture-reports/codebase-memory-install.json`: hash doğrulandı, `ancestor_chain_clean: true`, `probe_ok: true`.
- `scripts/ci/codebase_memory_stdio_probe.ps1` → `runtime/fixture-reports/codebase-memory-probe.json`: `ok: true`, `0.11.0`, **17 araç**, init 5,3 sn.
- `scripts/ci/codebase_memory_fixture_test.ps1` → `runtime/fixture-reports/codebase-memory-fixture.json`: `index_repository` 10 düğüm/15 kenar, `index_status: ready`, `search_graph` → `kithub-cbm-fixture.src.util.greet` (`src/util.js` 1-3), `delete_project` ile temizlik.
- `scripts/query_codebase_graph.ps1` + `build_context_pack.ps1 -IncludeCodebaseContext` → context-pack'te `codebase.status: ok`, `source: codebase-memory-mcp`, 6000 bayt gerçek grafik (2885 düğüm/5102 kenar, 7 sn).

**Tasarım sınırı (bilinçli):** `codebase` bölümü **varsayılan kapalı**. Kitap projelerinde kod grafiği anlamsız olduğu ve her koşuda indeksleme maliyeti yaratacağı için yalnızca istendiğinde açılır ve açıkken bile **fail-open**'dır (adaptör kapalı/binary yok/hata → `status: fallback`, görev asla düşmez). Kapalıyken paket parmak izi değişmez.

## 2. Observer

`scripts/capture_observer_snapshot.ps1`: adaptör yapılandırmasını okur, `status --json` (+ veri varsa `usage --json --since 30d`) alır, `runtime/agent-runs/<runId>/observer.jsonl`'a yazar. **Fail-open**; boş veritabanında `usage` atlanır (koşuya ~30 sn eklemek yerine `observer_db_empty` kaydı düşer). Runner'da doğrulama adımından sonra, ayrı alt süreçte çağrılır (aynı süreçte `exit` çağrısı runner'ı öldürüyordu — düzeltildi).

## 3. Hafıza

`scripts/save_memory_record.ps1` (kanıt kaydı üretir; zorunlu/yasak alan kontrolü + bağımsız doğrulayıcı) + `select_memory_records.ps1` (`same_project_same_book_relevant_phase`) + `build_context_pack.ps1` entegrasyonu. Depo: `runtime/memory/records.jsonl` (sqlite3/.NET SDK olmadığı için şema alanları birebir korunarak; ileride SQLite'a taşınabilir). Doğrulayıcı başarıda `exit 0` yazmadığından karar JSON `valid` alanından okunur.

**2026-09-19 — Hikâye hafızası (story_state) eklendi:** bölüm sayısı arttıkça karakter konumları/olaylar/süreklilik ihlalleri hafıza zinciriyle taşınıyor. `schema.json` yeni `story_state` kayıt tipi + `story_state_recent_count: 3`; `scripts/save_story_state_record.ps1` (character-state/plot-ledger/continuity-ledger özetini şema-uyumlu kayda çevirir, fail-open); seçici aynı proje+kitabın son N story_state kaydını fazdan bağımsız taşır; context-pack `story_state` bölümü; runner her başarılı koşuda kaydı yazar. Kanıt: `scripts/ci/story_state_memory_test.ps1` PASS (5 kanıt) + tam e2e PASS (1. koşu 2 kayıt → 2. koşu 4 kayıt).

## 4. Headroom

`scripts/headroom_reduce.ps1` deterministik motor: JSON-lines log gruplama (değişken alan maskesi + `_headroom_count`), düz metin tekrar toplama, büyük JSON kırpma; `preserve_fields` **değeri taşıyan elemanları asla atmaz**; her şüpheli durumda **fail-open `raw_content`**. Ölçüm (`runtime/fixture-reports/headroom-pilot.json`): 103 KB log → 54 KB (%48), 59 KB integrity raporu → 28 KB (%53), 52 KB deepcheck → 11 KB (%78). Eşik 32 KiB (eski 1 MiB eşiği katmanı hiç devreye sokmuyordu). Kitap metni/sözleşme/bağlam paketi/kanıt politikayla `excluded`.

Bu iş sırasında bulunan üç **gerçek** hata: (1) dosya sonundaki boş satır JSON-lines gruplamayı tamamen devre dışı bırakıyordu, (2) `preserve_fields` denetimi `OrderedDictionary`'yi anahtarlar yerine .NET üyeleri üzerinden gezdiği için hem yanlış alarm hem sahte "geçti" üretiyordu, (3) kapı eşiği sabit kodluydu.

## 5. Regresyon (Gün 6)

| Test | Sonuç |
|---|---|
| `studio_task_e2e_test.ps1` (gerçek Ollama qwen2.5:3b, 2 koşu) | **PASS** — artifact + `observer snapshot: 2 kayıt` + `hafiza zinciri OK` + verifier `pass` + görev `completed` |
| `npm run test:typography` | PASS |
| `scripts/ci/memory_isolation_test.ps1` | PASS (selected=1, conflicts=2) |
| `scripts/ci/final_readiness_check.ps1` | PASS (skill-standard 13, skill-evals 3, agent-governance) |
| `scripts/ci/task_engine_runtime_test.ps1` | PASS |
| `scripts/ci/adapter_inventory_contract_test.ps1` | PASS — codebase-memory + observer + headroom `enabled with evidence`, omniroute `disabled (fail-closed)` |
| `scripts/ci/adapter_canary_report.ps1` | headroom `enabled_pilot_proven`, best 0.7799 |

Aktivasyon kuralı kalıcı hâle geldi: **"kanıtsız adaptör açılamaz"** — açık her adaptör için kanıt dosyası zorunlu.

## 6. Tek kalan iş: OmniRoute sağlayıcısı

Gateway sağlığı gerçekten çalışıyor (canary PASS, model kataloğu dönüyor). Gerçek completion çağrısı `401 Unauthorized` döndürüyor: yol doğru, eksik olan tek şey dashboard'dan bir sağlayıcı/anahtar tanımlamak. `scripts/ci/omniroute_propose_fixture.ps1` hazır — bağlantı kurulduğu anda tek komutla doğrulanıp `enabled: true` yapılabilir. OpenAI anahtarı Studio'ya kayıtlı ama hesapta kredi yok (`credit_balance_exhausted`).

## Yeniden doğrulama komutları

```powershell
powershell -File scripts/install_codebase_memory.ps1            # hash + zincir + sonda
powershell -File scripts/ci/codebase_memory_fixture_test.ps1    # gerçek indeksleme + arama
powershell -File scripts/ci/adapter_inventory_contract_test.ps1 # kanıtsız adaptör açılamaz
powershell -File scripts/ci/studio_task_e2e_test.ps1            # uçtan uca (Ollama gerekir)
```
