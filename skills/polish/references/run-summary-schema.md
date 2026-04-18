# Run Summary Schema

The file `{WORK_DIR}/_workspace/run-summary.json` is the canonical runtime index for a pipeline run.

## Required Top-Level Fields
- `run_id`
- `skill_name`
- `started_at`
- `updated_at`
- `status` (`in_progress` | `completed` | `blocked` | `failed`)
- `current_step`
- `steps` (array)

## Step Item Schema
Each `steps[]` item must include:
- `step_id`
- `step_name`
- `agent_name`
- `status` (`pending` | `in_progress` | `completed` | `blocked` | `failed`)
- `started_at`
- `finished_at`
- `artifacts` (array of file paths)
- `error_code` (nullable)
- `error_message` (nullable)
- `primary_model` (nullable)
- `effective_model` (nullable)
- `fallback_used` (bool)
- `fallback_reason` (nullable)
- `timeout_seconds` (nullable)

## Rules
- `run_id` is immutable within the same run.
- `step_id` values must be unique within `steps[]`.
- `updated_at` must be refreshed after each step transition.
- Any blocking condition must be reflected in both `status` and `error_code`.
- `error_code` must be selected from `references/error-code-glossary.md`.
