# IDE Agent Workflow

This repository can run without an application-owned API key.

Use this mode when an IDE agent such as Cursor, Windsurf, Continue, Claude Code, or Codex can edit files in the workspace. The IDE agent performs the writing work; the runner validates the files.

## Responsibility Boundary

In IDE Agent Mode, `kit_hub` is not the creative language model. The IDE agent or the human operator writes the creative manuscript files. `kit_hub` provides the production frame around that writing:

- phase orchestration
- required file contracts
- longform state ledgers
- text quality and continuity gates
- agent compliance manifests
- DOCX/front matter/cover brief export

Do not describe an IDE Agent Mode result as "the app wrote the book by itself." The accurate description is: the IDE agent wrote or revised the content, and `kit_hub` validated, organized, tracked, and exported the book package.

Autonomous creative generation requires an explicit provider-backed command or API integration configured in command mode. Internet research is not automatic; it must be a defined phase/tool with source artifacts.

## Setup

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kitap Adi"
Set-Location "$env:USERPROFILE\Documents\KitHubProjects\kitap-adi"
Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force
```

Put the user request in:

```text
runtime/book-request.md
```

Example:

```text
3 bolumluk kisa kitap testi: Istanbul'da Bogaz'da yemek yiyen bir adam betimlensin.
```

PowerShell 5.1 note: Turkish text files should be UTF-8 with BOM. If Turkish characters look broken, re-save the file as UTF-8 with BOM.

## Run With Manual IDE Agent

Start the runner:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase export
```

At each phase, the runner pauses. In your IDE agent, ask it to do that phase. You can print the exact phase prompt:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ide_phase_prompt.ps1 -Phase create
```

After the IDE agent writes the required files, return to the terminal and press Enter. The runner checks artifacts and moves to the next phase.

## Local Test Mode

Local test mode needs no API. It uses deterministic scaffolding and contract checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/local_phase.ps1 -ProjectRoot . -Phase propose -RunId RUN-LOCAL
```

This proves proposal scaffolding and approval-file creation. It does not write the actual manuscript. For `create`, `polish`, and `rewrite`, use IDE manual mode or a configured provider/API/CLI command.

Local test mode is a smoke test adapter. It must not be presented as proof that a provider LLM, IDE agent, or autonomous agent team wrote the book.

## Real Command Mode

Use command mode only when you have a CLI that can run the model or IDE agent automatically.

Edit `runtime/runner-config.json`:

```json
{
  "execution_mode": "command",
  "phase_commands": {
    "propose": "your-agent-cli propose",
    "design-big": "your-agent-cli design-big",
    "design-small": "your-agent-cli design-small",
    "create": "your-agent-cli create",
    "polish": "your-agent-cli polish",
    "rewrite": "your-agent-cli rewrite",
    "export": "your-agent-cli export"
  }
}
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -Mode command -FromPhase intake -ToPhase export
```

## What The IDE Agent Must Produce

The runner does not accept vague completion. Each phase must write real files:

- proposals under `_workspace/`
- design files under `design/`
- approved book/chapter/layout plans under `design/04_book_plan.md`, `design/05_chapter_plan.md`, `design/06_layout_plan.md`
- chapters under `episode/`
- state ledgers under `revision/_state/`
- quality/editorial reports under `revision/_workspace/`
- DOCX under `revision/export/`
- agent compliance manifest under `runtime/agent-compliance/{phase}.json`

If files are missing, malformed, too short/long, repetitive, mojibake-corrupted, publication metadata is falsely claimed, or the exported DOCX does not contain the current episode text, the runner fails the phase.

Before any chapter writing, `design-big` must produce `revision/_state/book-plan.json`, `revision/_state/open-source-story-model.json`, `revision/_state/chapter-plan.json`, and `revision/_state/layout-plan.json`. `design-small` is blocked until the user approves `runtime/approvals/book-plan-approval.json`; do not write around this gate by manually creating chapter files early.

`open-source-story-model.json` is the mandatory story planning model. The IDE agent must load it before `design-small`, `create`, `polish`, `rewrite`, and `export`. It binds Manuskript-style character/plot/world/outline fields, novelWriter-style synopsis/tag/cross-reference rules, bibisco-style premise/fabula/setting rules, and STORM-style pre-writing/source rules into the current book project.

The IDE agent must write the compliance manifest last:

```json
{
  "run_id": "RUN-...",
  "phase": "create",
  "required_agents": ["episode-creator", "tdk-polisher", "tdk-layout-agent", "quality-verifier"],
  "agents_executed": ["episode-creator", "tdk-polisher", "tdk-layout-agent", "quality-verifier"],
  "required_references": ["skills/create/SKILL.md"],
  "loaded_state_files": [
    "revision/_state/book-plan.json",
    "revision/_state/open-source-story-model.json",
    "revision/_state/chapter-plan.json",
    "revision/_state/layout-plan.json",
    "revision/_state/longform-plan.json",
    "revision/_state/character-state.json",
    "revision/_state/plot-ledger.json",
    "revision/_state/continuity-ledger.json"
  ],
  "output_artifacts": ["episode/ep001.md"],
  "artifact_hashes": [
    {
      "path": "episode/ep001.md",
      "sha256": "lowercase-64-character-sha256"
    }
  ],
  "phase_authority": "manual_ide_agent",
  "completed_at": "2026-06-18T12:00:00.0000000+03:00",
  "contract_status": "PASS",
  "missing_items": []
}
```

Recommended helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/write_agent_compliance.ps1 -ProjectRoot . -Phase create -RunId RUN-... -RequiredAgents episode-creator,tdk-polisher,tdk-layout-agent,quality-verifier -RequiredReferences skills/create/SKILL.md -LoadedStateFiles revision/_state/book-plan.json,revision/_state/open-source-story-model.json,revision/_state/chapter-plan.json,revision/_state/layout-plan.json,revision/_state/longform-plan.json,revision/_state/character-state.json,revision/_state/plot-ledger.json,revision/_state/continuity-ledger.json -OutputArtifacts episode/ep001.md -PhaseAuthority manual_ide_agent
```

## Output

Final DOCX files are written under:

```text
revision/export/
```

To copy the approved final output to Desktop, use the guarded final-export command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot . -DestinationDirectory "$env:USERPROFILE\Desktop" -RequireExportApproval
```

Never copy or rename an older DOCX to satisfy export. If DOCX creation fails because a tool such as Pandoc is missing, report the failure and leave export blocked.
Never clean working files until the user explicitly approves `runtime/approvals/cleanup-approval.json` with `approved=true` and `final_output_preserved=true`.
