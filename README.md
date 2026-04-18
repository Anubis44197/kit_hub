# Novel Writing Engine

This repository contains a multi-agent writing pipeline for long-form Turkish novel/book production.

## Installation
1. Copy this repository into your local plugin workspace.
2. Ensure `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are discoverable by your runtime.
3. Restart the runtime session so updated skills/agents are reloaded.

## Quick Start
1. Run `/propose` to generate project-level concept options.
2. Run `/design-big` for bootstrap, character core, and plot-hook macro architecture.
3. Run `/design-small` for 25-episode range detail.
4. Run `/create` for draft episodes.
5. Run `/polish` for correction loops.
6. Run `/rewrite` only when design drift or quality failure requires structural rewrite.
7. Run `/export-word` for DOCX output after explicit approval.

## Pipeline
1. `/propose`
2. `/design-big`
3. `/design-small`
4. `/create`
5. `tdk-polisher` (mandatory in create/polish/rewrite episode flows)
6. `tdk-layout-agent` (mandatory when `book_mode.enabled=true`)
7. `quality-verifier` / `revision-reviewer` gate
8. `/polish`
9. `/rewrite`
10. `/export-word`

## Commands
- `/propose`: candidate proposals + project direction selection
- `/design`: router for `design-big` and `design-small`
- `/design-big`: macro story architecture
- `/design-small`: episode-range detail architecture
- `/create`: episode generation with mandatory TDK/layout pass
- `/polish`: diagnostics + correction + review
- `/rewrite`: structural rewrite flow
- `/export-word`: approval-gated DOCX export

## Local Validation
- Linux/macOS: `bash scripts/ci/final_readiness_check.sh`
- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1`

## Workflow Notes
- `novel-config.md` is the central source of truth.
- Episode-range mappings determine active design documents per episode.
- TDK and layout artifacts are mandatory gates before final acceptance.
- Content language policy: story/chapter text is Turkish.
- Tooling/design policy: skill and agent contracts are English.
- Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana.
- Canonical episode writeback must come from:
  - `09_tdk-layout_bookmode_EP{NNN}.md` when `book_mode.enabled=true`
  - `08_tdk-polisher_polished_EP{NNN}.md` when `book_mode.enabled=false`

## Project Layout
```text
{project}/
├── novel-config.md
├── design/
├── episode/
├── revision/
└── _workspace/
```

## Agent Architecture
- Base agents from original architecture: 18
- Added agents:
  - `tdk-polisher`
  - `tdk-layout-agent`
- Current total: 20
- Architecture map: `docs/ARCHITECTURE_MAP.md`
- Agent specifications: `agents/`
- Skill orchestrators: `skills/`
- Plugin metadata: `.claude-plugin/`

## License
Apache-2.0
