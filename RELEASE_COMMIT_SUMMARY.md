# Release Commit Summary (v1.2.0)

## Suggested Commit Title
`release: v1.2.0 contract-hardening, export pipeline, and CI governance`

## Commit Scope
- Added Turkish-first writing governance (`tdk-polisher`, `tdk-layout-agent`, language policy).
- Added approval-gated Word export flow (`export-word`, `export-approval-gate`, `export-validator`, `book-exporter`).
- Added deterministic runtime contracts (`run_id`, `step_id`, `run-summary`, error codes, metrics, bottleneck report).
- Added model-management contracts (shared schema, adapters, fallback policy, A/B spec).
- Added CI contract validation, smoke checks, regression/snapshot/golden scaffolds, final readiness gate.
- Added security/privacy/copyright policies and WORK_DIR isolation.
- Updated docs, changelog, and release checklist.

## Suggested Commit Body
- Introduces v1.2.0 operational hardening for multi-agent Turkish novel production.
- Standardizes verdict/error/report schemas and enforces policy through CI checks.
- Adds release-readiness and export governance with explicit user approval gates.
