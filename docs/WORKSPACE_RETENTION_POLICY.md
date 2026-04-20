# Workspace Retention Policy

## Purpose
This policy defines how runner execution artifacts are stored, tracked, and pruned.
It prevents workspace growth from becoming unbounded while preserving recent traceability.

## Canonical Runtime Paths
- Runs root: `runtime/runs/`
- Per-run summary: `runtime/runs/RUN-*/run-summary.json`
- Per-run evidence: `runtime/runs/RUN-*/evidence/*.json`
- Current run pointer: `runtime/current-run.json`

## Current Run Pointer Contract
`runtime/current-run.json` is the fast lookup record for operators and CI.

Required fields:
- `run_id`
- `status` (`in_progress` | `completed` | `failed`)
- `updated_at` (ISO 8601)
- `project_root`
- `summary_path` (project-relative path)
- `evidence_dir` (project-relative path)
- `last_step_id`
- `last_evidence_path`
- `message`
- `retention.enabled`
- `retention.max_runs`

## Retention Behavior
- Retention is controlled by `quality_flags.retention` in `runtime/runner-config.json`.
- Default behavior:
  - `enabled: true`
  - `max_runs: 20`
- After each run completion (or failure), runner prunes old run directories under `runtime/runs/`.
- The active run is never pruned.

## Safety Rules
- Pruning is restricted to directories matching `runtime/runs/RUN-*`.
- Runner verifies target paths remain inside `runtime/runs/` before deletion.
- Retention failures are non-blocking and logged as warnings.

## Configuration Example
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
