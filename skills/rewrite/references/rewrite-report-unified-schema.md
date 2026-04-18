# Rewrite Report Unified Schema

Use this schema to unify all rewrite-stage reports.

## Scope
- `revision-analyst` report
- `character-sculptor` report
- `episode-rewriter` execution report
- `quality-verifier` rewrite verdict report

## Required Shared Fields
- `run_id`
- `step_id`
- `episode`
- `agent_name`
- `prompt_version`
- `effective_model`
- `verdict`
- `error_code` (nullable)
- `scores`
- `issue_summary`
- `artifacts`

## `scores` Baseline Keys
- `design_alignment`
- `continuity_alignment`
- `voice_integrity`
- `rewrite_completeness`

## `issue_summary` Keys
- `critical`
- `major`
- `minor`
- `manual_review_required`

## Verdict Rules
- Allowed verdicts: `PASS` or `REWRITE`
- If `critical > 0`, verdict cannot be `PASS`

## Output
- `{WORK_DIR}/_workspace/rewrite-unified-report_EP{NNN}.json`
