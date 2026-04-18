# Architecture Map

## Flow Overview
- `propose` -> idea candidates and selection
- `design-big` -> macro architecture
- `design-small` -> episode-range detail
- `create` -> draft + TDK/layout + quality gate
- `polish` -> diagnostics + revision loop + TDK/layout + review gate
- `rewrite` -> drift analysis + rewrite + TDK/layout + quality gate
- `export-word` -> approval + validator + DOCX build

## Core Layers
- `agents/`: execution roles
- `skills/`: orchestration contracts
- `skills/polish/references/`: governance, schema, policy, testing specs
- `scripts/ci/`: contract and smoke validation
- `tests/`: fixtures, regression cases, snapshots, golden scaffolds

## Determinism Anchors
- standardized verdict vocabulary
- standardized error-code glossary
- run metadata (`run_id`, `step_id`)
- mandatory artifact gates
- issue enum contracts (TDK/layout)
