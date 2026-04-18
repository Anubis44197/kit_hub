# Adapter Contract: Claude/Codex

This adapter maps shared-task-schema payloads to Claude/Codex prompt invocations.

## Adapter ID
- `adapter_claude_codex_v1`

## Input
- shared-task-schema envelope
- model routing metadata (`primary_model`, timeout policy)

## Transformation Rules
- render `task` as explicit objective line
- render `constraints` as hard rules block
- render `output_contract` as required output checklist
- inject `prompt_version` from target agent/skill frontmatter

## Output Requirements
- preserve contract JSON keys and enum values
- emit explicit verdict token (`PASS` or `REWRITE` where applicable)
- emit standardized `error_code` on blocked/failed steps

## Failure Handling
- first retry: same model, same prompt version
- second attempt: secondary model per fallback policy
- if unresolved: mark blocked with glossary error code
