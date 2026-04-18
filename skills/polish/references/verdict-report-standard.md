# Verdict and Report Standard

Standardize verdict/report formats across create, polish, rewrite, and export validation.

## Verdict Vocabulary
- quality/rewrite gates: `PASS` | `REWRITE`
- export approval gate: `APPROVED` | `BLOCKED`
- export validator: `READY` | `BLOCKED`

No additional verdict tokens are allowed.

## Required Report Header Fields
- `run_id`
- `step_id`
- `agent_name`
- `prompt_version`
- `effective_model`
- `status`

## Required JSON Fields (Generic)
- `verdict`
- `error_code` (nullable)
- `critical`
- `major`
- `minor`
- `manual_review_required` (nullable)

## Error Semantics
- `error_code` must come from `error-code-glossary.md`.
- `verdict` and `error_code` must be logically consistent.
  - example: `PASS` with non-null blocking error code is invalid.
