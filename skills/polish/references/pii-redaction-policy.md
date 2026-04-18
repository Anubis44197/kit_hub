# PII Redaction Policy

Apply this policy to prompts, reports, manifests, and logs.

## Protected Data Types
- full personal names when not required by story context metadata
- phone numbers
- email addresses
- physical addresses
- ID/passport/tax-like identifiers
- payment card numbers

## Redaction Format
- Replace sensitive spans with tokens:
  - `[REDACTED_NAME]`
  - `[REDACTED_PHONE]`
  - `[REDACTED_EMAIL]`
  - `[REDACTED_ADDRESS]`
  - `[REDACTED_ID]`
  - `[REDACTED_CARD]`

## Rules
- Redact in reports and machine-readable logs by default.
- Keep story-content text unchanged unless the user explicitly requests redaction in manuscript output.
- Include `redaction_applied: true|false` in relevant report metadata.
