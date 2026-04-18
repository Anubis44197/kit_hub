# Runner Usage

## Purpose
`scripts/run_pipeline.ps1` is a real orchestrator entrypoint for this repository.
It executes the full phase chain with artifact-gate validation:

`propose -> design-big -> design-small -> create -> polish -> rewrite -> export`

## 1) Install Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

This creates:
- `runtime/runner-config.json` (if missing)
- `runtime/runs/`

## 2) Manual Mode (Default)

Manual mode still asks the user/IDE to run each phase, but phase transitions and artifact gates are automated and tracked.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export
```

Use `-NoWait` to skip enter prompts (useful for prefilled test runs):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase polish -NoWait
```

## 3) Command Mode

Edit `runtime/runner-config.json` and fill `phase_commands`.
Then set `execution_mode` to `command`.

Example:
```json
{
  "execution_mode": "command",
  "phase_commands": {
    "propose": "my-agent-cli run /propose",
    "design-big": "my-agent-cli run /design-big",
    "design-small": "my-agent-cli run /design-small",
    "create": "my-agent-cli run /create",
    "polish": "my-agent-cli run /polish",
    "rewrite": "my-agent-cli run /rewrite",
    "export": "my-agent-cli run /export-word"
  }
}
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export -Mode command
```

## 3.1) Optional Dictionary Check Layer

You can enable an additional dictionary-verification pass for Turkish text quality.
This runs automatically after `create`, `polish`, and `rewrite` phases.

In `runtime/runner-config.json`:

```json
{
  "quality_flags": {
    "enable_dictionary_check": true,
    "dictionary_check_command": "powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot \"{project_root}\" -Phase {phase} -RunId {run_id}"
  }
}
```

Output artifact:
- `revision/_workspace/10_tdk-dictionary-check_<phase>.json`

You can also force-enable from CLI:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase rewrite -EnableDictionaryCheck
```

## 4) Run Summary

Each run writes:
- `runtime/runs/RUN-YYYYMMDD-HHMMSS/run-summary.json`

This is the canonical runner execution log.

## 5) Artifact Gates

The runner validates required artifacts per phase before moving forward.
If missing, the run fails immediately with a clear message.
