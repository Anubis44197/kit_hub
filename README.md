# Novel Writing Engine

Professional multi-agent pipeline for Turkish novel, story, and print-ready book production.

## Overview
This repository provides an agent + skill based writing system for end-to-end book production: idea expansion, full-book design, chapter writing, continuity control, Turkish editorial polish, front matter, cover brief, and DOCX export.

Primary flow:
`/intake -> /propose -> /design-big -> /design-small -> /create -> /polish -> /rewrite -> /export-word`

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
- Publisher-submission and print-preview delivery profiles with DOCX page/style validation

## What This Repository Is Not
- Not a classic web application (`npm start` / API server)
- `index.html` is a local utility tool (Word-style preview), not the core runtime engine
- Main orchestration is command-based in IDE/runtime or via runner scripts
- Not an autonomous writer when no provider/API/IDE agent has been configured

## Core Capabilities
| Capability | Description | Main Components |
|---|---|---|
| Multi-Phase Writing | Structured progression from user brief to export | intake/propose/design/create/polish/rewrite/export |
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
1. Clone the repository:
   - `git clone https://github.com/Anubis44197/kit_hub.git`
   - `cd kit_hub`
2. Run the readiness check:
   - `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1`
3. Open the repository in your IDE/runtime workspace.
4. Ensure plugin metadata is discoverable:
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
5. Restart the runtime session to reload agents and skills.
6. Optional bootstrap:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`

The default readiness check is intentionally fast enough for normal use. Long-form and production sample tests are available separately:
- `powershell -ExecutionPolicy Bypass -File scripts/ci/writing_type_profiles_gate_test.ps1`
- `powershell -ExecutionPolicy Bypass -File scripts/ci/longform_scalability_gate_test.ps1`
- `powershell -ExecutionPolicy Bypass -File scripts/ci/production_sample_export_test.ps1`

## Standard User Flow (Required)
Do not write a book directly in the application repository root. Create one isolated project per book:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kitap Adi"
Set-Location "$env:USERPROFILE\Documents\KitHubProjects\kitap-adi"
```

Then write the real user request into `runtime/book-request.md`, run intake, approve the brief, approve the story direction, approve the book plan, then write/create/polish/export. The app must not silently choose a default topic.

The complete Turkish operating procedure is in:
- `docs/USER_FLOW_TR.md`
- `docs/SMALL_E2E_RUNBOOK_TR.md`

## No API Key / IDE Agent Mode
You do not need to give this repository an API key. If your IDE already has an agent or model connection, run the repository in manual IDE mode.

1. Create an isolated book project:
   - `powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kitap Adi"`
   - `Set-Location "$env:USERPROFILE\Documents\KitHubProjects\kitap-adi"`
2. Create IDE manual config:
   - `Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force`
3. Create `runtime/book-request.md` yourself and write only the user's actual book request into it. The repository does not ship a default topic file.
4. Start the gated pipeline:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase export`
5. After `intake`, answer or accept the questions/options in `runtime/book-brief.json`, `runtime/book-dna.json`, and `runtime/layout-profile.json`; set `runtime/approvals/book-brief-approval.json` to `approved=true` only when the writing brief and page/layout package are acceptable. `approved=true` is not enough by itself: the brief must include accepted answers for writing type, target length/pages, target reader, genre, character policy, style/tone, and publication package.
6. After `propose`, choose one story direction in `runtime/approvals/story-choice.json` by setting `selected_option` and `approved=true`.
7. After `design-big`, review `design/04_book_plan.md`, `design/05_chapter_plan.md`, `design/06_layout_plan.md`, and the matching `revision/_state/book-plan.json`, `revision/_state/open-source-story-model.json`, `revision/_state/chapter-plan.json`, `revision/_state/layout-plan.json`, and `revision/_state/volume-plan.json`; set `runtime/approvals/book-plan-approval.json` to `approved=true` only if the plan, page target, chapter target, continuity model, open-source story model, and layout are acceptable.
7. When the runner pauses, ask your IDE agent to complete the current phase.
8. Optional phase prompt helper:
   - `powershell -ExecutionPolicy Bypass -File scripts/ide_phase_prompt.ps1 -Phase create`
9. Press Enter in the runner terminal after the IDE agent writes the required files.

Manual IDE mode keeps `execution_claim_mode=simulated` because the runner cannot prove what the external IDE did, but artifact gates, text quality gates, TDK/layout gates, longform state checks, and publication-compliance checks still run.

Agent orchestration is contract-bound:
- `runtime/agent-registry.json` lists every allowed agent, phase, reference, and write boundary.
- `runtime/agent-status-contract.json` defines allowed agent statuses.
- `runtime/phase-contracts/*.json` defines mandatory agents, state files, approvals, allowed outputs, and denied outputs.
- `runtime/runs/{run_id}/run-journal.jsonl` records phase audit events.
- `revision/_state/open-source-story-model.json` binds Manuskript, novelWriter, bibisco, and STORM-inspired planning patterns into the current book's outline, character, plot, world, cross-reference, research, and export rules.

Each phase must also write an agent compliance manifest:
- `runtime/agent-compliance/{phase}.json`

The runner fails the phase if a required agent is missing from that manifest, if a required `agent_statuses` entry is not `completed`, if `contract_status` is not `PASS`, or if `missing_items` is not empty.
The manifest and phase evidence also carry `contract_hashes`; stale compliance files fail after any agent registry, status contract, or phase contract change.

Detailed guide:
- `docs/IDE_AGENT_WORKFLOW.md`

## Automatic Provider Mode
For a fully automatic writing run, connect a real model/agent CLI and use the provider config. This mode is fail-closed: if no provider is configured, it stops instead of pretending that writer agents ran.

1. Create a project with `scripts/new_project.ps1`.
2. Copy provider config:
   - `Copy-Item runtime/runner-config.provider.template.json runtime/runner-config.json -Force`
3. Set the provider executable:
   - `$env:KITHUB_PROVIDER_EXE="your-agent-cli"`
4. Optionally set provider arguments:
   - `$env:KITHUB_PROVIDER_ARGS="--project-root ""{project_root}"" --phase {phase} --run-id ""{run_id}"" --prompt-file ""{prompt_file}"""`
5. Run the pipeline:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.json -FromPhase intake -ToPhase export`

The provider must write the exact artifacts required by `runtime/phase-contracts/{phase}.json`, including `runtime/agent-compliance/{phase}.json`. The runner then verifies approvals, agent sequence, agent evidence, state updates, length fulfillment, Turkish text quality, layout, and export integrity.

## Quick Start
1. `scripts/new_project.ps1` creates a clean book project outside the app repository.
2. `runtime/book-request.md` receives only the real user prompt.
3. `/intake` asks/locks book brief, writing type, page/layout, front matter, cover package.
4. `/propose` offers story/book directions and waits for user selection.
5. `/design-big` and `/design-small` produce the book, chapter, continuity, and layout plans.
6. `/create` writes only after approved plan/design freeze.
7. `/polish` and `/rewrite` run editorial, continuity, TDK, layout, and quality gates.
8. `/export-word` requires explicit user approval.
9. `scripts/export_final.ps1` copies final DOCX outside the project, such as Desktop.
10. `scripts/cleanup_project.ps1` runs only after explicit cleanup approval.

## Command Reference
| Command | Purpose | Output |
|---|---|---|
| `/run` | Launch full pipeline with hard gates | Runner summary + evidence |
| `/intake` | Ask and lock the pre-writing brief | `book-brief`, `book-dna`, `layout-profile`, approval gate |
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

## Pre-Writing Brief Gate
Writing must not start from a vague prompt. `intake` creates:
- `runtime/book-brief.json`
- `runtime/book-dna.json`
- `runtime/layout-profile.json`
- `runtime/approvals/book-brief-approval.json`

The user must approve the brief before `propose` can continue. This locks writing type, genre/category, target reader, target pages/chapters/words, character policy, setting, point of view, style, source requirements, front matter, cover package, and print layout.

The runner rejects a fake brief approval. The brief must contain structured `required_user_questions`, filled `answers`, and approval requirements. If the user has not specified length, the intake answer must explicitly say the system may choose or suggest the length; otherwise planning is blocked.

## Export and Approval Model
| Stage | Result |
|---|---|
| Book brief approval missing | `propose` blocked |
| Story choice approval missing | `design-big` blocked |
| Book plan approval missing | `design-small` blocked |
| Design freeze approval missing | `create` blocked |
| Rewrite approval missing | `rewrite` blocked |
| Export approval missing (`approval=false`) | Export blocked with `E_EXPORT_APPROVAL` |
| Approval granted (`approval=true`) | Export proceeds through validator/manifests |
| DOCX integrity check | Must pass structural verification (`verify_docx_integrity.ps1`) |
| DOCX layout/profile check | Must pass style and page setup verification (`verify_docx_layout_profile.ps1`) |
| DOCX content match check | Exported DOCX text must contain snippets from current `episode/ep*.md` files; stale copied DOCX files are blocked |

## Local Validation
| Task | Command |
|---|---|
| Final readiness (Windows) | `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1` |
| Final readiness (Linux/macOS) | `bash scripts/ci/final_readiness_check.sh` |
| External IDE smoke test (Windows) | `powershell -ExecutionPolicy Bypass -File scripts/ci/external_smoke_test.ps1 -WorkspaceRoot <repo-path> -TestRunPath test-run` |
| DOCX structural integrity | `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_docx_integrity.ps1 -DocxPath <absolute-path-to-docx>` |
| Optional dictionary verification | `powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot . -Phase polish -RunId RUN-LOCAL` |
| Length fulfillment gate | `powershell -ExecutionPolicy Bypass -File scripts/ci/length_fulfillment_gate_test.ps1` |

## KitHub Studio UI
- Open the static studio preview directly when you only need layout/editing preview:
  - `index.html`
- Start the local Studio Bridge when the UI should call the real pipeline:
  - `powershell -ExecutionPolicy Bypass -File scripts/start_studio.ps1`
- The bridge listens on `http://127.0.0.1:8765/` and exposes only local health and pipeline endpoints.
- In the Studio UI:
  - use `Yeni Proje` to create a separate KitHub project through `scripts/new_project.ps1`,
  - enter an absolute project path and use `Projeyi Bağla` to read it through the bridge,
  - if the bridge is not running, `Projeyi Bağla` falls back to the browser folder picker when supported,
  - write the initial book prompt in `Kitap isteği` and use `İsteği Kaydet` to create/update `runtime/book-request.md`,
  - enter the absolute project path before running `Dışa Aktar`,
  - use the `Plan` tab to review `design/*.md` before approving the book plan,
  - use the `Revizyon` tab to review recent `revision/_workspace` reports,
  - choose the `fromPhase` / `toPhase` range before running the pipeline,
  - use the `Onaylar` panel to write explicit approval files under `runtime/approvals`,
  - use `Bölümü Kaydet` to write the currently opened `episode/ep*.md`,
  - use `Yenile` after pipeline runs to reload chapters, exports, approvals, and agent evidence,
  - use `Dışa Aktar` to run `scripts/run_pipeline.ps1` through the local bridge.
  - review `Çalıştırma Günlüğü` for the real pipeline output or bridge errors.
- If the bridge is not running, `Dışa Aktar` copies the equivalent PowerShell command to the clipboard instead of pretending it ran.

## Local Preview Policy
- `scripts/start_app.ps1` only runs runtime bootstrap + readiness checks.
- `scripts/start_studio.ps1` starts the optional local UI bridge for user-driven Studio runs.
- Production flow remains pipeline-first (`/run`, Studio Bridge, or `scripts/run_pipeline.ps1`).

## Runner Automation
- Initialize runtime config:
  - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
- Run full pipeline in IDE manual mode:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase export`
- One-time bootstrap + run:
  - `/run`
- Run with optional dictionary check enabled:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase rewrite -EnableDictionaryCheck`
- Runner writes a live pointer file:
  - `runtime/current-run.json`
- Runner requires hard approval files (default):
  - `runtime/approvals/book-brief-approval.json`
  - `runtime/approvals/story-choice.json`
  - `runtime/approvals/book-plan-approval.json`
  - `runtime/approvals/design-freeze.json`
  - `runtime/approvals/rewrite-approval.json`
  - `runtime/approvals/export-approval.json`
- `story-choice.json` must include both `approved=true` and a `selected_option` before `design-big` can continue. This prevents the app from silently choosing a plot direction after a simple topic prompt.
- `book-plan-approval.json` must be approved before `design-small`; this prevents an IDE or LLM from writing chapters before the user has accepted the book plan, open-source story model, chapter plan, and page/layout targets.
- Runner enforces hard phase contracts (default):
  - issue JSON schema
  - verdict markdown token (`PASS|FAIL|BLOCKED`)
  - export manifest existence
  - DOCX content must match current manuscript source files
- Runner enforces agent compliance manifests:
  - `runtime/agent-compliance/{phase}.json`
  - required agents must be listed, marked executed, and have `agent_statuses.status=completed`
  - `artifact_hashes` and `contract_hashes` must match current files
  - missing items fail the phase
- Runner enforces command and evidence guardrails:
  - configured phase commands are scanned for destructive commands, nested expression execution, remote-download-to-shell patterns, and project-external absolute paths
  - oversized text/JSON/Markdown evidence artifacts are blocked so agents cannot hide unreviewable bulk output in logs
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
|-- agents/
|-- skills/
|-- scripts/
|-- tests/
|-- docs/
|-- runtime/
|-- .claude-plugin/
`-- index.html
```

## Documentation
- Architecture overview: `docs/ARCHITECTURE_MAP.md`
- Turkish user flow: `docs/USER_FLOW_TR.md`
- Small E2E runbook: `docs/SMALL_E2E_RUNBOOK_TR.md`
- Runner usage: `docs/RUNNER_USAGE.md`
- Release process: `RELEASE_CHECKLIST.md`
- Release history: `CHANGELOG.md`

## License
Apache-2.0
