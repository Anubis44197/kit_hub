# Golden Output Drift Spec

This spec defines how to detect behavior drift after agent/skill contract changes.

## Golden Set
- Store canonical sample inputs and expected outputs under:
  - `tests/golden/<flow>/<case-id>/`

Minimum flows:
- `create`
- `polish`
- `rewrite`
- `export-word`

## Comparison Targets
- verdict values
- issue counts by severity
- issue enum distribution
- mandatory artifact presence
- summary/manifest field completeness

## Drift Rules
- `critical` severity count increase => fail
- verdict downgrade (`PASS` -> `REWRITE`) => fail
- missing mandatory artifact => fail
- field removal in JSON contracts => fail
- formatting-only differences in markdown narrative sections => warn

## Report
- `{WORK_DIR}/_workspace/golden-drift-report.md`

Report sections:
- changed cases
- fail reasons
- warning reasons
- approved drift notes
