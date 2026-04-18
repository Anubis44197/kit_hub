#!/usr/bin/env bash
set -euo pipefail

echo "[final-readiness] run contract lint..."
bash scripts/ci/validate_contracts.sh

echo "[final-readiness] run smoke test..."
bash scripts/ci/smoke_test.sh

echo "[final-readiness] run regression contract smoke..."
bash scripts/ci/regression_contract_smoke.sh

echo "[final-readiness] verify plan has no open TODO tasks..."
# Allow template lines that document TODO syntax examples.
open_todo_count="$(
  awk '
    /- \[ \] `TODO`/ {
      if ($0 ~ /TODO\|IN_PROGRESS\|BLOCKED\|DONE/) next;
      c++;
    }
    END { print c+0 }
  ' YAPILACAKLAR_PLAN.md
)"

if [ "$open_todo_count" -ne 0 ]; then
  echo "Open TODO tasks found in YAPILACAKLAR_PLAN.md: $open_todo_count"
  exit 1
fi

echo "[final-readiness] done"
