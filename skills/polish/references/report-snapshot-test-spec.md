# Report Snapshot Test Spec

Snapshot tests guard report/manifest contract stability.

## Targets
- quality verifier verdict reports
- tdk issue JSON
- layout issue JSON
- export manifests

## Required Artifacts
- `tests/snapshots/<flow>/<case-id>/expected/*.json`
- `tests/snapshots/<flow>/<case-id>/expected/*.md`

## Comparison Rules
- JSON: strict field presence and enum value checks
- Markdown: structural section checks; content wording drift allowed unless contract fields changed

## Fail Rules
- missing required field => fail
- enum value mismatch => fail
- missing mandatory section header => fail
