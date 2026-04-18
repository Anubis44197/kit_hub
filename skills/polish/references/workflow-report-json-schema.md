# Workflow Report JSON Schema

This schema applies to create/polish/rewrite workflow reports.

## Required Fields
- `run_id`
- `step_id`
- `flow` (`create` | `polish` | `rewrite`)
- `episode`
- `agent_name`
- `prompt_version`
- `effective_model`
- `verdict`
- `scores`
- `issue_summary`
- `artifacts`

## `scores` Required Keys
- `timeline_consistency`
- `numeric_consistency`
- `voice_integrity`
- `hook_strength`
- `guardrail_compliance`

Optional keys:
- `tdk_compliance`
- `layout_compliance`

## `issue_summary` Required Keys
- `critical`
- `major`
- `minor`
- `manual_review_required`
