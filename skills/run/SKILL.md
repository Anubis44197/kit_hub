---
name: run
description: "Single-command pipeline launcher for propose->design->create->polish->rewrite->export with hard gates."
prompt_version: "1.0.0"
---

# Run Skill

## Purpose
Start the full novel pipeline from one command and enforce hard execution gates.

## Command
- `/run`

## Execution Contract
1. Ensure runtime bootstrap is prepared:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
2. Execute orchestrator:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export`

## Hard Rules
- Do not skip phases.
- Do not claim completion without runner evidence artifacts.
- Respect approval gates for `create`, `rewrite`, `export`.
- If a phase fails or is blocked, stop and report exact error + evidence path.

## Required Outputs
- `runtime/current-run.json`
- `runtime/runs/RUN-*/run-summary.json`
- `runtime/runs/RUN-*/evidence/*.json`

## Notes
- In manual mode, the IDE/operator must still complete each phase task.
- For unattended execution, configure command mode in `runtime/runner-config.json`.
