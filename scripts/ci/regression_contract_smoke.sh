#!/usr/bin/env bash
set -euo pipefail

echo "[regression-smoke] checking regression spec docs..."
test -f skills/polish/references/regression-test-spec.md
test -f skills/polish/references/tdk-regression-test-spec.md
test -f skills/polish/references/layout-regression-test-spec.md
test -f skills/polish/references/report-snapshot-test-spec.md

echo "[regression-smoke] checking regression fixtures..."
test -f tests/regression/core/case-001/input.md
test -f tests/regression/core/case-001/expected.json
test -f tests/regression/tdk/case-001/input.md
test -f tests/regression/tdk/case-001/expected_issues.json
test -f tests/regression/layout/case-001/input.md
test -f tests/regression/layout/case-001/expected_issues.json

echo "[regression-smoke] checking snapshot fixtures..."
test -f tests/snapshots/create/case-001/expected/verdict.md
test -f tests/snapshots/create/case-001/expected/issues.json

echo "[regression-smoke] checking agent golden placeholders..."
for f in agents/*.md; do
  a="$(basename "$f" .md)"
  test -f "tests/golden/agents/${a}/input.md"
  test -f "tests/golden/agents/${a}/expected.md"
done

echo "[regression-smoke] done"
