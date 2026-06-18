# Novel Writing Engine

Professional multi-agent pipeline for Turkish novel, story, and print-ready book production.

## Overview
This repository provides an agent + skill based writing system for end-to-end book production: idea expansion, full-book design, chapter writing, continuity control, Turkish editorial polish, front matter, cover brief, and DOCX export.

Primary flow:
`/propose -> /design-big -> /design-small -> /create -> /polish -> /rewrite -> /export-word`

Reader-facing output is chapter/book based. Legacy internal paths may still use `episode/epNNN.md` for compatibility.

## Generation Responsibility
`kit_hub` is a book-production orchestrator, not a hidden standalone brain. Creative text is produced by one of these explicitly configured sources:

- an IDE agent or human writer in manual mode
- a provider/API/CLI command in command mode
- the deterministic local adapter for smoke testing only

The repository validates, tracks, structures, and exports the result. It should not claim that autonomous agents wrote a book unless a real provider-backed command/API executed those phases. It should not claim internet research occurred unless source artifacts were produced.

## Repository Positioning (Upstream vs This Repository)
This project is based on the upstream architecture (`MJbae/awesome-novel-studio`) and extended for stricter Turkish publication workflow.

| Criteria | Upstream (`awesome-novel-studio`) | This Repo (`kit_hub`) |
|---|---|---|
| Primary role | Novel production pipeline | Complete Turkish book production pipeline |
| Turkish quality layer | Limited | Extended (`tdk-polisher`, optional dictionary check, exception governance) |
| Book layout gate | Present | Present + mandatory gate contract in create/polish/rewrite flows |
| Export safety | Basic export flow | Approval gate + validator + DOCX integrity checks |
| Runner/orchestration | Phase-oriented | Phase-oriented + artifact gates + optional dictionary check integration |
| Local preview | Minimal technical page | Turkish reading preview page (`index.html`) |

Summary: `kit_hub` is not only a content panel. It is an extended production engine with stronger quality controls.

## What This Repository Is
- Contract-driven writing pipeline for long-form book projects
- Runtime-compatible plugin structure (`agents/`, `skills/`, `.claude-plugin/`)
- Turkish-first quality model with mandatory TDK and layout gates
- Approval-gated Word export pipeline with front matter and cover brief requirements

## What This Repository Is Not
- Not a classic web application (`npm start` / API server)
- `index.html` is a local utility tool (Word-style preview), not the core runtime engine
- Main orchestration is command-based in IDE/runtime or via runner scripts
- Not an autonomous writer when no provider/API/IDE agent has been configured

## Core Capabilities
| Capability | Description | Main Components |
|---|---|---|
| Multi-Phase Writing | Structured progression from concept to export | propose/design/create/polish/rewrite/export |
| Turkish Language Quality | Spelling, punctuation, grammar particles, dialogue normalization | `tdk-polisher` |
| Book Layout Normalization | Readability-focused paragraph/dialogue page shaping | `tdk-layout-agent` |
| Quality Gating | Contract checks before canonical writeback | `quality-verifier`, `revision-reviewer`, CI scripts |
| Book Package Export | Explicit approval, front matter, cover brief, DOCX validation | `export-approval-gate`, `front-matter-editor`, `cover-designer`, `export-validator`, `book-exporter` |
| Local Visual Preview | Book-like page preview before export | `index.html` |

## Long-Form Reliability Model (Three Walls)
Long-form AI fiction commonly fails in four areas. This repository addresses each with explicit controls.

| Wall | Typical Failure | Mitigation in This Repository |
|---|---|---|
| Character Depth Drift | Characters become generic over many episodes | Character constraints from design docs + continuity checks (`continuity-bridge`, `episode-creator`, `revision-reviewer`) |
| Story Coherence Breakdown | Timeline, cause-effect, and foreshadowing drift | `novel-config.md` as source-of-truth + `rule-checker` and `quality-verifier` gates |
| Language/Mechanics Degradation | Punctuation, dialogue flow, readability degrade | `tdk-polisher` + `tdk-layout-agent` + canonical writeback restrictions |
| Book Package Incompleteness | Missing preface, TOC, cover copy, or print blockers | `front-matter-editor`, `cover-designer`, export manifest gates |

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

## No API Key / IDE Agent Mode
You do not need to give this repository an API key. If your IDE already has an agent or model connection, run the repository in manual IDE mode.

1. Bootstrap:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
2. Create IDE manual config:
   - `Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force`
3. Write your book request:
   - `runtime/book-request.md`
4. Start the gated pipeline:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase export`
5. After `propose`, choose one story direction in `runtime/approvals/story-choice.json` by setting `selected_option` and `approved=true`.
6. When the runner pauses, ask your IDE agent to complete the current phase.
7. Optional phase prompt helper:
   - `powershell -ExecutionPolicy Bypass -File scripts/ide_phase_prompt.ps1 -Phase create`
8. Press Enter in the runner terminal after the IDE agent writes the required files.

Manual IDE mode keeps `execution_claim_mode=simulated` because the runner cannot prove what the external IDE did, but artifact gates, text quality gates, TDK/layout gates, longform state checks, and publication-compliance checks still run.

Each phase must also write an agent compliance manifest:
- `runtime/agent-compliance/{phase}.json`

The runner fails the phase if a required agent is missing from that manifest, if `contract_status` is not `PASS`, or if `missing_items` is not empty.

Detailed guide:
- `docs/IDE_AGENT_WORKFLOW.md`

## Quick Start
1. `/run` (single-command full pipeline)
2. `/propose` (if you want phase-by-phase control)
3. `/design-big`
4. `/design-small`
5. `/create`
6. `/polish`
7. `/rewrite` (only if needed)
8. `/export-word` (requires explicit user approval)

## Command Reference
| Command | Purpose | Output |
|---|---|---|
| `/run` | Launch full pipeline with hard gates | Runner summary + evidence |
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
| Encoding / Script Safety | Valid UTF-8 Turkish; mojibake and unexplained non-Turkish script usage block print-ready export |

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

## Local Preview Policy
- Automatic localhost preview is disabled.
- `scripts/start_app.ps1` only runs runtime bootstrap + readiness checks.
- Production flow is pipeline-first (`/run` or `scripts/run_pipeline.ps1`).

## Runner Automation
- Initialize runtime config:
  - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
- Run full pipeline:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export`
- One-time bootstrap + run:
  - `/run`
- Run with optional dictionary check enabled:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase rewrite -EnableDictionaryCheck`
- Runner writes a live pointer file:
  - `runtime/current-run.json`
- Runner requires hard approval files (default):
  - `runtime/approvals/story-choice.json`
  - `runtime/approvals/design-freeze.json`
  - `runtime/approvals/rewrite-approval.json`
  - `runtime/approvals/export-approval.json`
- `story-choice.json` must include both `approved=true` and a `selected_option` before `design-big` can continue. This prevents the app from silently choosing a plot direction after a simple topic prompt.
- Runner enforces hard phase contracts (default):
  - issue JSON schema
  - verdict markdown token (`PASS|FAIL|BLOCKED`)
  - export manifest existence
- Runner enforces agent compliance manifests:
  - `runtime/agent-compliance/{phase}.json`
  - required agents must be listed and marked executed
  - missing items fail the phase
- Runner enforces hard text quality gates (default):
  - min/max character limits
  - mojibake detection
  - duplicate-line ratio limit
  - dialogue style consistency
  - psychological marker minimum for psychological genres
- Runner can block critical phases unless `execution_claim_mode=executed`:
  - set `quality_flags.require_executed_claims_for_critical_phases=true` after command-mode phase commands are configured
  - use `verify_real_run.ps1` when you need proof that create/polish/rewrite/export were command-executed
- Real-run proof check (no simulated/fake completion):
  - `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_real_run.ps1 -ProjectRoot .`
- Runner retention policy:
  - Keeps recent run traces under `runtime/runs/` (default `max_runs=20`)
  - Configurable in `runtime/runner-config.json` via `quality_flags.retention`
- Detailed runner guide:
  - `docs/RUNNER_USAGE.md`
  - `docs/IDE_AGENT_WORKFLOW.md`
  - `docs/WORKSPACE_RETENTION_POLICY.md`

## Agent Architecture
| Metric | Value |
|---|---|
| Base architecture | 18 specialist agents |
| Added project-specific agents/layers | `tdk-polisher`, `tdk-layout-agent`, export approval/validator/exporter set, and related gates |
| Current total | 32 agent definitions |

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
