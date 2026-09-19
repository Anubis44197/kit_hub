# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Added
- Adapter activation evidence gates: `scripts/ci/adapter_inventory_contract_test.ps1` rejects any enabled adapter without proof; `scripts/ci/adapter_canary_report.ps1` reports pilot evidence.
- Observer integration: `scripts/capture_observer_snapshot.ps1` writes `runtime/agent-runs/<runId>/observer.jsonl` per task run (fail-open, skips `usage` on an empty database).
- Memory integration: `scripts/save_memory_record.ps1` plus context-pack selection, so a later run carries earlier decision/verification records.
- Story-state memory: `scripts/save_story_state_record.ps1` turns `revision/_state` ledgers (character-state, plot-ledger, continuity-ledger) into schema-compliant `story_state` records after each run (fail-open); the context pack carries the last N records across phases so character locations, events, and continuity violations survive as the book grows; `scripts/ci/story_state_memory_test.ps1` proves the chain.
- Headroom engine: `scripts/headroom_reduce.ps1` (deterministic, fail-open) with measured 48–78% reduction on real tool logs/JSON, plus `scripts/ci/headroom_pilot_ab.ps1`.
- codebase-memory-mcp activation: `scripts/install_codebase_memory.ps1` (SHA-256 verified install to a DACL-clean path), `scripts/query_codebase_graph.ps1`, `scripts/ci/lib_mcp_stdio.ps1` (event-based stdio client), `scripts/ci/codebase_memory_fixture_test.ps1`, and opt-in code graph context in `build_context_pack.ps1 -IncludeCodebaseContext`.

### Changed
- codebase-memory-mcp runs from `%LOCALAPPDATA%\Programs\codebase-memory-mcp\` instead of the in-repo `.tools` copy, whose ancestor chain carries untrusted mutation ACEs (binary refuses to start there). No user-folder ACL changes are required.
- MCP stdio responses are read event-based; the previous `Peek()` polling lost the `tools/list` reply while the daemon logged it as successful.
- Headroom gate thresholds read the adapter config instead of hard-coded constants; pilot size floor lowered to 32 KiB.

### Note
- Reserved for post-`1.3.0` changes.

## [1.4.0] - 2026-08-19

### Added
- Rehberli Mod (guided mode): three-stage flow (1 Project, 2 Book Design, 3 Write & Export) with start/done panels, automatic stage advancement, and a persistent "Gelişmiş Mod" toggle.
- 13-step design wizard with card galleries for layout profile, page design, and typeface; per-step approval and a bulk-approval dialog.
- "Tek Akışta Yaz & Çıkar" single-flow execution: sequential phase ranges (intake→design-big, design-small→polish, rewrite→export) via the bridge, with an IDE single-command fallback.
- AI cover image generation: `Generate-CoverImage` and `/api/cover-asset/generate` (OpenAI images), cover upload/read endpoints, and a "Kapak Görseli" toolbar in the cover studio that auto-approves the cover step.
- Bridge endpoints: `/api/wizard-state/read|save`, `/api/desktop-package/open` (mirrors Export-ToDesktop naming), `/api/run-pipeline`, `/api/new-project`; wizard bundle served at `/assets/studio-wizard.js`; no-cache headers on static responses.
- Faz şeridi (phase strip): compact top-bar trigger with a detailed 9-phase production popover (number, title, description, status), always visible and reopenable.
- Real "Akış" tab in the right panel (Asistan / Akış / Yayın): the previously hidden 9-phase flow list is now a first-class tab with progress, plus "Tek Akışta Yaz & Çıkar" and "İçerik Akışını Çalıştır" quick actions.

### Changed
- Wizard bar simplified from six buttons to three: `← Önceki` · `Adımı Onayla` · `Sonraki →` plus progress (x/13), 13 step chips, and "Tek Akışta Yaz & Çıkar". "Onayı Aç" was removed and "Toplu Onay" collapsed into a subtle link; the summary dialog is unchanged.
- Approval is now a review marker, not a lock: controls are never disabled, and changing a selection on an approved step automatically clears that step's approval (it must be approved again). The `wz-locked`/dimming behavior was removed.
- Top bar de-duplicated: the injected ⚡▦✚ menus (Motor / Paneller / Araçlar) and the "Export Fazını Çalıştır" button were removed — every action already exists elsewhere (Tek Akışta in the wizard bar and Akış tab; panel toggles in the top-bar chrome controls; publication tools in the Yayın tab).
- Guided mode shows the full typography panel ("eskisi gibi") with all tabs and groups visible; the active wizard step's group and gallery are highlighted with a green outline instead of hiding the rest.
- Guided-mode interface: design controls moved to the right panel, bottom panel collapsed (`--type-h: 0`), preview centered with full height; nothing squeezed.
- Wizard bar, galleries, start/done cards, and dialogs restyled to the app dark theme.
- `start_studio.ps1` rewritten to spawn the bridge fully detached (WMI) with port cleanup and log files; the bridge auto-starts at Windows logon via a Startup-folder launcher.

### Fixed
- Wizard module never loaded because the bridge static whitelist lacked `/assets/studio-wizard.js`; route added.
- Stale JavaScript in the browser: no-cache headers added to bridge static responses.
- Phase strip defaulted to hidden; now visible by default with a permanent trigger button.

## [1.3.0] - 2026-08-16

### Added
- Structured editor node support: GFM tables and footnotes (`[^1]`) with ProseMirror round-trip, toolbar buttons and `structuredEditorApi.run("table")` / `run("footnote")`.
- Rich editor e2e coverage: markdown round-trip for bold/italic/underline, table/footnote/image nodes, and toolbar insertion.
- Print proof checks: page overflow, chapter start parity (odd/even), and cover spine/barcode checks for KDP and Ingram fixtures.
- Ingram PDF/X-3 + CMYK conversion via Ghostscript and CI test.
- `VERSION` single source of truth consumed by the portable package, installer, and CI.

### Changed
- Portable package now embeds `VERSION` and a versioned changelog.
- `browser_e2e_test.ps1` PASS gate extended with structured-node and rich-round-trip assertions.

## [1.2.0] - 2026-04-18

### Added
- `tdk-polisher` and `tdk-layout-agent` integration into create/polish/rewrite flows.
- Export pipeline agents: `export-approval-gate`, `export-validator`, `book-exporter`.
- `export-word` skill with approval gate, validator gate, batch mode, and compatibility test plan.
- Runtime contracts: `run_id`, `step_id`, `run-summary.json`, error-code glossary, metrics spec.
- Language policy: Turkish content, English contracts, disallowed East Asian scripts.
- CI contract lint/smoke/regression/final-readiness workflows and fixtures.
- Model management references: capability matrix, fallback-timeout policy, prompt A/B spec.

### Changed
- Unified verdict vocabulary to `PASS/REWRITE`.
- Added deterministic issue enums and schemas for TDK and layout diagnostics.
- Expanded README with operational workflow and `/export-word`.
- Standardized rewrite unified report schema.

## [1.1.0] - 2026-04-18

### Note
- Baseline upstream version reference before local hardening and adaptation.
