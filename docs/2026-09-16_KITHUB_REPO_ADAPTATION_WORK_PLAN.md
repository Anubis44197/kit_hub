# KitHub Repo Adaptation — Güncel Uygulama Planı

Tarih: **16 Eylül 2026**
Son güncelleme: **17 Eylül 2026**
Proje: **KitHub Studio**
Durum: **Kısmen uygulandı; dış motor gerektiren adapter canary işleri kapalı**

Amaç: codebase-memory-mcp, Observer, OmniRoute, Headroom ve namespaced memory fikirlerini KitHub’ın mevcut görev kuyruğu, AgentRun, Context Pack, izin kökleri ve bağımsız verifier mimarisine kontrollü biçimde adapte etmek.

## Kesin sınırlar

- [x] Dış repo hiçbir zaman KitHub’ın görev, izin, verifier, onay veya yayınlama otoritesini devralmayacak. Kanıt: `runtime/adapters/*.json`.
- [x] Varsayılan çalışma biçimi local-first, loopback ve anahtarsız test olacak. Kanıt: `runtime/adapters/omniroute.json`.
- [x] Çalışmayan adapter otomatik etkinleştirilmeyecek; fallback korunacak. Kanıt: `scripts/ci/adapter_canary_report.ps1`.
- [x] API anahtarları rapor, log, fixture veya commit içine yazılmayacak. Kanıt: `runtime/memory/schema.json`.
- [x] Provider/adapter hatası sahte `completed` üretmeyecek; `blocked`, `revision_required` veya fail-open/fail-closed ayrımı korunacak. Kanıt: `scripts/task_supervisor.ps1`, `scripts/verify_agent_run.ps1`.

## Faz 0 — Baseline ve güvenlik

- [x] Mevcut KitHub runtime ve dirty çalışma ağacı raporlandı. Kanıt: `docs/adapters/2026-09-16_PHASE0_BASELINE.md`.
- [x] Readiness, task runtime ve verifier testleri baseline olarak çalıştırıldı. Kanıt: `docs/2026-09-16_AGENT_RUNTIME_REPAIR_FINAL_STATUS.md`.
- [x] Dış repo adayları commit/lisans/platform/risk notlarıyla değerlendirildi. Kanıt: `docs/2026-09-16_AGENT_REPO_ADOPTION_REPORT.md`.
- [x] Adapter sözleşmeleri `runtime/adapters/` altında sınırlandı. Kanıt: `runtime/adapters/codebase-memory-mcp.json`, `runtime/adapters/observer.json`, `runtime/adapters/omniroute.json`, `runtime/adapters/headroom.json`.
- [x] `enabled`, `mode`, `transport`, timeout/fallback ve denied operation sözleşmeleri tanımlandı. Kanıt: `runtime/adapters/*.json`.

Başarı durumu: **Geçti.** Dış repo etkin değilken KitHub çalışmaya devam ediyor.

## Faz 1 — codebase-memory-mcp read-only adapter

- [x] Windows binary/release sürümü ve checksum raporlanabilir hale getirildi. Kanıt: `scripts/adapter_inventory_check.ps1`.
- [x] MCP bağlantısı read-only ve `stdio` kapsamına alındı. Kanıt: `runtime/adapters/codebase-memory-mcp.json`.
- [x] `index_repository`, `search_graph`, `trace_path`, `impact_analysis` için KitHub adapter sözleşmesi yazıldı. Kanıt: `runtime/adapters/codebase-memory-mcp.json`.
- [x] Context Pack fallback korundu. Kanıt: `runtime/adapters/codebase-memory-mcp.json`.
- [!] Gerçek fixture indexing aktif değil: Windows DACL güvenlik kontrolü çözülmedi. Kanıt: `docs/2026-09-16_AGENT_RUNTIME_REPAIR_PROGRESS8.md`.

Başarı durumu: **Sözleşme hazır, gerçek indexing kapalı.**

## Faz 2 — Observer AgentRun gözlem adapter’ı

- [x] Observer v1.33.0 Windows binary kurulumu ve checksum raporlanabilir hale getirildi. Kanıt: `scripts/adapter_inventory_check.ps1`.
- [x] One-shot snapshot wrapper eklendi; proxy varsayılan açılmıyor. Kanıt: `scripts/run_observer_snapshot.ps1`.
- [x] Snapshot hedefi `runtime/agent-runs/<runId>/observer.jsonl` olarak bağlandı. Kanıt: `scripts/run_observer_snapshot.ps1`.
- [x] Observer ana task statüsünü değiştiremiyor; salt gözlem olarak kalıyor. Kanıt: `runtime/adapters/observer.json`.
- [x] Observer yok/timeout olursa AgentRun yaşam döngüsünü bozmayacak fail-open davranışı doğrulandı. Kanıt: `scripts/ci/observer_adapter_test.ps1`.

Başarı durumu: **Çalışıyor; gözlem amaçlı ve güvenli kapalı/proxy’siz.**

## Faz 3 — OmniRoute provider gateway

- [x] Loopback-only/fail-closed sözleşme eklendi. Kanıt: `runtime/adapters/omniroute.json`.
- [x] Health check scripti gateway kapalıyken `disabled`/`unavailable` durumunu raporluyor. Kanıt: `scripts/omniroute_health_check.ps1`.
- [x] Remote mode, proxy bypass, account pooling, MCP/A2A admin kapsam dışı bırakıldı. Kanıt: `runtime/adapters/omniroute.json`.
- [x] Uzak provider çağrısı yapılmadan kapalı bırakıldı. Kanıt: `docs/2026-09-17_AGENT_RUNTIME_REPAIR_PROGRESS24.md`.
- [!] Gateway başlangıcı tamamlanmadı: `.build/next` production marker eksik; OAuth provider’ları yapılandırılmamış. Kanıt: `docs/2026-09-17_AGENT_RUNTIME_REPAIR_PROGRESS24.md`.
- [!] İzole build `BUILD_ID` üretti fakat start hâlâ kapalı: `.source/source.config.mjs` yazma izni reddedildi ve `prerender-manifest.json` eksik kaldı. Kanıt: `docs/2026-09-17_AGENT_RUNTIME_REPAIR_PROGRESS25.md`, `runtime/fixture-reports/omniroute-start.stderr.log`.
- [x] Workspace kopyasında backend-only build ve geçici local gateway canary geçti; `/v1/models` 200 döndü. Kanıt: `docs/2026-09-17_AGENT_RUNTIME_REPAIR_PROGRESS26.md`, `scripts/ci/omniroute_gateway_canary.ps1`.

Başarı durumu: **Güvenli fail-closed korunuyor; local gateway health canary çalışıyor.**

## Faz 4 — Headroom kontrollü sıkıştırma pilotu

- [x] Sıkıştırılabilir içerik sınırları tanımlandı: tool output, tekrar eden log, büyük JSON. Kanıt: `runtime/adapters/headroom.json`.
- [x] Kanıt/yaratıcı metin/manuscript/export verileri sıkıştırma dışı bırakıldı. Kanıt: `runtime/adapters/headroom.json`.
- [x] Policy check fallback davranışı rapora dahil edildi. Kanıt: `scripts/headroom_policy_check.ps1`.
- [!] Gerçek Headroom SDK/motor karşılaştırması yok; paket doğrulanmadan etkinleştirilmeyecek. Kanıt: `docs/2026-09-16_AGENT_RUNTIME_REPAIR_PROGRESS21.md`.

Başarı durumu: **Policy/fallback hazır; gerçek motor kapalı.**

## Faz 5 — Namespaced memory

- [x] KitHub local SQLite/FTS5 namespaced memory şeması tasarlandı. Kanıt: `runtime/memory/schema.json`.
- [x] Kayıt türleri `decision`, `error`, `artifact`, `verification`, `user_preference` ile sınırlandı. Kanıt: `runtime/memory/schema.json`.
- [x] Project/book/run/phase/source hash zorunlu hale getirildi. Kanıt: `runtime/memory/schema.json`.
- [x] `raw_prompt`, `api_key`, `credential`, `personal_data` alanları reddediliyor. Kanıt: `scripts/validate_memory_record.ps1`.
- [x] Kitaplar arası memory isolation selector ve testi eklendi. Kanıt: `scripts/select_memory_records.ps1`, `scripts/ci/memory_isolation_test.ps1`.

Başarı durumu: **Şema, hassas alan koruması ve isolation testi hazır.**

## Faz 6 — Planner → Executor → Verifier sözleşmesi

- [x] Write-root guard eklendi. Kanıt: `scripts/assert_agent_write_root.ps1`.
- [x] Bağımsız verifier eklendi. Kanıt: `scripts/verify_agent_run.ps1`.
- [x] `pass`, `revision_required`, `blocked` ayrımı tutuluyor. Kanıt: `scripts/task_engine.ps1`, `scripts/task_supervisor.ps1`.
- [x] Verifier/test akışı regression ile doğrulandı. Kanıt: `scripts/ci/task_engine_runtime_test.ps1`.

Başarı durumu: **Çalışıyor.**

## Faz 7 — Studio UX ve operasyon

- [x] Bridge health endpoint çalışıyor. Kanıt: `scripts/studio_bridge.ps1`.
- [x] Adapter inventory endpoint eklendi. Kanıt: `scripts/studio_bridge.ps1`.
- [x] Adapter health/version/checksum görünümü için JSON kaynak hazır. Kanıt: `scripts/adapter_inventory_check.ps1`.
- [x] Browser içinde ana ekran QA yapıldı; sayfa açılıyor, konsol hata vermiyor, yatay taşma yok. Kanıt: `docs/2026-09-17_AGENT_RUNTIME_REPAIR_PROGRESS25.md`.
- [ ] Editör içi kartlar için proje açma/oluşturma akışıyla ikinci görsel QA yapılmalı.
- [ ] Clickable local artifact endpoint’leri ayrı UX işi olarak ele alınmalı.

Başarı durumu: **Backend/endpoint hazır; görsel QA sırada.**

## Faz 8 — Değerlendirme ve rollout

- [x] Ortak adapter canary raporu eklendi. Kanıt: `scripts/ci/adapter_canary_report.ps1`.
- [x] Başarısız adapter tek ayarla kapalı kalıyor; fallback korunuyor. Kanıt: `runtime/adapters/*.json`.
- [x] Otomatik rollout yapılmıyor. Kanıt: `scripts/ci/adapter_canary_report.ps1`.
- [ ] Aynı fixture ile baseline/codebase-memory/Observer/OmniRoute üç tekrar karşılaştırması dış adapter’lar açılmadan yapılamaz.
- [ ] `create` manuscript ve `export` rollout için ikinci insan onayı korunmalı.

Başarı durumu: **Canary raporu çalışıyor; gerçek rollout kapalı.**

## Sıradaki uygulanabilir işler

1. [x] Plan dosyasını gerçek duruma göre güncelle.
2. [x] Adapter inventory’ye tüm adapter’ları dahil et.
3. [x] Memory isolation testini ekle.
4. [x] Studio browser ana ekran görsel QA yap.
5. [x] OmniRoute için gateway build/start sorununu local canary düzeyinde çöz.
6. [ ] codebase-memory için Windows DACL engelini ayrı, yönetici/onay gerektiren iş olarak çöz.
7. [ ] Headroom gerçek SDK/motor doğrulamasını paket kimliği netleşince yap.

## Çalışma kaydı kuralları

- Tamamlanan madde `[x]`, bilinçli kapalı/blocked madde `[!]`, bekleyen madde `[ ]` kalacak.
- Her kritik madde yanında kanıt dosyası yazılacak.
- API anahtarı, kişisel veri veya ham provider prompt’u bu dosyaya yazılmayacak.
- Kod değişiklikleri mevcut kullanıcı dirty değişikliklerini ezmeden uygulanacak.
