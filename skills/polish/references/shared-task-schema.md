# Shared Task Schema

Use this schema for model-agnostic task execution across all skills and agents.

## Envelope
```json
{
  "schema_version": "1.0.0",
  "task": "string",
  "inputs": {},
  "constraints": {},
  "output_contract": {}
}
```

## Required Fields
- `schema_version`
- `task`
- `inputs`
- `constraints`
- `output_contract`

## Task Naming Convention
- `create.episode_draft`
- `polish.episode_fix`
- `rewrite.episode_rebuild`
- `export.word_docx`
- `validate.quality_gate`

## `inputs` Guidelines
- include source artifact paths
- include target episode/range metadata
- include `run_id` and `step_id`

## `constraints` Guidelines
- language policy
- script policy
- guard rails
- timeout/fallback policy refs

## `output_contract` Guidelines
- expected artifact list
- mandatory json fields
- verdict vocabulary
- error-code vocabulary
