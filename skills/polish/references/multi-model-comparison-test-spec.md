# Multi-Model Comparison Test Spec

Compare model behavior on identical inputs for the same task contract.

## Goal
Measure quality, contract reliability, latency, and cost tradeoffs per model.

## Required Inputs
- fixed task payloads (shared-task-schema)
- model set (at least 2 models)
- fixed prompt_version
- fixed fallback policy

## Evaluation Metrics
- `contract_pass_rate`
- `verdict_agreement_rate`
- `critical_issue_count`
- `latency_ms`
- `estimated_cost`

## Output Artifacts
- `{WORK_DIR}/_workspace/model-compare-report.md`
- `{WORK_DIR}/_workspace/model-compare-results.json`

## Result JSON Fields
- `task_id`
- `models`
- `sample_size`
- `metrics_by_model`
- `ranking`
- `recommended_primary`
- `recommended_secondary`

## Fail Conditions
- contract_pass_rate below threshold
- incompatible verdict drift against baseline model
- unresolved critical issue increase
