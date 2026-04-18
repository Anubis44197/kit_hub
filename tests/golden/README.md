# Golden Tests

Place golden test cases under:

- `tests/golden/create/<case-id>/`
- `tests/golden/polish/<case-id>/`
- `tests/golden/rewrite/<case-id>/`
- `tests/golden/export-word/<case-id>/`

Each case should include:
- input artifacts
- expected verdict/report/manifest outputs
- optional approved drift note

Agent-level golden placeholders:
- `tests/golden/agents/<agent-name>/input.md`
- `tests/golden/agents/<agent-name>/expected.md`
