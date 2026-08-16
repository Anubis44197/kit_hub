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

## Studio API Mode
Use API mode when the user wants the application itself to drive writing phases through a model provider.

1. Start Studio:
   - `powershell -ExecutionPolicy Bypass -File scripts/start_app.ps1 -ProjectRoot .`
2. Open settings with the gear button.
3. Choose `API Modu`.
4. Select provider, model, and enter the API key.
5. Press `Kaydet` or `Test Et`.
6. Create or bind a KitHub project.
7. Fill the starting brief and save it.
8. Use the pipeline controls to run phases from intake/design through create/polish/export.

In API mode, `scripts/studio_bridge.ps1` loads the saved provider settings and runs `scripts/provider_phase.ps1` through `runtime/runner-config.provider.template.json`. If provider settings or the API key are missing, the pipeline fails closed before claiming that agents ran.

In IDE mode, the IDE agent writes the requested files while KitHub validates the artifacts, approvals, agent evidence, continuity, Turkish quality, layout, and DOCX export. IDE/manual evidence is intentionally labeled `execution_claim_mode=simulated`: it proves persisted artifacts and contracts, not that a live external agent process is still running. API/provider mode uses executed command evidence when configured.

## KitHub Studio: New User Flow
KitHub Studio is the recommended interface for normal use. The backend still runs through PowerShell scripts, but the user should work from the Studio screen instead of editing runtime files by hand.

### 1. Install and open
```powershell
git clone https://github.com/Anubis44197/kit_hub.git
cd kit_hub
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
powershell -ExecutionPolicy Bypass -File scripts/install_epubcheck.ps1
powershell -ExecutionPolicy Bypass -File scripts/start_studio.ps1
```

If the browser does not open automatically, open the local Studio URL printed by the script. `studio_bridge.ps1` must stay open while Studio is used for project creation, API mode, DOCX import, saving chapters, layout saving, and export.

### 2. Create or bind a book project
Use one of these buttons in Studio:

- `Yeni Proje`: creates a clean KitHub project folder.
- `Projeyi Bağla`: connects an existing KitHub project.

Book projects should live outside the application engine when possible, for example under:

```text
Documents/KitHubProjects/<BookName>
```

The application repository is the engine. The book project folder is the manuscript workspace.

### 3. Enter the user's book request
The user writes the subject, genre, target page count, characters, setting, style, ending expectations, and boundaries in the Studio brief area. Then:

1. Fill the starting wizard fields.
2. Press `İsteği Oluştur`.
3. Press `Kaydet`.
4. Press `Romanı Planla`.
5. Review and approve the plan.
6. Press `Planı Onayla ve Yazdır`.

The system must plan before writing. It should not start from an old sample, leftover test project, or hard-coded default topic.

If you import an existing TXT/MD/DOCX manuscript, the source is kept as manuscript context and added to the book request. It does not invent missing brief answers. Fill the required wizard fields (`Tür`, `Hedef sayfa`, `Hedef okur`, `Konu`, `Karakterler / karakter politikası`, `Dönem ve mekân`, `Anlatıcı`, `Final`, `Sınırlar`) before pressing `İsteği Kaydet`; Studio adds the selected/default `Üslup` and the standard `Yayın paketi`, focuses the first missing field, and blocks writing until the structured brief is complete.

### 4. Choose IDE Mode or API Mode
Studio supports two production modes.

| Mode | Use When | How It Works |
|---|---|---|
| `IDE Modu` | The user has an IDE assistant such as Codex/Claude/Cursor but no direct API key in KitHub | Studio saves the brief and phase state. The IDE agent writes the required artifacts. KitHub validates agent evidence, continuity, Turkish quality, layout, approvals, and export. |
| `API Modu` | The user wants KitHub to call a model provider directly | Open settings, choose provider/model, enter API key, save/test, then run the pipeline from Studio. Missing provider settings fail closed. |

API keys are stored through Studio provider settings. They must not be committed into the repository.

### 5. Edit, review, and revise
Studio includes:

- delayed autosave with a visible dirty/saving state, local crash-recovery drafts, atomic episode writes, and an unload guard
- `Ctrl+S`, `Ctrl+F`, and `Ctrl+H` editor shortcuts with chapter/book search and replace
- a chapter manager for create, rename, duplicate, keyboard/drag reorder, and recoverable delete
- page-like manuscript preview
- DOCX import for existing Word manuscripts
- live edit panel
- page notes
- version history and restore
- type-specific quality checks
- long-text chapter splitting for large manuscripts
- advanced layout controls

After connecting a project, open `Profesyonel Araçlar` in the publication controls. Its four sections provide:

- real character, location, plot-thread, and research CRUD backed by project state files
- chapter-linked comment threads and tracked-change proposals with accept/reject actions
- author/editor/reviewer/admin role records and a project team list
- daily/project word goals, deadlines, and timed focus sessions
- publication profile, ISBN-13, imprint, language, and PNG/JPEG cover-source management

Design Markdown files shown under research are intentionally read-only; editable research records are stored separately. Professional state is saved atomically in `revision/_state/studio-professional.json`.

Live edit suggestions are not applied automatically. The user must approve or save changes.

### 6. Layout and print preparation
The layout panel writes the selected book package to:

- `revision/_state/layout-plan.json`
- `runtime/layout-profile.json`

Supported layout controls include page size, print mode, front matter, font, point size, line spacing, margins, paragraph indentation, chapter start policy, heading hierarchy, running headers, page number position, table-of-contents depth, and widow/orphan control.

Use `Ön/Arka Sayfaları Otomatik Doldur` in `Profesyonel Araçlar > Yayın Kimliği` to seed copyright and author pages, then review the generated text. KDP, IngramSpark, and custom-print profiles apply profile-specific bleed and validation rules. A valid ISBN-13 can be rendered as an EAN-13 barcode. Uploaded cover art is checked from its real pixel dimensions and blocks readiness below 300 effective DPI; spine text is suppressed below 79 pages.

### 7. Export
When the manuscript and approvals are ready, use Studio export controls. `Export Fazını Çalıştır` builds and validates the approved DOCX package; the publication controls can additionally build print PDF, full-wrap cover PDF, and EPUB. `Final DOCX'i Masaüstüne Kopyala` copies the approved final DOCX to the selected destination. Export must pass:

- export approval
- reader-facing cleanliness checks
- DOCX integrity validation
- DOCX layout/profile validation
- DOCX content match validation
- embedded-font and publication-profile checks for print PDF
- official EPUBCheck validation when EPUB is requested
- ISBN/EAN-13, bleed, cover completeness, and cover-DPI checks

The final output can be copied to the Desktop or another selected output folder. `READY` means file-level checks passed; a physical proof and the distributor upload preview are still required. IngramSpark keeps `PDF/X + CMYK` as an explicit external review until a compliant conversion tool is configured.

### 8. Normal local files
Studio may create runtime log files while it is open:

```text
studio-stdout.log
studio-stderr.log
```

These logs are local troubleshooting files and should not be pushed as manuscript or product files.

## Repository Positioning (Upstream vs This Repository)
This project is based on the upstream architecture (`MJbae/awesome-novel-studio`) and extended for stricter Turkish publication workflow.

| Criteria | Upstream (`awesome-novel-studio`) | This Repo (`kit_hub`) |
|---|---|---|
| Primary role | Novel production pipeline | Complete Turkish book production pipeline |
| Turkish quality layer | Limited | Extended (`tdk-polisher`, default dictionary check, exception governance) |
| Book layout gate | Present | Present + mandatory gate contract in create/polish/rewrite flows |
| Export safety | Basic export flow | Approval gate + validator + DOCX integrity checks |
| Runner/orchestration | Phase-oriented | Phase-oriented + artifact gates + default dictionary check integration |
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
| Chapter Target Control | Per-chapter target/min/max word gates and retry tracking | `revision/_state/create-plan.json` |
| Design Drift Control | Approved design hash baseline and rewrite impact scope | `revision/_state/design-hashes.json`, `rewrite-impact-report.json` |
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
| 2 | `tdk-py` dictionary check | Runs by default; manual mode reports `skipped` when the provider is unavailable, while provider/API mode can fail closed |
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
- Python 3.10+ (used by the dictionary-check layer when the provider is available)

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
3. Create `runtime/book-request.md` yourself and write only the user's actual book request into it. The repository does not ship a default topic file.
4. Start the gated pipeline:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase export`
5. After `intake`, answer or accept the questions/options in `runtime/book-brief.json`, `runtime/book-dna.json`, and `runtime/layout-profile.json`; set `runtime/approvals/book-brief-approval.json` to `approved=true` only when the writing brief and page/layout package are acceptable. `approved=true` is not enough by itself: the brief must include accepted answers for writing type, target length/pages, target reader, genre, character policy, style/tone, and publication package.
6. After `propose`, choose one story direction in `runtime/approvals/story-choice.json` by setting `selected_option` and `approved=true`.
7. After `design-big`, review `design/04_book_plan.md`, `design/05_chapter_plan.md`, `design/06_layout_plan.md`, and the matching `revision/_state/book-plan.json`, `revision/_state/chapter-plan.json`, `revision/_state/layout-plan.json`, and `revision/_state/volume-plan.json`; set `runtime/approvals/book-plan-approval.json` to `approved=true` only if the plan, page target, chapter target, continuity model, and layout are acceptable.
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

Each phase must also write an agent compliance manifest:
- `runtime/agent-compliance/{phase}.json`

The runner fails the phase if a required agent is missing from that manifest, if a required `agent_statuses` entry is not `completed`, if `contract_status` is not `PASS`, or if `missing_items` is not empty.
The manifest and phase evidence also carry `contract_hashes`; stale compliance files fail after any agent registry, status contract, or phase contract change.

Detailed guide:
- `docs/IDE_AGENT_WORKFLOW.md`

## Quick Start
1. `/run` (single-command full pipeline)
2. `/intake` (ask/lock book brief, writing type, page/layout, front matter, cover package)
3. `/propose` (if you want phase-by-phase control)
4. `/design-big`
5. `/design-small`
6. `/create`
7. `/polish`
8. `/rewrite` (only if needed)
9. `/export-word` (requires explicit user approval)

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
- `create-plan.json` is mandatory after design-big; every generated chapter must stay within its target word range.
- `design-hashes.json` locks the approved plan. If design files change after approval, create/polish/export stop until rewrite produces `revision/_workspace/rewrite-impact-report.json`.
- `chief-editor-orchestrator` does not write manuscript text; it verifies handoffs, approvals, retry decisions, and agent-chain completeness.
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
| Agent Skills compatibility | `powershell -ExecutionPolicy Bypass -File scripts/ci/validate_skill_standard.ps1` |
| Skill catalog generation | `powershell -ExecutionPolicy Bypass -File scripts/ci/generate_skill_catalog.ps1 -Format json` |
| Skill eval contracts | `powershell -ExecutionPolicy Bypass -File scripts/ci/validate_skill_evals.ps1` |
| External IDE smoke test (Windows) | `powershell -ExecutionPolicy Bypass -File scripts/ci/external_smoke_test.ps1 -WorkspaceRoot <repo-path> -TestRunPath test-run` |
| DOCX structural integrity | `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_docx_integrity.ps1 -DocxPath <absolute-path-to-docx>` |
| Dictionary verification | `powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot . -Phase polish -RunId RUN-LOCAL` (a skipped/provider-unavailable result fails closed) |
| 36-agent fixture validation | `powershell -ExecutionPolicy Bypass -File scripts/ci/fixture_agent_runner.ps1` (reports `fixture_validation`, not autonomous provider execution) |
| Existing-project config migration | `powershell -ExecutionPolicy Bypass -File scripts/ci/migrate_project.ps1 -ProjectRoot <project-path>` |
| State consistency validation | `powershell -ExecutionPolicy Bypass -File scripts/ci/validate_state_consistency.ps1 -ProjectRoot <project-path>` |
| Run integrity validation | `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_run_integrity.ps1 -ProjectRoot <project-path>` |
| Real local provider fixture execution | `powershell -ExecutionPolicy Bypass -File scripts/ci/provider_agent_runner.ps1 -Provider ollama -Model qwen2.5:3b` (optional local-only 36-agent test; this does not configure Studio to use Ollama, and external providers require explicit data-transfer approval) |
| Browser DOM + interaction E2E | `powershell -ExecutionPolicy Bypass -File scripts/ci/browser_e2e_test.ps1` (editor dirty/recovery shortcuts, chapter-manager and professional-tool dialogs, desktop and 390x844 mobile computed audits, contrast, overflow, and reduced-motion checks; manual WCAG testing still required) |
| Studio security + final export E2E | `powershell -ExecutionPolicy Bypass -File scripts/ci/studio_bridge_security_export_test.ps1` (origin allowlist, session-header preflight, endpoint/key fail-closed behavior, selected output directory, and collision-safe DOCX copy) |
| Studio chapter manager + atomic save E2E | `powershell -ExecutionPolicy Bypass -File scripts/ci/studio_bridge_chapter_manager_test.ps1` (professional state, atomic cover upload/replace, entity CRUD, autosave cleanup, chapter create/rename/duplicate/order, and recoverable delete) |
| Print/EPUB publication E2E | `powershell -ExecutionPolicy Bypass -File scripts/ci/publication_typesetting_test.ps1` (A5 pagination, front/back matter, full-wrap cover, 79-page spine rule, EAN-13, embedded fonts, and official EPUBCheck) |

## Local Preview Policy
- Studio is the local preview and control surface.
- Use `scripts/start_studio.ps1` for the interactive UI.
- Use `scripts/start_app.ps1` for compatibility/bootstrap flows.
- Production can be driven from Studio or directly through `scripts/run_pipeline.ps1`.

## Runner Automation
- Initialize runtime config:
  - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
- Run full pipeline in IDE manual mode:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase export`
- One-time bootstrap + run:
  - `/run`
- Run with the dictionary check explicitly enabled:
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
- `book-plan-approval.json` must be approved before `design-small`; this prevents an IDE or LLM from writing chapters before the user has accepted the book plan, chapter plan, and page/layout targets.
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
| Registry-governed agents | 36 (canonical source: `runtime/agent-registry.json`) |
| Added project-specific agents/layers | `tdk-polisher`, `tdk-layout-agent`, `layout-profile-planner`, `research-citation-auditor`, export approval/validator/exporter set, front-matter/cover/publication gates, and `final-proofreader` |
| Golden agent fixtures | 36 (one `input.md`/`expected.md` pair per registered agent under `tests/golden/agents/`) |

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
- `book-brief-approval.json` must be approved before `propose`; this prevents the app from silently deciding writing type, target length, characters, front matter, cover, or page layout.
