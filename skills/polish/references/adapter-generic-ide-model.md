# Adapter Contract: Generic IDE Model

This adapter maps shared-task-schema payloads to non-Claude IDE-integrated models.

## Adapter ID
- `adapter_generic_ide_v1`

## Input
- shared-task-schema envelope
- IDE model runtime config (name, max context, timeout)

## Transformation Rules
- keep task envelope unchanged at semantic level
- enforce same verdict vocabulary (`PASS`/`REWRITE`)
- enforce same error-code glossary
- require output JSON contract parity with Claude/Codex adapter

## Compatibility Rules
- if model cannot satisfy strict JSON, enforce post-format validation step
- if context limit is lower than input size, require chunk plan and merge metadata
- always stamp `effective_model` and `adapter_id` in step metadata

## Failure Handling
- retry once with compacted context
- fallback to configured secondary model
- if unresolved, block with standardized error code
