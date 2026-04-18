# Pipeline Metrics and Bottleneck Report Spec

This spec defines runtime metrics collection across create/polish/rewrite/export flows.

## Metrics File
- `{WORK_DIR}/_workspace/pipeline-metrics.json`

## Required Top-Level Fields
- `run_id`
- `skill_name`
- `total_duration_ms`
- `total_steps`
- `retry_count`
- `blocked_count`
- `failed_count`
- `completed_count`
- `step_metrics` (array)

## Step Metric Item
- `step_id`
- `step_name`
- `agent_name`
- `duration_ms`
- `status`
- `retry_index`
- `error_code` (nullable)

## Bottleneck Report
- `{WORK_DIR}/_workspace/pipeline-bottleneck-report.md`

Report must include:
- top 3 slowest steps
- most retried step
- most blocked step
- error-code frequency summary
- recommended optimization targets

## Rules
- `duration_ms` must be recorded for every completed/blocked/failed step.
- Retries must increment `retry_index` and `retry_count`.
- Bottleneck report must be generated when run status is `completed`, `blocked`, or `failed`.
