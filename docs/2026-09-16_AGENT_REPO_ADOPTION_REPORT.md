# KitHub Ajan Repo Adaptasyon Raporu

Tarih: 2026-09-16  
Kapsam: OmniRoute, claude-mem, Headroom, Observer/task observer, codebase-memory-mcp, Claude setup adayları.

## Kısa karar

KitHub’a bütün repoları kopyalamıyoruz. En yüksek değer sırası:

1. `DeusData/codebase-memory-mcp`: codebase keşfi ve etki analizi için MCP adaptörü.
2. `thedotmack/claude-mem`: genel sohbet hafızası olarak değil, KitHub’ın mevcut Context Pack/ledger sistemine seçici gözlem arşivi olarak uyarlanmalı.
3. `artzy/OmniRoute`: provider adapter’ının önüne opsiyonel gateway/router olarak bağlanmalı; KitHub’ın görev/verifier otoritesi olmamalı.
4. `headroomlabs-ai/headroom`: token/context sıkıştırma katmanı olarak pilotlanabilir; yaratıcı metinde kayıpsızlık kanıtlanmadan etkinleştirilmemeli.
5. `superbasedapp/observer`: süreç/token/maliyet gözlemi için güçlü aday; Windows üzerinde önce binary ve izin davranışı doğrulanmalı.
6. Claude setup repoları: sadece seçilmiş rules/hooks/skills fikirleri alınmalı; global Claude ayarı KitHub’a kopyalanmamalı.

## Repo değerlendirmeleri

### 1. OmniRoute — `artzy/OmniRoute`

Repo: https://github.com/artzy/OmniRoute  
MIT lisanslı; tek endpoint üzerinden çok sağlayıcı, fallback, quota ve çoklu routing stratejileri sunuyor. README; `auto`, coding/fast/cheap/offline/smart profilleri, 19 routing stratejisi, MCP/A2A ve token sıkıştırma katmanlarını listeliyor. Kaynak: [OmniRoute README](https://github.com/artzy/OmniRoute).

KitHub’a uyumu: provider seçim ve fallback problemimizi çözer. Mevcut `provider_phase.ps1` içindeki sağlayıcı çağrısını `localhost` OmniRoute endpoint’ine yönlendirmek mümkün.

Uyarlama sınırı: OmniRoute’a görev tamamlandı yetkisi verilmez. AgentRun, timeout, write-root, verifier ve insan onayı KitHub’da kalır. OmniRoute yalnızca `provider/model/fallback` taşıma katmanı olur. MCP/A2A yönetim yüzeyini doğrudan açmak riskli; yalnızca loopback ve dar token scope kullanılmalı.

Karar: **Uyarlayarak al — Faz 6 provider gateway pilotu.**

### 2. claude-mem — `thedotmack/claude-mem`

Repo: https://github.com/thedotmack/claude-mem  
Apache-2.0. Oturum gözlemlerini sıkıştırıp SQLite/FTS5 ve hibrit arama ile sonraki oturumlara getiriyor; worker, hook ve MCP yüzeyleri var. README, kurulumun sadece global npm kurulumu olmadığını; plugin/hook kurulumu için `npx claude-mem install` veya plugin komutlarının gerektiğini belirtiyor. Kaynak: [claude-mem README](https://github.com/thedotmack/claude-mem).

KitHub’a uyumu: Context Pack’in yerine geçmemeli. Kullanılacak model:

- Kalıcı hafıza: kullanıcı-genel değil, proje kimliği + kitap kimliği ile namespaced.
- Oturum sonunda yalnızca gözlem özeti, karar, hata ve kanıt kaydı alınır.
- Provider prompt’una tüm hafıza değil, Context Pack seçicisinin döndürdüğü küçük bölüm girer.
- FTS/vector sonuçlarının kaynağı ve hash’i AgentRun’a yazılır.

Risk: otomatik gözlem enjeksiyonu yaratıcı kitaplarda eski/yanlış bağlamı taşıyabilir; kişisel veriler ve kitaplar arası sızıntı riski var.

Karar: **Çekirdek kodu kopyalama; davranış modelini ve seçici arama sözleşmesini adapte et.**

### 3. Headroom — `headroomlabs-ai/headroom`

Repo/site: https://github.com/headroomlabs-ai/headroom  
Apache-2.0. Headroom wrapper/proxy/SDK/MCP yüzeyleriyle tool çıktısı ve tekrar eden bağlamı sıkıştırmayı hedefliyor. Güncel dokümana göre context yönetimi pipeline içinde otomatikleşmiş; `headroom.pipeline_extension` ile PRE_SEND normalizasyonu yapılabiliyor. Kaynak: [Headroom configuration](https://github.com/headroomlabs-ai/headroom/blob/main/docs/content/docs/configuration.mdx).

KitHub’a uyumu: en uygun yer provider prompt’undan önceki `contextPackText` katmanı ve büyük tool çıktıları. Ancak `book-request`, yaratıcı metin, sözleşme JSON’u ve verifier kanıtı kayıpsız tutulmalı. Sıkıştırma sadece tekrar eden log, liste ve keşif çıktılarında opt-in olmalı.

Karar: **Pilotla; yaratıcı içerikte varsayılan yapma.**

Not: `turangenesis/headroom` farklı bir projedir; token sıkıştırma değil, risk skoru ve insan-onay firewall’ıdır. Bu ikinci Headroom adayı KitHub’ın izin/approval katmanına daha yakındır, fakat mevcut KitHub guard’ı zaten görev durum ve write-root kontrolü yaptığı için doğrudan kopya gerektirmez. Kaynak: [turangenesis/headroom](https://github.com/turangenesis/headroom).

### 4. Task observer adayı — `superbasedapp/observer`

Repo: https://github.com/superbasedapp/observer  
Apache-2.0. Yerel Go binary; Claude Code, Codex, Cursor, Gemini CLI ve başka araçların oturumlarını, token/maliyet, dosya ve süreç etkinliğini gözlüyor. Proxy yolu gerçek provider token sayılarını yakalayabiliyor; watcher yolu JSONL geçmişini tarıyor; dashboard 5 saniyelik canlı görünüm sağlıyor. Kaynak: [Observer README](https://github.com/superbasedapp/observer).

KitHub’a uyumu: mevcut AgentRun/PID/heartbeat/log katmanına gözlemci olarak iyi oturur. Observer’ın kendi process supervisor’ını KitHub’ın görev otoritesi yerine koymamalıyız. En doğru adaptasyon:

- `task_id` ↔ observer session/run etiketi.
- AgentRun’a token/cost snapshot ekleme.
- Observer dashboard’ını ayrı bırakıp KitHub kartına yalnızca yerel özet/bağlantı verme.
- MCP kayıtlarını otomatik ve geniş yetkiyle yazmama; açık kurulum adımı.

Risk: proxy, MCP şema token maliyeti ve Windows binary güveni ayrıca test edilmeli.

Karar: **Gözlem/ölçüm katmanı olarak pilotla; görev otoritesi olarak alma.**

### 5. codebase-memory-mcp — `DeusData/codebase-memory-mcp`

Repo: https://github.com/DeusData/codebase-memory-mcp  
Native single binary, tree-sitter + seçili Hybrid LSP çözümleme, kalıcı SQLite bilgi grafiği ve 15 MCP aracı sunuyor. Arama, trace, architecture, impact analysis, dead-code ve graph sorguları var; Windows desteği ve API-key gerektirmeyen yerel çalışma dokümante edilmiş. Kaynak: [codebase-memory-mcp README](https://github.com/DeusData/codebase-memory-mcp).

KitHub’a uyumu: en doğrudan değer burada. `Phase 0` codebase audit, Context Pack source selection, `allowed_write_roots` incelemesi ve verifier öncesi etki analizi için kullanılabilir. MCP çıktısı doğrudan provider’a aktarılmamalı; KitHub seçici katmanı yalnızca ilgili sembol/çağrı/etki sonuçlarını hash’leyip Context Pack’e eklemeli.

Risk: repo issue’larında uzun süre çalışan MCP daemon’ında ciddi bellek sızıntısı raporu var; Windows’ta uzun süreli servis olarak değil, kontrollü CLI/sidecar ve kaynak limitiyle başlamalı. Kaynak: [memory leak issue](https://github.com/DeusData/codebase-memory-mcp/issues/581).

Karar: **İlk gerçek adaptasyon adayı.**

### 6. Claude setup adayları

`stuartshields/claude-setup`: MIT; global `~/.claude/` içine rules, hooks, agents, skills ve governance akışı koyuyor. Proje köküne kopyalanmaması gerektiğini açıkça söylüyor. Kaynak: [stuartshields/claude-setup](https://github.com/stuartshields/claude-setup).

`nuts-and-bolts-ai/claude-setup`: Claude Code için adım adım requirements → codebase research → plan → implement → validate → ship workflow’u ve `.claude` komut/agent/skill düzeni sunuyor. Kaynak: [nuts-and-bolts-ai/claude-setup](https://github.com/nuts-and-bolts-ai/claude-setup).

KitHub’a uyumu: kurulum betiğini veya global ayarları kopyalamak yerine şu fikirler alınmalı: fresh-session fazları, plan onayı, doğrulama kapısı, hook gözlemi ve governance checklist. KitHub’ın mevcut `runtime/agent-registry.json`, phase contracts, task queue ve readiness kontrolleri zaten bu modelin daha güvenli yerel karşılığı.

Karar: **Kod/ayar kopyalama yok; workflow desenlerini mevcut KitHub sözleşmelerine eşle.**

## Önerilen adaptasyon sırası

1. `codebase-memory-mcp`: yalnızca yerel read-only MCP sidecar; Context Pack’e seçici sonuç adapter’ı.
2. `observer`: AgentRun maliyet/token/process gözlem adapter’ı.
3. `OmniRoute`: loopback provider gateway; önce `propose` veya `polish` gibi düşük riskli faz.
4. `Headroom`: log/tool çıktısında opt-in sıkıştırma; yaratıcı metinde kapalı.
5. `claude-mem`: proje-namespaced karar/kanıt hafızası; önce SQLite/FTS5 davranışı, sonra gerekirse plugin.
6. Claude setup: yalnızca governance/skill fikirlerinin cherry-pick edilmesi.

## Adaptasyon mimarisi

`KitHub task queue → AgentRun → Context selector → (codebase-memory / claude-mem) → optional Headroom → OmniRoute/provider → write-root guard → independent verifier → human approval`

Bu sırada dış repoların hiçbiri KitHub’ın görev, dosya yazma, verifier veya yayınlama otoritesini devralmamalı.

## Sonuç

İlk adapte edilecek repo `codebase-memory-mcp`; ikinci `observer`; üçüncü `OmniRoute`. `claude-mem` değerli ama en yüksek veri-sızıntısı riskine sahip. Headroom yardımcı optimizasyon, Claude setup ise doğrudan runtime değil workflow referansı olarak kullanılmalı.
