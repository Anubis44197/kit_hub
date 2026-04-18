# Deterministic Thresholds

Use these baseline numeric thresholds unless project config overrides them.

## Quality Axes (0-100)
- `timeline_consistency`: pass >= 95
- `numeric_consistency`: pass >= 95
- `voice_integrity`: pass >= 85
- `hook_strength`: pass >= 80
- `guardrail_compliance`: pass >= 95
- `tdk_compliance`: pass >= 90
- `layout_compliance`: pass >= 90 when book mode is enabled

## Verdict Rule
- `PASS` only if all mandatory axes meet threshold and no critical issue exists.
- Otherwise verdict must be `REWRITE`.

## Retry Bound
- max retries per episode stage: `2`
- if still below threshold: block and emit blocking error code
