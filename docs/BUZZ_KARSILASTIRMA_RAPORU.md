# Buzz × KitHub Derin Karşılaştırma ve Ajan Sistemi Analizi Raporu

**Tarih:** 2026-08-25
**Kapsam:** block/buzz (commit 822c5ab, 2026-08-25) ↔ kit_hub (v1.3.0, 36 ajan, 8 faz)
**Yöntem:** Kaynak kodu okuma, mimari doküman analizi, runtime/contract/registry incelemesi
**Yanıtlanan soru:** Buzz ajan sistemi nedir? KitHub için işe yarar mı? Nerede, nasıl, hangi maliyetle?

---

## 1. Yönetici Özeti

**Buzz** (block/buzz), Block Inc. tarafından geliştirilen, Nostr protokolü üzerine inşa edilmiş, **kendinden barındırılabilir (self-hosted) bir ekip çalışma alanıdır**. İnsanlar ve AI ajanları aynı kanallarda konuşur, işbirliği yapar. Her ajanın kendi kriptografik kimliği vardır. Her mesaj, reaksiyon, workflow adımı, onay — imzalı bir Nostr eventidir. Ajan runtimeı **ACP (Agent Client Protocol)** ve **MCP (Model Context Protocol)** standartlarına dayanır.

**KitHub** (kit_hub), Türkçe roman/kitap üretimi için **sözleşme-bağlı çok ajanlı (contract-bound multi-agent) bir yazım hattıdır**. 36 ajan rolü, 8 faz, yetki ve doğrulama katmanı, TDK/ISBN/Word export desteği ile endüstriyel kitap üretimini hedefler. Ajanlar bir PowerShell runner tarafından yönetilir; ya IDE ajanı (Claude/Codex) ya da API modu (tek seferlik büyük prompt → JSON dosyaları) ile çalışır.

**Temel bulgu:** İki sistem **aynı kategoride değildir** — tamamlayıcıdır.

| Boyut | Buzz | KitHub |
|-------|------|--------|
| Ne işe yarar? | Ekip iletişimi + ajan işbirliği ortamı | Türkçe kitap üretim hattı |
| Ajan modeli | Gerçek çok ajanlı runtime (eşzamanlı, event-driven) | Rol taklidi (tek model, sıralı, dosya tabanlı) |
| Yürütme | Gerçek ajan süreçleri (buzz-agent + ACP + MCP) | IDE ajanı veya tek API çağrısı |
| Doğrulama | Genel (workflow approval gates) | Derin (TDK, uzunluk, kontinüite, yayıncılık) |
| Operasyonel yük | Yüksek (Rust, Postgres, Redis, relay) | Düşük (PowerShell, dosyalar, tarayıcı) |
| Kullanıcı | Ekip (çok kişi + ajan) | Tek yazar / yazar-editör |

**Nihai öneri:** Buzz, kit_hubun yerine geçmez; **canlı çalışma ortamı, çok ajanlı eşzamanlılık ve işbirliği katmanını** sağlayabilir. En gerçekçi entegrasyon: kit_hubu buzz üzerinde çalışan bir "kitap yazım ekibi" olarak konumlandırmak. Ancak tek kullanıcılı offline üretim için buzzun ek yükü çoğunlukla gereksizdir.

---

## 2. Buzz Ajan Sistemi — Derinlemesine

### 2.1 Platform Mimarisi (Nostr Relay + Event Log)

Buzz, Nostr protokolü (NIP-01) üzerine inşa edilmiştir:

- **Relay** merkezidir. Tüm okuma/yazma WebSocket üzerinden relaye gider.
- Her aksiyon imzalı bir JSON eventidir: {id, pubkey, kind, tags, content, sig}
- 127den fazla event kindı tanımlıdır (buzz-core/src/kind.rs). Yeni özellik = yeni kind numarası.
- **Veritabanı:** Postgres (events, channels, tokens, workflows, audit) + Redis (presence, typing, fan-out)
- **Topluluk (community):** URL bazlı; her relay bir topluluk barındırır.

    CLIENTS: İnsan (desktop/web/mobile) ve Ajan (buzz-cli, Tauri, Flutter)
        │ WebSocket (NIP-01)
        ▼
    buzz-relay (Axum): EVENT pipeline, REQ handler, SubscriptionRegistry, HTTP bridge
        /events, /query, /count, /media, /git/*, /hooks/{id}
        │              │
        ▼              ▼
    Postgres        Redis
    (events,        (presence,
     channels,       typing,
     workflows,      fan-out)
     audit)

### 2.2 Ajan Sistemi Katmanları

Buzzın ajan sistemi **üç ana binary + iki protokol** ile çalışır:

    Herhangi bir ACP istemcisi (Zed, JetBrains, buzz-acp, özel)
        │
        │ stdio ACP (JSON-RPC 2.0)
        ▼
    buzz-agent / goose / codex-acp / claude-agent-acp
        │
        │ stdio MCP (JSON-RPC 2.0)
        ▼
    buzz-dev-mcp (shell, str_replace, file_edit, todo)
        │
        ▼
    rg, tree, git, npm, powershell, ...

#### 2.2.1 buzz-acp — ACP Harness (Ana Bağlantı Noktası)

**Dosya:** crates/buzz-acp/
**Dil:** Rust
**Ne işe yarar:** Buzz relaydeki @mentionları dinler, bir ACP ajanı (goose, codex, claude-code) başlatır, gelen mesajları ajan promptu olarak gönderir, ajanın tool calllarını relaye yayınlar.

    Buzz Relay ──WS──→ buzz-acp ──stdio ACP──→ Ajan (goose/codex/claude)
                                                 │
                                            Buzz CLI (send_message, ...)

**Önemli özellikler:**
- **1-32 paralel ajan subprocess** (--agents), aynı bot kimliğini paylaşır, per-channel in-flight kilidi
- **Kuyruk mekanizması** (queue.rs): kanal başına en fazla 500 olay, 50li batchler, 10 retry, 5-300sn backoff, dead-letter. Dedup modları: Drop (varsayılan) veya Queue
- **Heartbeat**: rölantide proof-of-life sorgusu (--heartbeat-interval)
- **Sahip kontrollü çalıştırma komutları**: !shutdown, !cancel, !rotate
- **Yanıt filtresi** (--respond-to): owner-only, allowlist, anyone, nobody
- **ACP yaşam döngüsü**: spawn → initialize → session/new → session/prompt → session/cancel
- **Idle timeout** (varsayılan 620sn) + **hard timeout** (7200sn)
- **Forum kanalları** desteği (45001-45003 kindları)

#### 2.2.2 buzz-agent — Minimal ACP Uyumlu Ajan

**Dosya:** crates/buzz-agent/
**Dil:** Rust (zero unsafe, zero panics)
**Standart:** ACP v1, JSON-RPC 2.0 over stdio

**Desteklenen LLM sağlayıcıları:**
- Anthropic (Claude)
- OpenAI / OpenAI-uyumlu (vLLM, llama.cpp, Ollama)
- OpenRouter
- Databricks (OAuth 2.0 PKCE)

**Döngü:** session/prompt al → LLM çağır → tool callları MCP üzerinden çalıştır → sonuçları LLMe geri besle → tool bitene kadar tekrarla → end_turn

**Bağlam yönetimi:**
- maybe_handoff() (handoff.rs): context dolunca özet çıkar → kendine devret (max_handoffs=10, varsayılan 200K token eşiği)
- reply_guard: mesaj göndermeyi unutan ajanı ikaz eder (mesh ajanları için varsayılan açık)

**Yapılandırma:** Tamamen ortam değişkenleri (config dosyası yok, flag yok). BUZZ_AGENT_PROVIDER, BUZZ_AGENT_SYSTEM_PROMPT, BUZZ_AGENT_MAX_ROUNDS, BUZZ_AGENT_MAX_PARALLEL_TOOLS (8), BUZZ_AGENT_TOOL_TIMEOUT_SECS (660), BUZZ_AGENT_MAX_HISTORY_BYTES (1MB), BUZZ_AGENT_MAX_TOOL_RESULT_TEXT_BYTES (50KB, ortası elided)

#### 2.2.3 buzz-dev-mcp — Developer MCP Sunucusu

**Dosya:** crates/buzz-dev-mcp/
**Ne işe yarar:** Herhangi bir MCP istemcisine shell + dosya düzenleme + todo araçları sağlar.
**Güvenlik:** Process-group kill, bounded output, geçici süreçler, working directory kısıtlaması.

#### 2.2.4 buzz-cli — Ajan Odaklı CLI

**Dosya:** crates/buzz-cli/
**Ne işe yarar:** Ajanların Buzz relay ile etkileşimi için JSON-in/JSON-out CLI.
**Alt komutlar:** agents, channels, messages, workflows, patches, repos, pr, issues, upload, users, social, pack, moderation, feed, mem, notes, emoji, dms, channel_templates, reactions

#### 2.2.5 buzz-workflow — YAML Otomasyon Motoru

**Dosya:** crates/buzz-workflow/
**Ne işe yarar:** Kanal-scopelu YAML workflowları. Sequential execution, evalexpr conditionları, approval gates.

**Tetikleyiciler (TriggerDef):**
- message_posted — opsiyonel evalexpr filter
- reaction_added — opsiyonel emoji filter
- diff_posted — kind:40008 diff eventi
- schedule — cron veya interval ("1h", "30m")
- webhook — HTTP POST /hooks/{id}

**Aksiyonlar (ActionDef):**
- send_message (reply_in_thread dahil)
- send_dm
- set_channel_topic
- add_reaction
- call_webhook (exfiltration riski — elevated authority gerekir: SEC-006)
- request_approval (from, message, timeout)
- delay

**Güvenlik:** check_owner_authority — sahibin kanal üyeliği ve rolü yeniden doğrulanır. call_webhook içeren tanımlar owner/admin rolü gerektirir.

#### 2.2.6 buzz-persona — Persona Paketleri

**Dosya:** crates/buzz-persona/
**Standart:** Open Plugin Spec (OPS) süperseti
**Yapı:** .plugin/plugin.json + agents/*.persona.md + skills/ + .mcp.json + hooks/

Her personanın:
- Kimlik (name, description)
- Sistem promptu
- Model, temperature, max_context_tokens
- Triggerlar (mentions, keywords, all_messages)
- Subscribe listesi
- MCP araç yapılandırması
- Yaşam döngüsü hookları

**Varsayılanlar:** defaults object pack-wide değerleri belirler; her persona override edebilir. Örn: paket varsayılanı Sonnet, pip Opus kullanır.

#### 2.2.7 sprig — Multicall Birleşik Binary

**Dosya:** crates/sprig/
**Ne işe yarar:** buzz-acp, buzz-agent, buzz-dev-mcpnin tek bir binaryde toplanmış hali. Symlink ile hangi rolü oynayacağı seçilir: ln -s sprig buzz-acp

### 2.3 Kimlik ve Güvenlik Modeli

- Her ajanın kendi **Nostr keypairi** (nsec/npub) vardır — bu onun Buzzdaki kimliğidir.
- buzz-admin generate-key → ajan anahtarı üretilir, buzz-admin add-member ile relay üyesi yapılır.
- **NIP-42** (WebSocket challenge-response auth) + **NIP-98** (HTTP imza doğrulaması)
- **Scoped identities:** Kanal üyelikleri, joblar, DMler, profil, denetim — toplulukla sınırlı.
- **Audit log:** buzz-audit hash-chain kurcalanmaya dayanıklı denetim.

### 2.4 Ajan Yaşam Döngüsü

    1. Kullanıcı @agent yazıp mesaj gönderir
    2. buzz-acp relaydeki mentionı alır, queueya koyar
    3. Uygun ajan subprocessine ACP session/prompt gönderir
    4. Ajan: LLM çağır → tool call → MCP çalıştır → sonuçları LLMe ver → döngü
    5. Ajan messages send ile yanıtı relaye yayınlar
    6. Yanıt kanalda görünür, threadde devam edebilir
    7. context dolduğunda: handoff (özetle → kendine devret)
    8. İptal: session/cancel → process-group kill
    9. Timeout: idle timeout (620sn) veya hard timeout (7200sn)

### 2.5 Remote Agents (Mesh)

**Dosya:** docs/remote-agents.md
**Ne işe yarar:** Buzz Desktopun ajanları uzak bir Kubernetes/Pod ortamında çalıştırması.
**Mimari:** Desktop → Provider binary (buzz-backend-kubernetes) → Substrate (K8s Pod) → sprig imajı çalışır
**Tasarım kısıtı:** Desktop ile uzak ajan arasında kalıcı bir yönetim kanalı YOKTUR.
**Durum sinyali:** Relay presence (kind:20001).
**Durdurma:** Relay mesajı (!shutdown).
**Güvenlik:** Provider binarysi ajanın nsecini alır — bu güven sınırıdır.
---

## 3. KitHub Ajan/Pipeline Mimarisi — Derinlemesine

### 3.1 Felsefe: Contract-Bound Orchestration

KitHub, **"ajan promptları güvenilir değildir; doğrulama katmanı güvenilirdir"** felsefesiyle inşa edilmiştir. Her faz:

- runtime/agent-registry.json — 36 ajanın tanımı (allowed_phases, write roots, timeout, max_turns)
- runtime/agent-status-contract.json — geçerli durumlar: completed, failed, blocked, timed_out, invalid_output
- runtime/phase-contracts/{phase}.json — her faz için gerekli ajanlar, referanslar, state dosyaları, izinler, reddedilen desenler
- runtime/agent-compliance/{phase}.json — faz sonunda yazılan uygunluk manifestosu (artifact_hashes, contract_hashes, agent_statuses içerir)
- runtime/runs/{run_id}/run-journal.jsonl — olay günlüğü (phase.started, phase.completed, phase.failed, run.completed)

**İlham kaynağı:** bytedance/deer-flow (subagent registry, status contract, guardrail, run journal)

### 3.2 36 Ajan, 8 Faz

    Faz:          Ajanda görev yapan ajanlar:
    intake        brief-interviewer, book-dna-locker, layout-profile-planner
    propose       proposal-generator
    design-big    concept-builder, character-architect, plot-hook-engineer,
                  book-structure-optimizer, domain-researcher, research-citation-auditor
    design-small  plot-hook-engineer, domain-researcher, episode-architect,
                  continuity-bridge, character-sculptor
    create        chief-editor-orchestrator, episode-architect, continuity-bridge,
                  episode-creator, quality-verifier, tdk-polisher, tdk-layout-agent
    polish        chief-editor-orchestrator, developmental-editor, continuity-editor,
                  line-editor, copy-editor, revision-reviewer, revision-executor,
                  story-analyst, rule-checker, tdk-polisher, tdk-layout-agent,
                  book-structure-optimizer, alive-enhancer, final-proofreader
    rewrite       revision-analyst, revision-executor, episode-rewriter,
                  quality-verifier, chief-editor-orchestrator, character-sculptor,
                  alive-enhancer, story-analyst, rule-checker, tdk-polisher,
                  tdk-layout-agent
    export        chief-editor-orchestrator, export-approval-gate, export-validator,
                  front-matter-editor, cover-designer, publication-compliance-checker,
                  final-proofreader, book-exporter, research-citation-auditor,
                  rule-checker, tdk-layout-agent

Her ajanın:
- allowed_write_roots: hangi dizinlere yazabilir? (Örn: episode, revision/_workspace, runtime/agent-compliance)
- required_references: hangi referans belgelerini okumalı?
- timeout_seconds, max_turns: kaynak sınırları
- agent_statuses: faz contractındaki required_agentslerin tamamı completed olmalı

### 3.3 Yürütme Modları

#### 3.3.1 IDE Modu

**Script:** scripts/ide_phase_prompt.ps1
**Nasıl çalışır:** Terminale faz görevlerini basar (required output dosyaları listesi). IDE ajanı (Claude Code, Codex) bu çıktıyı okur, dosyaları yazar. KitHub runnerı (run_pipeline.ps1) yazılan dosyaları doğrular, compliance manifestini kontrol eder.

**execution_claim_mode:** simulated — ajanın çalıştığına dair kanıt yok, sadece dosyaların varlığı doğrulanır.

#### 3.3.2 API Modu (Provider Mode)

**Script:** scripts/provider_phase.ps1 (8KB)
**Nasıl çalışır:**
1. Faz için büyük bir prompt oluşturur (tüm state dosyalarını, contractları, referansları içerir)
2. API çağrısı yapar: OpenAI, Anthropic, Gemini veya OpenRouter
3. Yanıtın {files: [{path, content}]} JSON olmasını bekler
4. Her dosyayı proje içine yazar (Assert-InProjectRoot güvenlik kontrolü)
5. Runner fazı doğrular

**execution_claim_mode:** executed — API çağrısı kanıtı vardır.
**Kısıtlama:** Tek seferlik dev bir prompt — gerçek çok ajanlı eşzamanlılık yoktur. "36 ajan" sırayla tek model bağlamında taklit edilir.

#### 3.3.3 Komut Modu

**Konfigürasyon:** runtime/runner-config.json içinde phase_commands
**Her faz için:** İsteğe bağlı özel komut (örneğin bir Docker containerı çağırmak).
**Şu an:** Varsayılan olarak tüm faz komutları boş (""). Kullanılmıyor.

### 3.4 Studio Web Arayüzü

**Dosyalar:** index.html + src/studio-editor.js, src/studio-wizard.js, src/studio-professional.js, src/page-flow.js
**Arka uç:** scripts/studio_bridge.ps1 (165KB) — 127.0.0.1:8765te TCP listener, HTTP benzeri API

**API uç noktaları:**
- /api/run-pipeline — faz zincirini başlatır
- /api/provider-settings — API anahtarı yönetimi (DPAPI şifreli)
- /api/live-edit — canlı düzenleme önerileri
- /api/new-project, /api/project-summary
- /api/professional-state/read|save — karakter, mekan, olay örgüsü yönetimi
- /api/cover-asset/generate|upload|read
- /api/version-history — sürüm geçmişi
- /api/import-docx — Word belgesi içe aktarma

### 3.5 Kritik Mimari Gözlem: "Çok Ajanlı" Aslında "Rol Taklidi"

KitHubın "36 ajanı" gerçek ajan süreçleri değil, **belge-tabanlı roller**dir:

- **IDE modunda:** Bir IDE ajanı (tek bağlam) tüm rolleri sırayla taklit eder, her biri için ayrı ayrı dosya yazar.
- **API modunda:** Tek bir API çağrısı tüm rolleri içeren prompt alır, tek seferde tüm dosyaları döndürür.
- agent_sequence kavramı sadece prompt metninde geçer (provider_phase.ps1: "Follow agent_sequence exactly"), JSON contractlarda tanımlı değildir. Gerçek sıralama handoff-contract.md ve ajan markdown dosyalarında gömülüdür.
- **Eşzamanlı çalışma yoktur.** Hiçbir noktada iki ajan aynı anda farklı bölüm yazmaz.

Bu bir **tasarım tercihidir** — kontinüite riskini azaltır, validasyonu basitleştirir. Gerçekte KitHub **tek yürütücülü, çok rollü bir roman yazma hattıdır**.

### 3.6 Kalite Kapıları

KitHubın en güçlü yanı doğrulama katmanıdır (run_pipeline.ps1, 124KB):

| Kapı | Ne kontrol eder? |
|------|------------------|
| Phase contracts | required_agents, allowed_output_patterns, denied_output_patterns |
| Agent compliance | agent_statuses, artifact_hashes, contract_hashes, phase_authority |
| User approvals | runtime/approvals/{phase}.json — approved=true/false |
| TDK dictionary | tdk_dict_check.ps1 — Türk Dil Kurumu sözlük kontrolü |
| Text quality gates | max_duplicate_line_ratio, min_psychological_markers, forbid_mixed_dialogue_styles, tell_sensory_ratio_max, require_turkish_diacritics |
| Cross-chapter gates | max_chapter_similarity, min_event_markers_per_chapter, max_opening_prefix_repeat |
| Length gates | min_chapter_word_completion_ratio (0.65), min_total_word_completion_ratio (0.9) |
| Forbidden patterns | TL;DR, Özet:, TODO, lorem ipsum, ... |
| Artifact size budget | max 1.5MB per artifact |
| Negative enforcement | Forbidden content patterns in episode outputs |
| Retention | max 20 run directory |

---

## 4. Karşılaştırma Tablosu

| Özellik | Buzz | KitHub | Uyum / Fark |
|---------|------|--------|-------------|
| **Ajan tanımı** | Persona pack (OPS, frontmatter, skills, MCP, hooks) | agent-registry.json + markdown prompt + phase contract | **Yüksek uyum.** kit_hub ajanları → buzz persona formatına taşınabilir. skills/ zaten SKILL.md kullanıyor. |
| **Ajan yürütme** | Gerçek ajan süreçleri (1-32 eşzamanlı, ACP/MCP) | Tek model taklidi (IDE ajanı veya API çağrısı) | **Temel fark.** Buzz gerçek çok ajanlı; kit_hub tek yürütücülü. |
| **Orkestrasyon** | Event-driven (mention/message/reaction/webhook/schedule) | Sıralı faz pipeline + onay kapıları | **Tamamlayıcı.** Buzz olayları kit_hub fazlarını tetikleyebilir. |
| **İletişim** | Kanallar, threadler, DMs, @mention, reaksiyonlar | Yok (dosya tabanlı) | **Eksik.** Buzzın en büyük farkı. |
| **Denetim** | İmzalı Nostr eventleri + hash-chain audit | run-journal.jsonl + SHA-256 manifest | **Kavramsal eşleşme var.** Buzz imza ekler. |
| **Kimlik** | Kriptografik (nsec/npub), her ajanın kendi anahtarı, NIP-42/NIP-98 | Üçüncü taraf API anahtarı (DPAPI şifreli) | **Farklı seviye.** Buzz daha olgun, kit_hubun ihtiyacı değil. |
| **Workflow/Automation** | YAML (5 trigger türü, 7 aksiyon, approval gates, evalexpr) | Pipeline (8 faz, shell script, approval JSON) | **Yüksek uyum.** Buzz workflow = kit_hub faz kapılarına analog. |
| **Araç/Plugin** | MCP (herhangi bir MCP sunucusu ile çalışır) | PowerShell scriptleri + esbuild bundle | **Farklı ekosistem.** MCP daha taşınabilir. |
| **Bağlam yönetimi** | Handoff/özetleme (max 10 handoff, 200K token) | State dosyaları (revision/_state/*.json) + handoff-contract.md | **Farklı yaklaşım, aynı sorun.** kit_hubun state dosyaları daha güvenilir (deterministik). |
| **Kalite doğrulama** | Genel (workflow approval gates) | **Çok derin:** TDK, uzunluk, kontinüite, yayıncılık, ... | **Fark.** kit_hubun en güçlü yanı, buzzda yok. |
| **Dil/Platform** | Rust (cargo, Postgres, Redis, Tauri, Flutter) | PowerShell + vanilla JS + ProseMirror | **Farklı yığın.** Buzz ağır, kit_hub hafif. |
| **Kurulum** | Rust toolchain, Postgres, Redis, Docker, npm | install.ps1 (PowerShell) | **Büyük fark.** kit_hub çok daha kolay kurulur. |
| **Windows desteği** | Alpha (imzasız .exe), PowerShell sınırlı | **Ana hedef** (PowerShell native) | **Fark.** kit_hub Windows için optimize. |
| **Kullanıcı sayısı** | Çok kullanıcılı (ekip) | Tek kullanıcı | **Farklı hedef kitle.** |
| **Olgunluk** | ~6676 PR, büyük ekip, aktif | v1.3.0, tek geliştirici | **Farklı ölçek.** |
---

## 5. Buzz KitHub İçin İşe Yarar mı? — Derin Değerlendirme

### 5.1 Doğrudan Taşınabilir / Düşük Maliyet-Yüksek Fayda

#### 5.1.1 Persona Pack Formatı → KitHub Ajanlarını Paketleme

KitHubın 36 ajanı (markdown + frontmatter) neredeyse birebir buzz persona pack formatına dönüşebilir:

- agents/episode-creator.md frontmatterı → agents/episode-creator.persona.md (model, trigger, mcp eklenir)
- skills/ → zaten SKILL.md formatında, OPS uyumlu
- Eksik: model seçimi, trigger konfigürasyonu, MCP araç tanımı, defaults

**Çıktı:** "Kitap Yazım Ekibi" buzz persona packi — herhangi bir buzz ortamında tek komutla yüklenebilir.

#### 5.1.2 Workflow Engine → Faz Tetikleyicileri

KitHubın faz kapıları (approval JSON dosyaları) buzz workflowdaki request_approval aksiyonu ile birebir eşleşir:

| KitHub | Buzz workflow |
|--------|---------------|
| runtime/approvals/design-freeze.json (approved=true/false) | action: request_approval (👍 reaction = onay) |
| require_user_approvals | timeout: "24h" |
| Forbidden content patterns | filter: trigger_text |
| Phase contracts | steps: [send_message, request_approval, call_webhook] |

**Çıktı:** Faz geçişlerini buzz kanalında canlı onay akışına taşımak.

#### 5.1.3 Run Journal → İmzalı Event Log

runtime/runs/{run_id}/run-journal.jsonl formatı:

    {"event":"phase.started","phase":"create","run_id":"RUN-..."}
    {"event":"phase.completed","phase":"create","status":"completed"}

Buzzda her satır bir Nostr eventi (kind:46001 KIND_WORKFLOW_STARTED) olabilir. buzz-audit hash-chaini kurcalanmaya karşı korur.

**Çıktı:** Yayıncı/denetçi için kurcalanmaya dayanıklı üretim kanıtı.

#### 5.1.4 MCP Araç Katmanı → PowerShell Adımları

KitHubın faz adımları (TDK kontrolü, layout kontrolü, export) MCP araçları olarak paketlenebilir:

- tdk-polisher → MCP aracı: tdk_check(text) -> {issues, score}
- quality-verifier → MCP aracı: verify_episode(path) -> {verdict, metrics}
- book-exporter → MCP aracı: export_docx(chapters, style) -> .docx

**Çıktı:** KitHub doğrulama mantığı herhangi bir MCP uyumlu ajan tarafından kullanılabilir.

### 5.2 Yüksek Değerli Ama Orta Maliyetli Entegrasyonlar

#### 5.2.1 Buzzı Dış Ortam Katmanı Olarak Kullanmak

En gerçekçi entegrasyon senaryosu:

    Buzz Relay
      #kitap-1 kanalı            #kitap-2 kanalı
      - yazar (insan)            - yazar (insan)
      - editör (insan)           - ajan-yazar (buzz-agent)
      - ajan-yazar               - editör (insan)
           │                          │
           └──────────┬───────────────┘
                      │ webhook (call_webhook)
                      ▼
    KitHub Doğrulama Motoru
    (run_pipeline.ps1: phase contracts, agent compliance,
     TDK checks, quality gates, export)
     - Girdi: buzzdan gelen webhook (faz başlatma)
     - Çıktı: doğrulama raporu → buzz kanalına geri
       (buzz-cli send_message veya webhook callback)

**Nasıl çalışır:**
1. Buzz kanalı oluşturulur: #kitap-1
2. Yazar (insan) veya ajan-yazar (buzz-agent) kanala mesaj gönderir: "bölüm 5 taslak hazır"
3. Buzz workflow (trigger: message_posted, filter: "bölüm.*hazır"): call_webhook → KitHub /api/run-pipeline
4. KitHub: create fazını çalıştırır (TDK, quality, kontinüite), doğrulama raporu üretir
5. KitHub: raporu doğrulama kanalına geri gönderir (buzz-cli send_message)
6. Editör kanalda 👍 ile onaylar
7. Onay → workflow request_approval → export fazı tetiklenir

**Faydası:** İnsan-ajan işbirliği canlı kanalda, tüm adımlar imzalı, denetlenebilir.

**Maliyeti:** Buzz relay kurulumu (Rust, Postgres, Redis, Docker), ajan anahtarı yönetimi, webhook konfigürasyonu.

#### 5.2.2 Gerçek Paralel Bölüm Üretimi

buzz-acp --agents 4 ile 4 ajan aynı anda farklı kanallarda farklı bölümler yazabilir. Ancak:

- **Risk:** Kontinüite (karakterler, olay örgüsü, zaman çizelgesi) paralel yazımda bozulabilir
- **KitHubın tasarımı:** Kontinüiteyi state ledgerlar + continuity-bridge ajanı ile korur — bu sıralı çalışma gerektirir
- **Çözüm:** Her bölüm ayrı bir kanalda, ortak state ledgerı paylaşarak — ancak state ledger güncellemeleri senkronize edilmelidir

**Öneri:** Kısa vadede tavsiye edilmez. KitHubın sıralı modeli kontinüite için doğru tasarım.

### 5.3 Düşük Değerli / Riskli Alanlar

#### 5.3.1 API Modunu buzz-acp ile Değiştirmek

KitHubın API modu (provider_phase.ps1) basit ve işlevsel: tek prompt → tek yanıt → dosyalar. Bunu buzz-acp ile değiştirmek:

- **Artı:** Gerçek ajan döngüsü (tool call, MCP, handoff)
- **Eksi:** Operasyonel yük (relay gerekli), offline-first bozulur, kurulum karmaşıklaşır
- **Karar:** Önerilmez. API modu kit_hubun ihtiyacını karşılıyor.

#### 5.3.2 KitHubı Buzz'a Bağımlı Hale Getirmek

KitHubın mevcut değeri: **offline-first, tek makine, kurulumu kolay**. Buzz bağımlılığı:

- Postgres + Redis + Rust derleme + relay yönetimi
- Windowsta ek zorluklar (Docker, WSL, imzasız binary)
- Her ajan için nsec yönetimi (güvenlik sorumluluğu)
- Yeni kullanıcı için öğrenme eğrisi

**Karar:** KitHubı buzz'a bağımlı kılmak yerine, buzzı isteğe bağlı dış katman olarak konumlandırmak.

### 5.4 Öncelikli Yol Haritası

| # | Ne yapılmalı? | Süre | Fayda | Risk |
|---|---------------|------|-------|------|
| 1 | KitHub ajanlarını buzz persona pack formatına dönüştürme (OPS uyumlu) | Kısa (1-2 gün) | Yüksek — taşınabilirlik, yeniden kullanım | Düşük — sadece metadata formatı |
| 2 | Buzz workflow approval modelini inceleme, kit_hub onay akışına fikir taşıma | Kısa (1 gün) | Orta — UX iyileştirmesi | Düşük — belge inceleme |
| 3 | buzz-workflow + webhook ile KitHub tetikleme (dış katman POC) | Orta (1 hafta) | Yüksek — canlı işbirliği | Orta — relay kurulumu |
| 4 | KitHub run journalını Nostr eventlerine dönüştürme (audit kanıtı) | Orta (3-5 gün) | Orta — yayıncı/denetçi için | Düşük — ekstra modül |
| 5 | KitHub MCP araç sunucusu (tdk_check, quality_verify, export_docx) | Orta (1-2 hafta) | Yüksek — her ajan kullanabilir | Orta — MCP öğrenme |
| 6 | buzz-acp + buzz-agent ile gerçek çok ajanlı çalışma | Uzun (2-4 hafta) | Yüksek — paralel üretim | Yüksek — kontinüite riski |
| 7 | KitHub Studioyu buzz entegrasyonu ile genişletme | Uzun (1+ ay) | Orta — niş kullanım | Yüksek — aşırı mühendislik |

---

## 6. Sonuç

### Buzz, KitHubın ajan sistemi midir? Hayır.

Buzz bir **ekip çalışma alanı + ajan runtimeıdır**. KitHub bir **Türkçe roman üretim hattı + doğrulama motorudur**. Aynı kategoride değillerdir.

### Buzz, KitHub için işe yarar mı? Bağlama bağlı.

| Kullanım senaryosu | İşe yarar mı? |
|--------------------|---------------|
| Tek yazar, offline, kendi bilgisayarında | **Hayır.** KitHub tek başına yeterli. |
| Yazar + editör + ajanlar aynı projede | **Evet.** Buzz kanal + mention + approval modeli değerli. |
| Olay-güdümlü otomasyon (bölüm yazıldı → kontrol → onay) | **Evet.** Buzz workflow + webhook ile KitHub tetiklenebilir. |
| Kurcalanmaya dayanıklı denetim (yayıncı/denetçi) | **Evet.** Nostr imzalı eventler + audit chain. |
| Paralel bölüm üretimi (N ajan = N bölüm) | **Riskli.** KitHub kontinüite modeli sıralı çalışma gerektirir. |
| Açık kaynak paket olarak dağıtım | **Evet.** Persona pack formatı (OPS) ile kit_hub ajanları paketlenebilir. |

### En Gerçekçi Entegrasyon

KitHubı buzz üzerinde çalışan bir **"kitap yazım ekibi"** olarak konumlandırmak:

1. Buzz kanalı = kitap projesi
2. Her ajan rolü = kanal üyesi (buzz-agent + kit_hub MCP araçları)
3. Buzz workflow = faz tetikleyicisi ve onay akışı
4. KitHub = doğrulama motoru (TDK, quality, export) — webhook ile çağrılır
5. Run journal = imzalı Nostr eventleri (denetim kanıtı)

**Ancak:** Bu entegrasyon, kit_hubun mevcut kullanıcı kitlesi (tek yazar, Windows, offline) için değil, **ekip/profesyonel yayıncılık** senaryoları içindir. Mevcut haliyle kit_hub, kendi hedefinde doğru ve işlevseldir.

---

## 7. Ek: Referans Dosya Haritası

### Buzz (kaynak kod)

| Dosya | İçerik |
|-------|--------|
| _workspace/_buzz_src/README.md | Proje genel bakış |
| _workspace/_buzz_src/ARCHITECTURE.md | Sistem mimarisi |
| _workspace/_buzz_src/VISION_AGENT.md | Ajan vizyonu |
| _workspace/_buzz_src/AGENTS.md | Ajan katkı rehberi |
| _workspace/_buzz_src/crates/buzz-acp/README.md | ACP harness (ana bağlantı) |
| _workspace/_buzz_src/crates/buzz-acp/src/relay.rs | Relay bağlantısı, WS, reconnect |
| _workspace/_buzz_src/crates/buzz-acp/src/acp.rs | ACP client (spawn, initialize, session, prompt, cancel) |
| _workspace/_buzz_src/crates/buzz-acp/src/queue.rs | Olay kuyruğu, batch, retry, dedup |
| _workspace/_buzz_src/crates/buzz-agent/README.md | Minimal ACP ajan |
| _workspace/_buzz_src/crates/buzz-agent/src/handoff.rs | Bağlam devri (handoff/özetleme) |
| _workspace/_buzz_src/crates/buzz-workflow/src/schema.rs | Workflow tanım şeması (TriggerDef, ActionDef) |
| _workspace/_buzz_src/crates/buzz-workflow/src/lib.rs | Workflow engine, authority gate |
| _workspace/_buzz_src/crates/buzz-persona/PERSONA_PACK_SPEC.md | Persona paket spesifikasyonu |
| _workspace/_buzz_src/crates/sprig/src/main.rs | Multicall binary dispatch |
| _workspace/_buzz_src/docs/remote-agents.md | Remote agent/mesh spesifikasyonu |

### KitHub

| Dosya | İçerik |
|-------|--------|
| README.md | Proje genel bakış |
| docs/AGENT_ORCHESTRATION_ARCHITECTURE.md | Contract-bound orchestration |
| docs/UPSTREAM_DEEP_COMPARE_2026-04-20.md | Upstream karşılaştırma |
| runtime/agent-registry.json | 36 ajan tanımı |
| runtime/agent-status-contract.json | Durum kontratı |
| runtime/phase-contracts/create.json | Faz kontratı örneği |
| runtime/agent-compliance/create.json | Uygunluk manifestosu örneği |
| runtime/runs/RUN-*/run-summary.json | Çalıştırma özeti örneği |
| runtime/runner-config.json | Runner yapılandırması |
| runtime/runner-config.provider.template.json | Provider modu yapılandırması |
| scripts/run_pipeline.ps1 | Ana pipeline runner (124KB) |
| scripts/provider_phase.ps1 | API modu faz yürütücü |
| scripts/ide_phase_prompt.ps1 | IDE modu prompt üretici |
| scripts/studio_bridge.ps1 | Studio web arka ucu (165KB) |
| skills/polish/references/handoff-contract.md | Ajanlar arası devir sözleşmesi |
| agents/chief-editor-orchestrator.md | Şef editör ajanı |
| agents/episode-creator.md | Bölüm yazarı ajanı |
| .claude-plugin/plugin.json | Claude Code plugin tanımı (v1.2.0) |
| VERSION | v1.3.0 |

---

*Rapor, 2026-08-25 tarihinde kit_hub-main (v1.3.0) ve block/buzz (commit 822c5ab) kaynak kodları üzerinde yapılan derinlemesine analiz sonucu hazırlanmıştır.*
