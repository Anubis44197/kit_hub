# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Note
- Reserved for post-`1.2.0` changes.

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
