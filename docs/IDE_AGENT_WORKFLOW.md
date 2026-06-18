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
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
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
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase export
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
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -Mode command -FromPhase propose -ToPhase export
```

## What The IDE Agent Must Produce

The runner does not accept vague completion. Each phase must write real files:

- proposals under `_workspace/`
- design files under `design/`
- chapters under `episode/`
- state ledgers under `revision/_state/`
- quality/editorial reports under `revision/_workspace/`
- DOCX under `revision/export/`
- agent compliance manifest under `runtime/agent-compliance/{phase}.json`

If files are missing, malformed, too short/long, repetitive, mojibake-corrupted, publication metadata is falsely claimed, or the exported DOCX does not contain the current episode text, the runner fails the phase.

The IDE agent must write the compliance manifest last:

```json
{
  "run_id": "RUN-...",
  "phase": "create",
  "required_agents": ["episode-creator", "tdk-polisher", "tdk-layout-agent", "quality-verifier"],
  "agents_executed": ["episode-creator", "tdk-polisher", "tdk-layout-agent", "quality-verifier"],
  "required_references": ["skills/create/SKILL.md"],
  "loaded_state_files": ["revision/_state/longform-plan.json"],
  "output_artifacts": ["episode/ep001.md"],
  "contract_status": "PASS",
  "missing_items": []
}
```

## Output

Final DOCX files are written under:

```text
revision/export/
```

To copy a file to Desktop:

```powershell
Copy-Item -LiteralPath "revision/export/YOUR_FILE.docx" -Destination "$env:USERPROFILE\Desktop\" -Force
```

Never copy or rename an older DOCX to satisfy export. If DOCX creation fails because a tool such as Pandoc is missing, report the failure and leave export blocked.
