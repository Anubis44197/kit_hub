# Uçtan Uca Senaryo, UI Overlap ve Adapter Durumu

Tarih: 2026-09-17

Bu rapor, öncelik sırası "uçtan uca gerçek senaryo → UI/preview → adapterler" şeklinde yürütülen çalışmanın sonucudur.

## 1. Uçtan uca gerçek senaryo — PASS

`scripts/ci/studio_task_e2e_test.ps1` eklendi ve koşuldu:

```
canlı bridge → proje işareti + runtime çekirdeği → save-book-request →
task-create → task-run → provider_phase (Ollama qwen2.5:3b, doğrudan API) →
dosya yazımı → run_task_provider → verify_agent_run (pass) → task completed
```

Sonuç: `_workspace/01_proposals.md` gerçek model içeriğiyle üretildi; bağımsız verifier `pass`, görev `completed`.

Test sırasında üretime alınan düzeltmeler:

- `scripts/run_task_provider.ps1`: provider artık ayrı alt süreçte çalışıyor. Eskiden `provider_phase.ps1`'in `exit 0`'ı tüm runner'ı bitiriyor, verifier hiç çalışmıyordu.
- `scripts/provider_phase.ps1`:
  - Faz kanıtı (`runtime/agent-compliance/<phase>.json`) runner tarafında yazılıyor (ajant write-root yetkisiyle çelişki giderildi; kanıt hash'li).
  - Prompt'a faz sözleşmesinden üretilen STRICT Output Policy (izinli/yasak desenler) gömüldü; read-only dosyalara yazım talimatı kaldırıldı.
  - Context pack prompt'a 1200 karakterlik önizleme olarak giriyor (dev JSON echo'ları ve kaçış bozulmaları azaldı).
  - Önce-doğrula-sonra-yaz; izinli desen dışı dosyalar "dropped" olarak kanıta geçer; önemsiz (<64 karakter) içerik yazılmaz; hiç somut çıktı yoksa görev düşer.
  - JSON hatasında düzeltici geri beslemeyle 1 tekrar; few-shot örnek + "gerçek içerik zorunlu" uyarısı.
- `scripts/verify_agent_run.ps1`: kanıt dosyalarının varlığı ve minimum içerik uzunluğu bağımsız denetleniyor.
- E2E fixture'ları ASCII-only (Windows PowerShell 5.1 kod sayfası güvenliği), bridge pipe deadlock'u asenkron boşaltma ile önlenmiş.

Not: 3B'lik küçük model düşük kaliteli içerik üretebilir; kapılar bunu yazmadan yakalar. Üretim kalitesi için daha büyük model (OpenRouter/OpenAI/Anthropic anahtarı) önerilir.

## 2. UI/preview overlap — GERÇEK, kök nedeni bulundu ve düzeltildi

Dar görünümde (≤780px) `.brand` gizlenince `.crumbs` grid'i ~120px workflow rail'iyle topbar ~177px'e yükseliyor; ama `index.html` mobil kuralı `.settings-panel { inset: 72px 12px auto }` sabiti kullanıyordu → panel açılınca üst ~105px topbar'ın altında kalıyordu (workspace modunda panel görünür olduğundan gerçek kullanıcı etkisi vardı).

Düzeltme:

- Panel konumu `--topbar-observed-height` CSS değişkenine bağlandı.
- Sayfa yüklenince topbar yüksekliğini ölçüp değişkene yazan ResizeObserver betiği eklendi (resize'da da günceller).
- Canlı doğrulama: `panelTop=178 ≥ topbarBottom=178`, `fullyBelowTopbar=true`, panel `visible`.
- `npm run test:typography` PASS. DOM'da duplicate hero yok (fullPage ekran görüntüsündeki çift görüntü capture dikiş artefaktıydı).

## 3. Adapterler

### OmniRoute — canary PASS, completion çağrısı açıldı, kalan adım auth

- `scripts/ci/omniroute_gateway_canary.ps1` PASS: `http://127.0.0.1:8787/v1/models` → 200, model kataloğu (`auto/best-coding` …) dönüyor.
- `scripts/ci/omniroute_propose_fixture.ps1` eklendi: gateway üzerinden GERÇEK `/v1/chat/completions` çağrısı yapar, files haritasını doğrular (yazmadan), raporu `runtime/fixture-reports/omniroute-propose-fixture.json`'a yazar.
- İlk gerçek çağrı yapıldı: **401 Unauthorized** — endpoint ve istek yolu doğru; kalan tek adım dashboard'dan API anahtarı tanımlamak (`INITIAL_PASSWORD` ile `http://127.0.0.1:20128`), sonra `OMNIROUTE_API_KEY` ile fixture'ı koşmak. Ayrıca Ollama upstream'i için `OMNIROUTE_ALLOW_LOCAL_PROVIDER_URLS=true` gerekebilir.
- Bu adımdan sonra `runtime/adapters/omniroute.json` `enabled=true` + `allowed_operations: ["health_check","propose_fixture"]` yapılabilir (fail-closed korunur).

### codebase-memory-mcp — DACL kök nedeni kesinleşti

- Binary çalışıyor (`0.11.0`, help OK). CLI ve stdio modları aynı noktada reddediyor:
  `C:\Users\90535` profil kökünde kalıtımsız bir Allow ACE, ikinci yerel hesaba (`S-1-5-21-…-3908196827`) Modify hakkı veriyor; binary bunu "untrusted identity" sayıp `cache-private` coordination dizini oluşturmayı reddediyor.
- `CBM_CACHE_DIR`, `HOME`, `XDG_CACHE_HOME`, `LOCALAPPDATA` override'ları denendi — binary gerçek profil yolunu Win32'den alıyor ve üst zincir DACL'ini denetliyor; override etkisiz.
- Kalıcı çözüm makine düzeyinde: `icacls C:\Users\90535 /remove:g *S-1-5-21-3623384205-1531654273-3415129787-3908196827` (kullanıcı onayı + yükseltilmiş izin gerekir; profil ACL'sine dokunur).
- `scripts/ci/codebase_memory_stdio_probe.ps1` eklendi: initialize + tools/list el sıkışması; engel kalkınca tek komutla doğrulayacak.

### Headroom — durum

Motor/SDK/binary kurulu değil; `runtime/adapters/headroom.json` pilot yapılandırması ve `scripts/headroom_policy_check.ps1` fallback politikasıyla duruyor. Somut motor kurulana kadar entegrasyon policy seviyesinde kalacak.

### Observer

`.tools/observer/observer.exe` mevcut; one-shot usage snapshot yolu (`scripts/run_observer_snapshot.ps1`) duruyor. Adapter `enabled=false` (canary onayı bekler).

## 4. Repo temizliği

- `.gitignore`'a eklendi: `.tools/`, `.freebuff/`, `runtime/agent-runs/`, `runtime/memory/` (357 MB'lık yerel araç kopyası ve run çıktıları takip dışına çıktı).
- `scripts/new_project.ps1` hariç tutma listesine `.tools`, `node_modules`, `_external`, `dist` eklendi — yeni proje kopyaları artık yüz MB'larca gereksiz dosya taşımaz.
- Commit hazırlığı: kod + adapter sözleşmeleri + CI betikleri + docs (durum/adoption raporları) tek mantıksal değişiklik kümesi; `_planlar/` ve `docs/…PROGRESS*.md` (23 dosya) ayrı değerlendirmeye — kalıcı dokümantasyon mu yoksa geçmiş çalışma notu mu kararı kullanıcıda.
