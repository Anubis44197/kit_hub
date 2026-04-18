# Model Fallback and Timeout Policy

Apply this policy to every agent/skill invocation.

## Routing
- `primary_model`: first-choice model for task.
- `secondary_model`: fallback when primary fails by policy.
- `tertiary_model` (optional): emergency fallback for contract completion.

## Timeout Defaults
- interactive step timeout: `60s`
- heavy generation step timeout: `180s`
- export/validation step timeout: `90s`

## Fallback Triggers
- timeout reached
- malformed JSON contract output
- missing required artifacts after retry
- blocked by transient model/runtime error

## Retry/Fallback Order
1. Retry primary once (same prompt_version, same constraints).
2. Switch to secondary model.
3. If still failing, emit blocked status with error code and stop.

## Required Metadata
Each step record must include:
- `primary_model`
- `effective_model`
- `fallback_used` (bool)
- `fallback_reason`
- `timeout_seconds`
