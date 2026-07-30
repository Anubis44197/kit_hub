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
- `request_compliance`
- `target_length_compliance`
- `state_update_compliance`
- `alive_dialogue`
- `alive_nonverbal`
- `alive_tension`
- `alive_distance`

Optional keys:
- `tdk_compliance`
- `layout_compliance`
- `publication_readiness`

## Required Evidence Keys
- `checked_files`
- `handoff_chain`
- `state_ledgers_read`
- `state_ledgers_written`
- `chapter_target`
- `actual_metrics`

`actual_metrics` must include:
- `word_count`
- `character_count`
- `scene_block_count`
- `dialogue_ratio`

## `issue_summary` Required Keys
- `critical`
- `major`
- `minor`
- `manual_review_required`
