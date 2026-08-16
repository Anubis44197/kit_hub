# Golden Tests

Golden artifacts live in the directories below.

## Agent-level golden fixtures

- `tests/golden/agents/<agent-name>/input.md`
- `tests/golden/agents/<agent-name>/expected.md`

Every agent in `runtime/agent-registry.json` has exactly one fixture pair.
`fixture_agent_runner.ps1` validates each pair (non-placeholder content,
non-empty, contract-backed `Expected contract` marker) and reports
`fixture_validation` results, not autonomous provider execution.

## Pipeline snapshot golden cases

- `tests/snapshots/<skill>/<case-id>/expected/...`

Example: `tests/snapshots/create/case-001/expected/` holds the expected
`issues.json` and `verdict.md` for the deterministic create adapter.

## Regression cases

Regression fixtures are kept under `tests/regression/` (core/layout/tdk) with
`input.md` plus `expected_issues.json` or `expected.json`, separate from the
golden set above.