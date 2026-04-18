# Prompt A/B Experiment Spec

Use this spec to compare prompt variants safely.

## Scope
- Compare `prompt_version` variants on identical input sets.
- Do not mix different model versions in a single A/B set unless explicitly noted.

## Required Inputs
- fixed test cases
- variant A prompt_version
- variant B prompt_version
- selected model

## Evaluation Metrics
- `quality_score` (0-100)
- `contract_pass_rate` (%)
- `critical_issue_rate` (%)
- `latency_ms`
- `estimated_cost`

## Decision Rules
- Reject variant if critical issue rate increases.
- Prefer variant with better quality/cost ratio.
- Require minimum sample size before promotion.

## Output Artifacts
- `{WORK_DIR}/_workspace/ab-test-report.md`
- `{WORK_DIR}/_workspace/ab-test-results.json`

## Result JSON Fields
- `variant_a`
- `variant_b`
- `sample_size`
- `metrics`
- `winner`
- `promotion_decision`
