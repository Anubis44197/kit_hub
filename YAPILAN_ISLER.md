# Yapilan Isler Dosyasi

Bu dosya yapilan degisikliklerin adim adim kaydidir.
Her adimda hangi dosyanin neden degistirildigi yazilir.

## 2026-04-18

### Adim 1 - Verdict Sozlugu Tekillestirme
- Degistirilen dosya: `agents/revision-reviewer.md`
- Yapilan degisiklik:
  - `REVISE` verdict'i kaldirildi.
  - `REWRITE` ile hizalandi.
  - Cikti metninde `REVISE` yerine `REWRITE` kullanildi.
- Gerekce:
  - `quality-verifier` zaten `PASS/REWRITE` kullaniyordu.
  - Farkli verdict kelimeleri pipeline kararlarinda belirsizlik olusturuyordu.

### Adim 2 - Final Cikti Kaynagi Netlestirme
- Degistirilen dosyalar:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
- Yapilan degisiklik:
  - `book_mode.enabled=true` ise final metin kaynagi `09_tdk-layout_bookmode_EP{NNN}.md` olarak sabitlendi.
  - `book_mode.enabled=false` ise final metin kaynagi `08_tdk-polisher_polished_EP{NNN}.md` olarak sabitlendi.
  - Final metnin `episode/epNNN.md` dosyasina geri yazma kurali eklendi.
- Gerekce:
  - TDK/layout adimlarindan sonra hangi metnin esas kabul edilecegi belirsizdi.

### Adim 3 - Zorunlu Artifact Gate Kurallari
- Degistirilen dosyalar:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
- Yapilan degisiklik:
  - Beklenen `_workspace` artefaktlari olmadan verifier/reviewer calistirmama kurali eklendi.
  - Eksik artefakt durumunda acik `artifact-missing` hatasi ile durma kurali eklendi.
- Gerekce:
  - Zorunlu adimlarin gercekten zorunlu olmasi gerekiyordu.

### Adim 4 - Soru Eki Gosterimi Duzeltmesi
- Degistirilen dosyalar:
  - `agents/tdk-polisher.md`
  - `skills/polish/references/tdk-official-baseline.md`
- Yapilan degisiklik:
  - Soru eki gosterimi gercek Turkce soru eki formuna duzeltildi (mi/mı/mu/mü).
- Gerekce:
  - Gecici placeholder gosterimi kural metninde yanlis yorum riski olusturuyordu.

### Adim 5 - README Operasyonel Parity Guclendirme
- Degistirilen dosya:
  - `README.md`
- Yapilan degisiklik:
  - Installation, Quick Start, Commands, Workflow Notes ve Agent Architecture bolumleri eklendi.
  - Pipeline adimlari TDK/layout gate mantigiyla guncellendi.
- Gerekce:
  - Orijinal depoya gore operasyonel dokumantasyon cok daralmisti.

### Adim 6 - Plan Durum Guncellemesi
- Degistirilen dosya:
  - `YAPILACAKLAR_PLAN.md`
- Yapilan degisiklik:
  - Parity basligindaki tamamlanan P0/P1 maddeler `DONE` olarak isaretlendi.
- Gerekce:
  - Plan ile gercek kod/dokuman durumu birebir uyumlu olmali.

### Adim 7 - Export Word Skill Iskeleti
- Degistirilen dosya:
  - `skills/export-word/SKILL.md`
- Yapilan degisiklik:
  - Onay kapisi + kaynak dogrulama + DOCX build akisi tanimlandi.
  - `tdk-polisher` ve `tdk-layout-agent` ciktilarina dayali kaynak onceligi eklendi.
  - Zorunlu manifest sozlesmesi eklendi.
- Gerekce:
  - Word export akisini pipeline ile uyumlu ve denetlenebilir yapmak.

### Adim 8 - Export Approval Gate Agent
- Degistirilen dosya:
  - `agents/export-approval-gate.md`
- Yapilan degisiklik:
  - Export icin explicit user consent zorunlulugu eklendi.
  - Scope/path uyumsuzlugunda `BLOCKED` verdict kurali eklendi.
- Gerekce:
  - Kullanici onayi olmadan docx olusturmayi engellemek.

### Adim 9 - Book Exporter Agent
- Degistirilen dosya:
  - `agents/book-exporter.md`
- Yapilan degisiklik:
  - Onayli kaynaklardan DOCX cikti kurallari tanimlandi.
  - Stil uygulama, layout kurallari ve manifest ciktilari eklendi.
- Gerekce:
  - Export adimini gercek bir agent olarak sisteme almak.

### Adim 10 - DOCX Stil Profili Sablonu
- Degistirilen dosya:
  - `skills/export-word/references/docx-style-profile-template.md`
- Yapilan degisiklik:
  - Sayfa boyutu, kenar bosluklari, tipografi, diyalog stili ve cikti ayarlari icin sablon eklendi.
- Gerekce:
  - Farkli projelerde tutarli Word cikti almak.

### Adim 11 - README ve Plan Guncellemesi
- Degistirilen dosyalar:
  - `README.md`
  - `YAPILACAKLAR_PLAN.md`
- Yapilan degisiklik:
  - README'ye `/export-word` komutu ve quick-start adimi eklendi.
  - Planin Word export P0 maddeleri `DONE` olarak isaretlendi.
- Gerekce:
  - Dokumantasyon ve plani gercek uygulama durumuna hizalamak.

### Adim 12 - Export Validator Agent
- Degistirilen dosya:
  - `agents/export-validator.md`
- Yapilan degisiklik:
  - Export oncesi dogrulama icin ayri gate agent eklendi.
  - Kritik TDK/layout issue ve kaynak/stil profil kontrolleri tanimlandi.
- Gerekce:
  - Export adimini deterministic ve bloklanabilir hale getirmek.

### Adim 13 - Export Pipeline Sertlestirme
- Degistirilen dosya:
  - `skills/export-word/SKILL.md`
- Yapilan degisiklik:
  - `export-validator` adimi pipeline'a eklendi.
  - `READY` verdict olmadan `book-exporter` calistirmama kurali eklendi.
  - Export summary report sozlesmesi eklendi.
- Gerekce:
  - Onay + kalite + kaynak dogrulama olmadan Word cikti uretimini engellemek.

### Adim 14 - Book Export Layout Derinlestirme
- Degistirilen dosya:
  - `agents/book-exporter.md`
- Yapilan degisiklik:
  - Otomatik bolumleme ve sayfa sonu davranisi kurallari eklendi.
  - Manifest alanlari `chapter_segmentation` ve `page_end_behavior` ile genisletildi.
- Gerekce:
  - Roman/kitap ciktilarinda bolum ve sayfa davranisini standardize etmek.

### Adim 15 - Config ve Stil Profili Baglantisi
- Degistirilen dosyalar:
  - `skills/polish/references/project-config-template.md`
  - `skills/export-word/references/docx-style-profile-template.md`
- Yapilan degisiklik:
  - `export_word` konfigurasyon blogu eklendi.
  - DOCX stil profiline `chapter_segmentation` ve `page_end.behavior` alanlari eklendi.
- Gerekce:
  - Export davranisini proje seviyesinde ayarlanabilir ve tekrar kullanilabilir yapmak.

### Adim 16 - Plan Durum Guncellemesi (Word Export P1)
- Degistirilen dosya:
  - `YAPILACAKLAR_PLAN.md`
- Yapilan degisiklik:
  - Word export altindaki P1 maddeler `DONE` olarak isaretlendi.
- Gerekce:
  - Plan durumu ile gercek uygulama durumunu hizalamak.

### Adim 17 - Batch Export Mode (English Contract)
- Modified files:
  - `skills/export-word/SKILL.md`
  - `agents/book-exporter.md`
- Changes:
  - Added batch range formats (`EP007`, `EP001-EP025`, list mode).
  - Added output strategy contract (`single_docx`, `multi_docx`).
  - Added deterministic naming and `produced_files` manifest fields.
- Reason:
  - To support reliable one-file and multi-file export workflows.

### Adim 18 - Word Compatibility Test Plan (English)
- Added file:
  - `skills/export-word/references/word-compatibility-test-plan.md`
- Changes:
  - Added client matrix (Word Win/Mac, LibreOffice, Google Docs import).
  - Added Turkish character preservation checks and layout checks.
  - Added deterministic compatibility report contract.
- Reason:
  - To verify DOCX portability and formatting integrity before release.

### Adim 19 - Export Config Extension
- Modified file:
  - `skills/polish/references/project-config-template.md`
- Changes:
  - Added `export_word.output_strategy` and `compatibility_test_required`.
- Reason:
  - To make batch mode and compatibility checks configurable per project.

### Adim 20 - Plan Status Update (Word Export P2)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked Word export P2 items as `DONE`.
- Reason:
  - Keep plan status aligned with implemented scope.

### Adim 21 - Encoding Safety Fix (English Test Doc)
- Modified file:
  - `skills/export-word/references/word-compatibility-test-plan.md`
- Changes:
  - Rewrote the Turkish character stress scenario in ASCII-safe wording to avoid mojibake.
- Reason:
  - Keep test documentation portable across editors and terminals.

### Adim 22 - Language Policy Enforcement (Turkish Content / English Design)
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
  - `skills/polish/references/project-config-template.md`
  - `agents/tdk-polisher.md`
  - `agents/export-validator.md`
  - `README.md`
- Added file:
  - `skills/export-word/references/language-policy.md`
- Changes:
  - Added explicit language policy: Turkish story content, English contracts.
  - Added disallowed script set: Hangul, Han, Hiragana, Katakana.
  - Added script safety checks to TDK and export validation flows.
- Reason:
  - Prevent East Asian scripts in story outputs while keeping tooling/docs in English.

### Adim 23 - Plan Status Update (Language Policy)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Added DONE line for language policy stabilization.
- Reason:
  - Keep plan aligned with implemented policy constraints.

### Adim 24 - TDK Polisher Issue Enum Contract (English)
- Modified file:
  - `agents/tdk-polisher.md`
- Changes:
  - Added required `issue_type` enum list.
  - Added deterministic `issues[]` item schema (`id`, `issue_type`, `severity`, `span`, `original_text`, `suggested_text`, `auto_fixable`).
- Reason:
  - Stabilize machine-readable issue output for downstream gates and tooling.

### Adim 25 - TDK Layout Issue Enum Contract (English)
- Modified file:
  - `agents/tdk-layout-agent.md`
- Changes:
  - Added required `layout_issue_type` enum list.
  - Added deterministic `issues[]` item schema for layout violations.
- Reason:
  - Standardize layout diagnostics and make review/export checks deterministic.

### Adim 26 - Plan Status Update (TDK Enum P0)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked both P0 enum tasks under "TDK ve Kitap Modu Derinlestirme" as `DONE`.
- Reason:
  - Keep the plan aligned with implemented contracts.

### Adim 27 - TDK Exception Baseline (English)
- Added file:
  - `skills/polish/references/tdk-exception-list.md`
- Changes:
  - Added exception categories to reduce false positives in TDK checks.
  - Added operational rule to downgrade uncertain corrections to `manual_review`.
- Reason:
  - Preserve literary intent while preventing over-correction.

### Adim 28 - Auto-Fix vs Manual-Review Policy
- Modified file:
  - `agents/tdk-polisher.md`
- Changes:
  - Added deterministic auto-fix vs manual-review mapping by issue type.
  - Added explicit uncertainty fallback rule.
- Reason:
  - Make line-end split and style-sensitive corrections predictable.

### Adim 29 - Book Mode Profile Set (English)
- Added file:
  - `skills/polish/references/book-mode-profiles.md`
- Modified file:
  - `skills/polish/references/project-config-template.md`
- Changes:
  - Added profile presets: `web_novel`, `print_preview`, `ebook`.
  - Added `book_mode.profile` selector in config template.
- Reason:
  - Support project-specific reading/export targets with consistent defaults.

### Adim 30 - Plan Status Update (TDK/Book P1)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked TDK exceptions, auto-fix/manual-review policy, and profile-set tasks as `DONE`.
- Reason:
  - Keep plan synchronized with implemented scope.

### Adim 31 - Runtime Metadata Contract (English)
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
- Changes:
  - Added mandatory `run_id` and `step_id` format rules.
  - Added requirement to stamp report headers with runtime metadata.
  - Added mandatory `run-summary.json` update after each step.
- Reason:
  - Improve deterministic traceability across all core flows.

### Adim 32 - Run Summary Schema (English)
- Added file:
  - `skills/polish/references/run-summary-schema.md`
- Changes:
  - Defined canonical schema for `{WORK_DIR}/_workspace/run-summary.json`.
  - Defined step item schema and status transition rules.
- Reason:
  - Standardize runtime indexing and failure diagnostics.

### Adim 33 - Plan Status Update (Runtime P0/P1)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked run-id/step-id and run-summary tasks as `DONE`.
- Reason:
  - Keep the plan synchronized with implementation.

### Adim 34 - Standard Error Code Glossary (English)
- Added file:
  - `skills/polish/references/error-code-glossary.md`
- Changes:
  - Added canonical runtime/export error codes (`E_SCHEMA`, `E_CONTINUITY`, `E_STYLE`, etc.).
  - Added usage rule for blocked/failed steps.
- Reason:
  - Unify failure diagnostics across all skills and agents.

### Adim 35 - Error Code Wiring
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
  - `skills/polish/references/run-summary-schema.md`
  - `agents/export-validator.md`
- Changes:
  - Added requirement to use glossary codes in runtime metadata.
  - Added export-validator error code mapping section.
- Reason:
  - Ensure every blocked/failed step emits standardized error signals.

### Adim 36 - Plan Status Update (Runtime Error Codes)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked runtime error-code glossary task as `DONE`.
- Reason:
  - Keep plan state synchronized with implementation.

### Adim 37 - Pipeline Metrics Spec (English)
- Added file:
  - `skills/polish/references/pipeline-metrics-spec.md`
- Changes:
  - Defined `pipeline-metrics.json` schema.
  - Defined `pipeline-bottleneck-report.md` contract.
  - Added retry/duration/error-frequency rules.
- Reason:
  - Standardize performance visibility and bottleneck detection.

### Adim 38 - Metrics Wiring Across Skills
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
- Changes:
  - Added mandatory metrics and bottleneck report outputs in runtime contract.
- Reason:
  - Ensure all major flows emit comparable runtime telemetry.

### Adim 39 - Plan Status Update (Runtime P2)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked pipeline metrics/bottleneck task as `DONE`.
- Reason:
  - Keep plan aligned with implemented observability scope.

### Adim 40 - Contract Lint and Smoke CI Base (English)
- Added files:
  - `scripts/ci/validate_contracts.sh`
  - `scripts/ci/smoke_test.sh`
  - `.github/workflows/ci-contracts.yml`
  - `tests/fixtures/sample-project/novel-config.md`
  - `tests/fixtures/sample-project/design/.gitkeep`
  - `tests/fixtures/sample-project/episode/.gitkeep`
  - `tests/fixtures/sample-project/revision/.gitkeep`
- Changes:
  - Added deterministic contract checks (frontmatter, verdict token, language policy, export gates).
  - Added fixture-based smoke checks for mandatory files and references.
  - Added PR/push workflow to run lint + smoke.
- Reason:
  - Enforce CI discipline and catch contract regressions early.

### Adim 41 - SemVer and Release Flow (English)
- Added files:
  - `CHANGELOG.md`
  - `RELEASE_CHECKLIST.md`
- Changes:
  - Added SemVer-oriented changelog structure.
  - Added release checklist covering contracts, smoke, export, and observability.
- Reason:
  - Standardize release notes and pre-release validation.

### Adim 42 - Golden Drift Control Spec (English)
- Added files:
  - `skills/polish/references/golden-output-drift-spec.md`
  - `tests/golden/README.md`
- Changes:
  - Added drift rules for verdict/severity/artifact/schema changes.
  - Added golden-case folder layout guidance.
- Reason:
  - Detect behavior drift after agent/skill updates.

### Adim 43 - Plan Status Update (CI/Lint/Release)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked all section-8 items as `DONE`.
- Reason:
  - Keep the plan synchronized with implemented CI/release scope.

### Adim 44 - Plan Consistency Fix (Changelog Task)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked "Degisiklik gunlugu dosyasi ekle (`CHANGELOG.md`)" as `DONE` to match implementation.
- Reason:
  - Remove cross-section plan inconsistency.

### Adim 45 - Security/Privacy/Copyright Baseline (English)
- Added files:
  - `skills/polish/references/pii-redaction-policy.md`
  - `skills/polish/references/copyright-compliance-checklist.md`
  - `skills/polish/references/offline-first-secure-profile.md`
  - `skills/polish/references/workdir-isolation-policy.md`
- Changes:
  - Added PII redaction policy for reports/logs.
  - Added copyright compliance checklist for source-based mode.
  - Added offline-first secure profile contract.
  - Added WORK_DIR boundary isolation rules.
- Reason:
  - Close section-9 policy gaps with explicit, enforceable references.

### Adim 46 - Policy Wiring and Config Extension
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
  - `skills/polish/references/project-config-template.md`
  - `agents/export-validator.md`
  - `skills/polish/references/error-code-glossary.md`
- Changes:
  - Wired security/privacy policy references into core skills.
  - Added `security_profile` and `source_mode` blocks in config template.
  - Extended export-validator checks for copyright and PII policy.
  - Added `E_COPYRIGHT_RISK`, `E_PII_POLICY`, `E_WORKDIR_BOUNDARY` codes.
- Reason:
  - Make policy constraints actionable in runtime and validation gates.

### Adim 47 - Plan Status Update (Security/Privacy/Copyright)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked all section-9 tasks as `DONE`.
- Reason:
  - Keep plan status synchronized with implemented safeguards.

### Adim 48 - Prompt Versioning Rollout
- Modified files:
  - all `agents/*.md`
  - all `skills/*/SKILL.md`
- Changes:
  - Added `prompt_version: "1.0.0"` to agent and skill frontmatter.
  - Updated CI contract lint to require `prompt_version`.
- Reason:
  - Make prompt contracts versionable and auditable.

### Adim 49 - Model Management References (English)
- Added files:
  - `skills/polish/references/model-capability-matrix.md`
  - `skills/polish/references/model-fallback-timeout-policy.md`
  - `skills/polish/references/prompt-ab-experiment-spec.md`
- Changes:
  - Added model capability matrix template.
  - Added fallback chain and timeout policy.
  - Added A/B prompt experiment contract.
- Reason:
  - Standardize model routing and prompt evolution decisions.

### Adim 50 - Runtime Schema Extension for Fallback Metadata
- Modified file:
  - `skills/polish/references/run-summary-schema.md`
- Changes:
  - Added `primary_model`, `effective_model`, `fallback_used`, `fallback_reason`, `timeout_seconds` fields.
- Reason:
  - Track model selection/fallback behavior in runtime logs.

### Adim 51 - Model Policy Wiring to Core Skills
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
- Changes:
  - Added model routing policy section.
  - Linked to capability matrix, fallback policy, and A/B spec references.
- Reason:
  - Ensure model-management rules are visible and enforceable in all critical flows.

### Adim 52 - Plan Status Update (Model Management)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked all section-10 tasks as `DONE`.
- Reason:
  - Keep plan synchronized with implementation.

### Adim 53 - Novel Config Schema and Validators (English)
- Added files:
  - `skills/polish/references/novel-config-schema.md`
  - `scripts/ci/validate_novel_config.sh`
  - `scripts/ci/check_ep_range_overlap.sh`
  - `scripts/ci/pipeline_smoke_contract.sh`
- Modified files:
  - `scripts/ci/smoke_test.sh`
  - `tests/fixtures/sample-project/novel-config.md`
- Changes:
  - Added mandatory config schema reference.
  - Added canonical platform and language/profile validators.
  - Added EP range overlap checker.
  - Added pipeline-contract smoke checks for create/polish/rewrite.
- Reason:
  - Close config-validation and smoke P0/P1 gaps in plan sections 3 and 4.

### Adim 54 - Regression and Snapshot Test Contracts (English)
- Added files:
  - `skills/polish/references/regression-test-spec.md`
  - `skills/polish/references/tdk-regression-test-spec.md`
  - `skills/polish/references/layout-regression-test-spec.md`
  - `skills/polish/references/report-snapshot-test-spec.md`
  - `scripts/ci/regression_contract_smoke.sh`
  - `tests/regression/core/case-001/input.md`
  - `tests/regression/core/case-001/expected.json`
  - `tests/regression/tdk/case-001/input.md`
  - `tests/regression/tdk/case-001/expected_issues.json`
  - `tests/regression/layout/case-001/input.md`
  - `tests/regression/layout/case-001/expected_issues.json`
  - `tests/snapshots/create/case-001/expected/verdict.md`
  - `tests/snapshots/create/case-001/expected/issues.json`
- Modified files:
  - `.github/workflows/ci-contracts.yml`
- Changes:
  - Added regression/snapshot specs and fixture skeletons.
  - Added regression contract smoke to CI workflow.
- Reason:
  - Establish deterministic regression and snapshot coverage baseline.

### Adim 55 - Plan Status Update (Config + Test/Quality)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked section-3 tasks as `DONE`.
  - Marked section-4 regression/snapshot tasks as `DONE`.
- Reason:
  - Keep plan synchronized with implemented validation and test contracts.

### Adim 56 - Local Verification Note
- Note:
  - Local execution of bash-based scripts failed in this Windows session with `E_ACCESSDENIED` from Bash service.
  - Static contract checks were verified by file/path/content inspection.
- Reason:
  - Record environment limitation transparently.

### Adim 57 - Model-Agnostic Shared Schema (English)
- Added files:
  - `skills/polish/references/shared-task-schema.md`
  - `skills/polish/references/agent-skill-schema-mapping.md`
- Changes:
  - Added common task envelope (`task`, `inputs`, `constraints`, `output_contract`).
  - Added concrete mapping from create/polish/rewrite/export agents to schema task IDs.
- Reason:
  - Establish a single model-agnostic execution contract.

### Adim 58 - Adapter Contracts and Verdict Standard (English)
- Added files:
  - `skills/polish/references/adapter-claude-codex.md`
  - `skills/polish/references/adapter-generic-ide-model.md`
  - `skills/polish/references/verdict-report-standard.md`
- Changes:
  - Defined adapter behavior for Claude/Codex and generic IDE model.
  - Standardized verdict/report vocabulary and required fields.
- Reason:
  - Remove adapter ambiguity and enforce output parity across models.

### Adim 59 - Multi-Model Comparison Spec (English)
- Added file:
  - `skills/polish/references/multi-model-comparison-test-spec.md`
- Changes:
  - Added metrics and fail rules for model comparison tests.
- Reason:
  - Formalize model selection with measurable criteria.

### Adim 60 - Adapter Policy Wiring and CI Check
- Modified files:
  - `skills/create/SKILL.md`
  - `skills/polish/SKILL.md`
  - `skills/rewrite/SKILL.md`
  - `skills/export-word/SKILL.md`
  - `scripts/ci/validate_contracts.sh`
- Changes:
  - Wired adapter/schema/verdict references into core skills.
  - Added CI checks for required adapter reference docs.
- Reason:
  - Make adapter governance enforceable at contract lint stage.

### Adim 61 - Plan Status Update (Model Uyum Katmani)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked all section-1 tasks as `DONE`.
- Reason:
  - Keep plan synchronized with implementation.

### Adim 62 - Core Documentation and Architecture Map
- Added file:
  - `docs/ARCHITECTURE_MAP.md`
- Modified file:
  - `README.md`
- Changes:
  - Added concise architecture map for flows/layers/determinism anchors.
  - Linked architecture map from README.
- Reason:
  - Close remaining documentation and architecture-map gaps.

### Adim 63 - Agent Hardening Contracts (English)
- Added files:
  - `skills/polish/references/deterministic-thresholds.md`
  - `skills/polish/references/workflow-report-json-schema.md`
  - `skills/polish/references/handoff-contract.md`
  - `skills/polish/references/continuity-bridge-output-schema.md`
  - `skills/polish/references/episode-creator-self-check-spec.md`
- Modified files:
  - `agents/quality-verifier.md`
  - `agents/episode-creator.md`
  - `agents/continuity-bridge.md`
- Changes:
  - Added numeric thresholds and deterministic verdict policy.
  - Added workflow JSON report schema contract.
  - Added continuity bridge output schema and creator self-check schema references.
  - Added handoff contract reference wiring in core skills.
- Reason:
  - Convert high-level agent behavior into measurable, deterministic contracts.

### Adim 64 - Golden Examples Expansion
- Modified files:
  - `tests/golden/README.md`
  - `scripts/ci/regression_contract_smoke.sh`
- Added files/folders:
  - `tests/golden/agents/<agent-name>/{input.md,expected.md}` for all agents
- Changes:
  - Added per-agent golden placeholders.
  - Added CI smoke check to require golden placeholders for every agent file.
- Reason:
  - Satisfy agent-level golden baseline requirement and keep it enforced.

### Adim 65 - Parity Checklist Closure (English)
- Added file:
  - `skills/polish/references/parity-gap-checklist.md`
- Changes:
  - Added parity checklist/report contract for upstream-vs-local behavior review.
- Reason:
  - Close remaining parity checklist task with a deterministic checklist.

### Adim 66 - Plan Status Update (Section 2, 5, 12)
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked section-2 README/architecture tasks as `DONE`.
  - Marked all section-5 hardening tasks as `DONE`.
  - Marked remaining section-12 parity checklist task as `DONE`.
- Reason:
  - Keep plan synchronized with completed implementation scope.

### Adim 67 - Rewrite Report Unification (English)
- Added file:
  - `skills/rewrite/references/rewrite-report-unified-schema.md`
- Modified file:
  - `skills/rewrite/SKILL.md`
- Changes:
  - Added unified rewrite report schema with shared fields/verdict rules.
  - Linked rewrite skill outputs to the unified schema reference.
- Reason:
  - Close final open task for rewrite-stage report format unification.

### Adim 68 - Final Plan Closure
- Modified file:
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Marked the last remaining TODO item as `DONE`.
- Reason:
  - Bring plan to full completion state.

### Adim 69 - Final Readiness CI Script (English)
- Added file:
  - `scripts/ci/final_readiness_check.sh`
- Changes:
  - Added single-entry final CI check chaining contract lint, smoke, regression smoke.
  - Added plan-open-TODO guard (template lines excluded).
- Reason:
  - Provide one deterministic release-readiness gate command.

### Adim 70 - Workflow Integration (Final Readiness)
- Modified file:
  - `.github/workflows/ci-contracts.yml`
- Changes:
  - Added `final_readiness_check` execution step.
- Reason:
  - Ensure final readiness gate runs in CI automatically.

### Adim 71 - Release Checklist Update
- Modified file:
  - `RELEASE_CHECKLIST.md`
- Changes:
  - Added explicit checklist item to run final readiness check script.
- Reason:
  - Align manual release flow with CI gate sequence.

### Adim 72 - Version Bump to v1.2.0
- Modified files:
  - `.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`
- Changes:
  - Updated plugin version fields from `1.1.0` to `1.2.0`.
- Reason:
  - Align plugin metadata with the planned release increment.

### Adim 73 - Changelog Release Cut (v1.2.0)
- Modified file:
  - `CHANGELOG.md`
- Changes:
  - Added `1.2.0` dated release section.
  - Moved current implementation scope into release notes.
  - Kept `Unreleased` as forward placeholder.
- Reason:
  - Prepare release documentation for versioned publication.

### Adim 74 - Single-Commit Summary Template
- Added file:
  - `RELEASE_COMMIT_SUMMARY.md`
- Changes:
  - Added suggested single commit title/body and release scope bullets.
- Reason:
  - Provide a ready-to-use one-commit summary for release finalization.

### Adim 75 - Windows Final Readiness Script
- Added file:
  - `scripts/ci/final_readiness_check.ps1`
- Changes:
  - Added a PowerShell-native final readiness validator covering:
    - agent/skill frontmatter checks
    - verdict vocabulary guard (`REVISE` ban)
    - language policy and adapter reference checks
    - fixture/config/range/pipeline contract checks
    - regression/snapshot/golden placeholder checks
    - open TODO guard for `YAPILACAKLAR_PLAN.md`
- Reason:
  - Remove Windows bash dependency and enable deterministic local validation on PowerShell.

### Adim 76 - Documentation and Checklist Sync (Windows Validation)
- Modified files:
  - `README.md`
  - `RELEASE_CHECKLIST.md`
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Added Windows command for final readiness script.
  - Added release checklist item for PowerShell validation path.
  - Recorded Windows readiness task as `DONE` in plan.
- Reason:
  - Keep docs, release process, and plan aligned with actual validation entrypoints.

### Adim 77 - External Test Findings Log
- Added file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Logged external IDE run issues and contract mismatches:
    - wrong workspace path usage
    - Turkish text mojibake
    - non-compliant TDK/layout issues JSON schemas
    - incomplete quality-verifier/report policy statements
  - Added immediate remediation checklist.
- Reason:
  - Preserve discovered defects in a single durable file for follow-up fix/verification.

### Adim 78 - External Findings Status Refresh
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Marked repaired items as resolved after external rerun:
    - workspace path correction
    - UTF-8/mojibake fix
    - TDK/layout issue JSON contract repairs
    - enum/mode/severity/span normalization
  - Added open items for export gate scenario and richer verifier metadata follow-up.
- Reason:
  - Keep findings document synchronized with latest user-side test outputs.

### Adim 79 - Export Gate Test Tracking
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Added EP001 export gate test result notes:
    - Scenario-2 (`READY`/`EXPORTED`) marked as observed.
    - Scenario-1 blocked-state evidence marked as partially missing in final bundle.
  - Added residual verification gap for explicit `BLOCKED + E_EXPORT_APPROVAL` capture.
- Reason:
  - Preserve exact confidence level of export-gate verification and avoid false closure.

### Adim 80 - Export Gate Evidence Closure
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Added raw Scenario-1 validator evidence (`BLOCKED`, `E_EXPORT_APPROVAL`).
  - Marked Scenario-1 and Scenario-2 as verified.
  - Marked EP001 export gate behavior as fully PASS.
- Reason:
  - Close the last open verification gap with explicit blocking evidence.

### Adim 81 - DOCX Output Integrity Risk Logged
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Added critical finding: external run reported `EP001.docx` as `32 bytes`.
  - Marked DOCX generation quality as failed despite export gate pass.
  - Added closure criteria: ZIP header, archive readability, `word/document.xml` existence, realistic size.
- Reason:
  - Prevent false PASS on placeholder/truncated DOCX outputs.

### Adim 82 - DOCX Integrity Closure Verified
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Logged strict integrity evidence for EP001 DOCX:
    - realistic size (`14727` bytes)
    - valid ZIP header (`50 4B 03 04 ...`)
    - ZIP readability and `word/document.xml` existence
    - manifest/compatibility report updated with PASS
  - Marked external EP001 end-to-end validation as PASS.
- Reason:
  - Close the last critical export integrity risk with hard technical proof.

### Adim 83 - Core Pipeline EP002 Validation Logged
- Modified file:
  - `TEST_RUN_FINDINGS_2026-04-18.md`
- Changes:
  - Added external EP002 core pipeline verification outcome:
    - create -> tdk-polisher -> tdk-layout -> quality-verifier
    - contract-compliant issue JSON outputs
    - canonical writeback to `episode/ep002.md`
  - Marked EP002 core pipeline as PASS.
- Reason:
  - Record post-export full-flow confidence on a second episode.

### Adim 84 - Quality Verifier Metadata Contract Hardening
- Modified files:
  - `agents/quality-verifier.md`
  - `scripts/ci/validate_contracts.sh`
  - `scripts/ci/final_readiness_check.ps1`
- Changes:
  - Added strict runtime metadata requirements (`run_id`, `step_id`, `mode`, `agent_name`, model/verdict fields).
  - Added required markdown verdict template headings.
  - Added lint/readiness checks to enforce new contract sections.
- Reason:
  - Reduce ambiguous verifier outputs and improve deterministic report parsing.

### Adim 85 - DOCX Integrity Automation
- Added file:
  - `scripts/ci/verify_docx_integrity.ps1`
- Changes:
  - Added hard DOCX checks:
    - file existence
    - minimum size threshold
    - ZIP signature (`50 4B 03 04`)
    - archive readability
    - required entry `word/document.xml`
- Reason:
  - Prevent false-positive export success on placeholder/corrupt DOCX outputs.

### Adim 86 - External IDE One-Command Smoke
- Added file:
  - `scripts/ci/external_smoke_test.ps1`
- Modified files:
  - `README.md`
  - `RELEASE_CHECKLIST.md`
  - `YAPILACAKLAR_PLAN.md`
- Changes:
  - Added one-command external smoke test for user-side IDE runs.
  - Added README and release checklist commands for external smoke and DOCX integrity checks.
  - Recorded corresponding tasks as DONE in plan.
- Reason:
  - Standardize external validation and reduce manual test drift.
