# Novel Writing Engine

Professional multi-agent pipeline for Turkish long-form fiction production.

## What This Repository Is
- A plugin-style agent/skill system for IDE-based LLM workflows
- A structured pipeline for proposal, design, creation, polishing, rewriting, and Word export
- A contract-driven architecture with CI checks and reproducible validation scripts

## What This Repository Is Not
- Not a typical web app with `npm start` or `python app.py`
- `index.html` is a local technical utility page, not the agent runtime engine
- Main execution happens through agent commands and runner scripts

## Core Capabilities
- Multi-phase writing workflow: `propose -> design -> create -> polish -> rewrite -> export`
- Turkish language quality gates via `tdk-polisher`
- Book layout normalization via `tdk-layout-agent`
- Approval-gated DOCX export with structural validation
- Local Word-style preview page (`index.html`) for quick visual checks before export

## Prerequisites
- Git
- PowerShell 7+ (recommended on Windows)
- An IDE/runtime that supports plugin-style command execution (agents + skills)

## Installation
1. Clone the repository:
   - `git clone https://github.com/Anubis44197/kit_hub.git`
2. Open the repository in your IDE/runtime workspace.
3. Ensure plugin metadata is visible to the runtime:
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
4. Restart the runtime session to reload agents and skills.
5. Optional bootstrap:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`

## Quick Start
1. `/propose`
2. `/design-big`
3. `/design-small`
4. `/create`
5. `/polish`
6. `/rewrite` (only when needed)
7. `/export-word` (requires explicit user approval)

## Command Reference
- `/propose`: generate proposal candidates
- `/design`: route to big/small design flows
- `/design-big`: macro architecture (concept, characters, plot hooks)
- `/design-small`: episode-range detailed planning
- `/create`: draft episode generation
- `/polish`: quality correction loop
- `/rewrite`: structural revision after design drift
- `/export-word`: gated DOCX export

## Pipeline Contracts
- `tdk-polisher` is mandatory in create/polish/rewrite episode flows
- `tdk-layout-agent` is mandatory when `book_mode.enabled=true`
- `quality-verifier` (and revision gates) must return PASS before canonical writeback
- Canonical episode source:
  - `09_tdk-layout_bookmode_EP{NNN}.md` when book mode is enabled
  - `08_tdk-polisher_polished_EP{NNN}.md` when book mode is disabled

## Language and Content Policy
- Story/chapter content language: Turkish
- Agent and skill contract language: English
- Disallowed scripts in story outputs: Hangul, Han, Hiragana, Katakana

## Local Validation
- Windows:
  - `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1`
- Linux/macOS:
  - `bash scripts/ci/final_readiness_check.sh`
- External IDE smoke (Windows):
  - `powershell -ExecutionPolicy Bypass -File scripts/ci/external_smoke_test.ps1 -WorkspaceRoot <repo-path> -TestRunPath test-run`
- DOCX integrity:
  - `powershell -ExecutionPolicy Bypass -File scripts/ci/verify_docx_integrity.ps1 -DocxPath <absolute-path-to-docx>`

## Local Word Preview
- Start a simple local server from repository root:
  - `python -m http.server 3000`
- Open:
  - `http://localhost:3000/`
- Purpose:
  - Paste manuscript text and preview Word/book-like page layout before DOCX export

## Runner Automation
- Initialize runtime config:
  - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
- Run full pipeline:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export`
- Detailed runner guide:
  - `docs/RUNNER_USAGE.md`

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
