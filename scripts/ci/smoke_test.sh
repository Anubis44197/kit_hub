#!/usr/bin/env bash
set -euo pipefail

echo "[smoke] checking fixture presence..."
test -f tests/fixtures/sample-project/novel-config.md
test -d tests/fixtures/sample-project/design
test -d tests/fixtures/sample-project/episode
test -d tests/fixtures/sample-project/revision

echo "[smoke] validating novel-config schema..."
bash scripts/ci/validate_novel_config.sh tests/fixtures/sample-project/novel-config.md

echo "[smoke] validating episode ranges..."
bash scripts/ci/check_ep_range_overlap.sh tests/fixtures/sample-project/novel-config.md

echo "[smoke] checking mandatory agents..."
test -f agents/tdk-polisher.md
test -f agents/tdk-layout-agent.md
test -f agents/export-approval-gate.md
test -f agents/export-validator.md
test -f agents/book-exporter.md

echo "[smoke] checking mandatory skills..."
test -f skills/create/SKILL.md
test -f skills/polish/SKILL.md
test -f skills/rewrite/SKILL.md
test -f skills/export-word/SKILL.md

echo "[smoke] checking runtime references..."
test -f skills/polish/references/run-summary-schema.md
test -f skills/polish/references/error-code-glossary.md
test -f skills/polish/references/pipeline-metrics-spec.md

echo "[smoke] validating pipeline contract..."
bash scripts/ci/pipeline_smoke_contract.sh

echo "[smoke] done"
