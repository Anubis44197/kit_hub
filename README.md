# Novel Writing Engine

Professional multi-agent pipeline for Turkish long-form fiction production.

## Overview
This repository provides an agent + skill based writing system for end-to-end novel production.

Primary flow:
`/propose -> /design-big -> /design-small -> /create -> /polish -> /rewrite -> /export-word`

## Repository Positioning (Upstream vs This Repository)
This project is based on the upstream architecture (`MJbae/awesome-novel-studio`) and extended for stricter Turkish publication workflow.

| Criteria | Upstream (`awesome-novel-studio`) | This Repo (`kit_hub`) |
|---|---|---|
| Primary role | Novel production pipeline | Novel production pipeline |
| Turkish quality layer | Limited | Extended (`tdk-polisher`, optional dictionary check, exception governance) |
| Book layout gate | Present | Present + mandatory gate contract in create/polish/rewrite flows |
| Export safety | Basic export flow | Approval gate + validator + DOCX integrity checks |
| Runner/orchestration | Phase-oriented | Phase-oriented + artifact gates + optional dictionary check integration |
| Local preview | Minimal technical page | Word-style preview page (`index.html`) |

Summary: `kit_hub` is not only a content panel. It is an extended production engine with stronger quality controls.

## What This Repository Is
- Contract-driven writing pipeline for long-form projects
- Runtime-compatible plugin structure (`agents/`, `skills/`, `.claude-plugin/`)
- Turkish-first quality model with mandatory TDK and layout gates
- Approval-gated Word export pipeline

## What This Repository Is Not
- Not a classic web application (`npm start` / API server)
- `index.html` is a local utility tool (Word-style preview), not the core runtime engine
- Main orchestration is command-based in IDE/runtime or via runner scripts

## Core Capabilities
| Capability | Description | Main Components |
|---|---|---|
| Multi-Phase Writing | Structured progression from concept to export | propose/design/create/polish/rewrite/export |
| Turkish Language Quality | Spelling, punctuation, grammar particles, dialogue normalization | `tdk-polisher` |
| Book Layout Normalization | Readability-focused paragraph/dialogue page shaping | `tdk-layout-agent` |
| Quality Gating | Contract checks before canonical writeback | `quality-verifier`, `revision-reviewer`, CI scripts |
| Word Export Safety | Explicit user approval and export validation | `export-approval-gate`, `export-validator`, `book-exporter` |
| Local Visual Preview | Book-like page preview before export | `index.html` |

## Long-Form Reliability Model (Three Walls)
Long-form AI fiction commonly fails in three areas. This repository addresses each with explicit controls.

| Wall | Typical Failure | Mitigation in This Repository |
|---|---|---|
| Character Depth Drift | Characters become generic over many episodes | Character constraints from design docs + continuity checks (`continuity-bridge`, `episode-creator`, `revision-reviewer`) |
| Story Coherence Breakdown | Timeline, cause-effect, and foreshadowing drift | `novel-config.md` as source-of-truth + `rule-checker` and `quality-verifier` gates |
| Language/Mechanics Degradation | Punctuation, dialogue flow, readability degrade | `tdk-polisher` + `tdk-layout-agent` + canonical writeback restrictions |

## Turkish Novel Quality Layer (TDK + Layout)
### TDK Polisher Scope
| Rule Group | What Is Checked | Example |
|---|---|---|
| Spelling | Common misspellings and typo cleanup | `yanliz -> yalnız`, `birsey -> bir şey` |
| Turkish Characters | Character restoration where unambiguous | `cok -> çok`, `yagmur -> yağmur` |
| Question Particle | Separate `mi/mı/mu/mü` usage | `geliyormu -> geliyor mu` |
| Conjunctions | `de/da`, `ki` corrections | `dedimki -> dedim ki`, `bende de` |
| Punctuation | Comma/period/quote spacing and consistency | Remove spaces before punctuation |
| Dialogue Readability | Dialogue block clarity and consistency | Separate cramped dialogue lines |
| Paragraph Readability | Split wall-of-text blocks carefully | Keep dramatic short lines intact |

### Layout Agent Scope
| Area | Behavior |
|---|---|
| Book Mode | Enforces page-oriented readability when `book_mode.enabled=true` |
| Paragraph Engine | Breaks overly dense blocks without changing story meaning |
| Dialogue Blocks | Keeps speaker flow legible for reading and export |
| Export Preparation | Stabilizes structure for DOCX output |

### Gate Order (Mandatory)
`create -> tdk-polisher -> tdk-layout-agent -> quality-verifier -> canonical episode`

### TDK Source Assurance Chain
| Layer | Source | Role |
|---|---|---|
| 1 | Official TDK rule set (7 references) | Primary writing and punctuation authority |
| 2 | `tdk-py` dictionary check (optional) | Detect probable misspellings and unknown forms |
| 3 | Project exception list | Prevent false positives on names, voice, and style |
| 4 | Regression fixtures | Keep repeated correctness over time |
| 5 | Human editorial pass | Final publication-grade decision |

Reference documents:
- `skills/polish/references/tdk-official-baseline.md`
- `skills/polish/references/tdk-source-assurance-chain.md`
- `skills/polish/references/tdk-exception-list.md`

## Prerequisites
- Git
- PowerShell 7+ (recommended on Windows)
- IDE/runtime that supports plugin command execution
- Python 3.10+ (recommended for optional dictionary-check layer)

## Installation
1. Clone repository:
   - `git clone https://github.com/Anubis44197/kit_hub.git`
2. Open repository in your IDE/runtime workspace.
3. Ensure plugin metadata is discoverable:
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
4. Restart runtime session to reload agents and skills.
5. Optional bootstrap:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`

## Quick Start
1. `/propose`
2. `/design-big`
3. `/design-small`
4. `/create`
5. `/polish`
6. `/rewrite` (only if needed)
7. `/export-word` (requires explicit user approval)

## Command Reference
| Command | Purpose | Output |
|---|---|---|
| `/propose` | Generate project proposals | Candidate concepts |
| `/design` | Router for design phases | Big/small design selection |
| `/design-big` | Macro architecture | Concept + character + plot framework |
| `/design-small` | Episode-range planning | Scene/continuity/hook maps |
| `/create` | Draft generation | Episode manuscripts |
| `/polish` | Correction + style stabilization | Polished episode artifacts |
| `/rewrite` | Structural revision after design drift | Rewritten canonical content |
| `/export-word` | Approval-gated export | DOCX artifact + validator reports |

## Pipeline Contracts
- `tdk-polisher` is mandatory in create/polish/rewrite episode flows.
- `tdk-layout-agent` is mandatory when `book_mode.enabled=true`.
- `quality-verifier` and revision gates must return PASS before canonical writeback.
- Canonical episode source:
  - `09_tdk-layout_bookmode_EP{NNN}.md` when book mode enabled
  - `08_tdk-polisher_polished_EP{NNN}.md` when book mode disabled

## Language and Content Policy
| Policy | Requirement |
|---|---|
| Story/Chapter Language | Turkish |
| Agent/Skill Contract Language | English |
| Disallowed Scripts in Story Text | Hangul, Han, Hiragana, Katakana |

## Export and Approval Model
| Stage | Result |
|---|---|
| Design freeze approval missing | `create` blocked |
| Rewrite approval missing | `rewrite` blocked |
| Export approval missing (`approval=false`) | Export blocked with `E_EXPORT_APPROVAL` |
| Approval granted (`approval=true`) | Export proceeds through validator/manifests |
| DOCX integrity check | Must pass structural verification (`verify_docx_integrity.ps1`) |

## Local Validation
| Task | Command |
|---|---|
| Final readiness (Windows) | `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1` |
| Final readiness (Linux/macOS) | `bash scripts/ci/final_readiness_check.sh` |
| External IDE smoke test (Windows) | `powershell -ExecutionPolicy Bypass -File scripts/ci/external_smoke_test.ps1 -WorkspaceRoot <repo-path> -TestRunPath test-run` |
| DOCX structural integrity | `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_docx_integrity.ps1 -DocxPath <absolute-path-to-docx>` |
| Optional dictionary verification | `powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot . -Phase polish -RunId RUN-LOCAL` |

## Local Word Preview
1. Start a local server from repository root:
   - `python -m http.server 3000`
2. Open:
   - `http://localhost:3000/`
3. Use cases:
   - Paste manuscript text
   - Preview page rhythm, dialogue blocks, and paragraph density
   - Run visual checks before DOCX export

## Runner Automation
- Initialize runtime config:
  - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
- Run full pipeline:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export`
- Run with optional dictionary check enabled:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase rewrite -EnableDictionaryCheck`
- Runner writes a live pointer file:
  - `runtime/current-run.json`
- Runner requires hard approval files (default):
  - `runtime/approvals/design-freeze.json`
  - `runtime/approvals/rewrite-approval.json`
  - `runtime/approvals/export-approval.json`
- Runner enforces hard phase contracts (default):
  - issue JSON schema
  - verdict markdown token (`PASS|FAIL|BLOCKED`)
  - export manifest existence
- Runner retention policy:
  - Keeps recent run traces under `runtime/runs/` (default `max_runs=20`)
  - Configurable in `runtime/runner-config.json` via `quality_flags.retention`
- Detailed runner guide:
  - `docs/RUNNER_USAGE.md`
  - `docs/WORKSPACE_RETENTION_POLICY.md`

## Agent Architecture
| Metric | Value |
|---|---|
| Base architecture | 18 specialist agents |
| Added project-specific agents/layers | `tdk-polisher`, `tdk-layout-agent`, export approval/validator/exporter set, and related gates |
| Current total | 23 agent definitions |

For complete mapping see `docs/ARCHITECTURE_MAP.md`.

## Repository Structure
```text
.
├── agents/
├── skills/
├── scripts/
├── tests/
├── docs/
├── runtime/
├── .claude-plugin/
└── index.html
```

## Documentation
- Architecture overview: `docs/ARCHITECTURE_MAP.md`
- Runner usage: `docs/RUNNER_USAGE.md`
- Release process: `RELEASE_CHECKLIST.md`
- Release history: `CHANGELOG.md`

## License
Apache-2.0
