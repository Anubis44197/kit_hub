#!/usr/bin/env bash
set -euo pipefail

echo "[final-readiness] run contract lint..."
bash scripts/ci/validate_contracts.sh

echo "[final-readiness] run smoke test..."
bash scripts/ci/smoke_test.sh

echo "[final-readiness] run regression contract smoke..."
bash scripts/ci/regression_contract_smoke.sh

echo "[final-readiness] done"
