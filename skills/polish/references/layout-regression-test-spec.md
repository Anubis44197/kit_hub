# Layout Regression Test Spec

Validate chapter readability and layout consistency.

## Coverage
- dialogue block separation
- paragraph density thresholds
- chapter heading consistency
- scene-break marker consistency

## Required Artifacts
- `tests/regression/layout/<case-id>/input.md`
- `tests/regression/layout/<case-id>/expected_issues.json`

## Pass Rules
- no unresolved critical layout issue
- expected layout issue types are detected when applicable
