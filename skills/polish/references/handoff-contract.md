# Handoff Contract

Standard contract for inter-agent payload transfer.

## Required Handoff Fields
- `run_id`
- `step_id`
- `from_agent`
- `to_agent`
- `episode`
- `task_id`
- `input_artifacts`
- `output_artifacts`
- `blocking_issues`
- `error_code` (nullable)

## Rules
- No handoff without `output_artifacts`.
- If `blocking_issues` is non-empty, next step must verify before execution.
- `run_id` must remain unchanged within the same pipeline run.
