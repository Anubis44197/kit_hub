# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Note
- Reserved for post-`1.3.0` changes.

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
