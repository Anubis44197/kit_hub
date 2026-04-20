# Runner Usage

## Purpose
`scripts/run_pipeline.ps1` is a real orchestrator entrypoint for this repository.
It executes the full phase chain with artifact-gate validation:

`propose -> design-big -> design-small -> create -> polish -> rewrite -> export`

Important:
- Runner validates phase artifacts and emits run/evidence logs.
- Runner execution is not equal to literary quality acceptance by itself.
- Phase completion claims are proof-bound by evidence files.

## 1) Install Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

This creates:
- `runtime/runner-config.json` (if missing)
- `runtime/runs/`
- `runtime/approvals/design-freeze.json`
- `runtime/approvals/rewrite-approval.json`
- `runtime/approvals/export-approval.json`

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
- `runtime/runs/RUN-YYYYMMDD-HHMMSS/evidence/<phase>-<index>.json`
- `runtime/current-run.json`

This is the canonical runner execution log.

`runtime/current-run.json` always points to the latest run state and latest evidence file.

## 4.1) Execution Claim Modes

Phase evidence includes:
- `execution_claim_mode=executed`: phase command ran through command mode
- `execution_claim_mode=simulated`: no command execution proof (manual mode or synthetic run)

Do not report an executed run without `executed` evidence records.

## 4.2) Retention

Runner can prune old run folders automatically after run completion.

In `runtime/runner-config.json`:

```json
{
  "quality_flags": {
    "retention": {
      "enabled": true,
      "max_runs": 20
    }
  }
}
```

Pruning only affects `runtime/runs/RUN-*` directories.

## 5) Artifact Gates

The runner validates required artifacts per phase before moving forward.
If missing, the run fails immediately with a clear message.

## 5.1) Approval Gates (Hard)

When `quality_flags.require_user_approvals=true` (default), these gates are mandatory:
- `create` requires `runtime/approvals/design-freeze.json` with `approved=true`
- `rewrite` requires `runtime/approvals/rewrite-approval.json` with `approved=true`
- `export` requires `runtime/approvals/export-approval.json` with `approved=true`

Without approval, phase is blocked.

## 5.2) Phase Contracts (Hard)

When `quality_flags.enforce_phase_contracts=true` (default):
- issue JSON artifacts are schema-validated (required fields + severity enum)
- verdict markdown must include `VERDICT: PASS|FAIL|BLOCKED`
- export requires manifest JSON artifact

Schema mismatch fails the phase.

## 5.3) Negative Enforcement

When `quality_flags.enable_negative_enforcement=true` (default),
runner scans episode outputs and blocks forbidden patterns.

Default patterns are configurable under:
- `quality_flags.forbidden_content_patterns`

## 6) Policy Documents

- `docs/STRICT_EXECUTION_POLICY.md`
- `docs/PHASE_EVIDENCE_SCHEMA.md`
- `docs/WORKSPACE_RETENTION_POLICY.md`
