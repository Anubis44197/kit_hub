# Architecture Map

## Flow Overview
- `propose` -> idea candidates and selection
- `design-big` -> macro architecture
- `design-small` -> episode-range detail
- `create` -> draft + TDK/layout + quality gate
- `polish` -> diagnostics + revision loop + TDK/layout + review gate
- `rewrite` -> drift analysis + rewrite + TDK/layout + quality gate
- `export-word` -> approval + validator + front matter + cover brief + DOCX build

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
- agent registry (`runtime/agent-registry.json`)
- agent status contract (`runtime/agent-status-contract.json`)
- phase contracts (`runtime/phase-contracts/*.json`)
- run journal (`runtime/runs/{run_id}/run-journal.jsonl`)

## Agent Governance Layer
- Agents are registered centrally and are allowed only in declared phases.
- Phase contracts declare mandatory agents, references, input state, approvals, allowed outputs, and denied outputs.
- Compliance manifests must include `agent_statuses`; every required agent must be `completed`.
- The runner writes append-only JSONL events so claims can be audited after execution.

## Complete Book Package Layer
- `front-matter-editor`: title page, copyright placeholders, preface, and TOC plan
- `cover-designer`: front-cover brief, back-cover copy, and spine guidance
- `book-structure-optimizer`: chapter purpose, pacing, continuity, and reader-promise checks
- `book-exporter`: final DOCX package assembly with print blockers surfaced in manifest
