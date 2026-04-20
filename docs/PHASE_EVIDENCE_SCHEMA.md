# Phase Evidence Schema

Each phase must emit one JSON evidence file under:
`runtime/runs/<run_id>/evidence/<phase>-<index>.json`

## Required Fields
- `run_id` (string)
- `step_id` (string)
- `phase` (string)
- `execution_claim_mode` (`executed` | `simulated`)
- `artifact_gate_passed` (boolean)
- `dictionary_check_enabled` (boolean)
- `started_at` (ISO-8601)
- `finished_at` (ISO-8601)
- `status` (`completed` | `failed`)
- `output_artifacts` (array of relative paths)
- `notes` (array of strings)

## Optional Fields
- `executed_command` (string or null)
- `error_code` (string)
- `metrics` (object)

## Validation Rules
1. `execution_claim_mode=executed` is allowed only when a phase command is actually invoked in command mode.
2. `artifact_gate_passed=true` requires at least one `output_artifacts` entry.
3. `status=completed` requires `artifact_gate_passed=true`.
4. If `status=failed`, `notes` must include failure reason.

## Example
```json
{
  "run_id": "RUN-20260420-120000-1234",
  "step_id": "create-01",
  "phase": "create",
  "execution_claim_mode": "executed",
  "artifact_gate_passed": true,
  "dictionary_check_enabled": true,
  "started_at": "2026-04-20T12:00:00.000Z",
  "finished_at": "2026-04-20T12:01:02.000Z",
  "status": "completed",
  "executed_command": "my-agent-cli run /create",
  "output_artifacts": [
    "episode/ep001.md",
    "revision/_workspace/04_quality-verifier_verdict_EP001.md"
  ],
  "notes": [
    "artifact gate passed"
  ]
}
```
