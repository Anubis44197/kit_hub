# Error Code Glossary

Use these codes consistently across all pipeline steps and reports.

## Core Codes
- `E_SCHEMA`: Required schema field missing or malformed.
- `E_ARTIFACT_MISSING`: Required input/output artifact file not found.
- `E_CONFIG_INVALID`: Invalid or incomplete `novel-config.md` values.
- `E_CONTINUITY`: Timeline/state continuity conflict detected.
- `E_STYLE`: Style-rule violation beyond allowed threshold.
- `E_TDK_CRITICAL`: Critical TDK issue remains unresolved.
- `E_LAYOUT_CRITICAL`: Critical layout issue remains unresolved.
- `E_SCRIPT_POLICY`: Disallowed script detected in story content.
- `E_APPROVAL_REQUIRED`: Explicit user approval missing for export.
- `E_APPROVAL_SCOPE`: Approval exists but does not match requested range/path.
- `E_EXPORT_BLOCKED`: Export blocked by validator gate.
- `E_COPYRIGHT_RISK`: Copyright compliance risk requires block or manual review.
- `E_PII_POLICY`: PII redaction policy violation in report/log output.
- `E_WORKDIR_BOUNDARY`: Attempted read/write outside assigned WORK_DIR boundary.
- `E_INTERNAL`: Unexpected runtime/system failure.

## Usage Rule
- Every `blocked` or `failed` step must set one primary `error_code`.
- Optional secondary codes can be listed in step metadata as `error_codes`.
