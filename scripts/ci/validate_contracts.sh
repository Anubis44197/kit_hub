#!/usr/bin/env bash
set -euo pipefail

echo "[contract-lint] validating agent frontmatter..."
for f in agents/*.md; do
  grep -q "^---" "$f"
  grep -q "^name:" "$f"
  grep -q "^description:" "$f"
  grep -q "^prompt_version:" "$f"
done

echo "[contract-lint] validating skill frontmatter..."
for f in skills/*/SKILL.md; do
  grep -q "^---" "$f"
  grep -q "^name:" "$f"
  grep -q "^description:" "$f"
  grep -q "^prompt_version:" "$f"
done

echo "[contract-lint] validating verdict vocabulary..."
grep -R -n "REVISE" agents skills && {
  echo "Found forbidden verdict token: REVISE"
  exit 1
} || true

echo "[contract-lint] validating mandatory export gate..."
grep -q "export-approval-gate" skills/export-word/SKILL.md
grep -q "export-validator" skills/export-word/SKILL.md

echo "[contract-lint] validating language policy blocks..."
grep -q "Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana." skills/create/SKILL.md
grep -q "Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana." skills/polish/SKILL.md
grep -q "Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana." skills/rewrite/SKILL.md
grep -q "Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana." skills/export-word/SKILL.md

echo "[contract-lint] validating model adapter references..."
test -f skills/polish/references/shared-task-schema.md
test -f skills/polish/references/agent-skill-schema-mapping.md
test -f skills/polish/references/adapter-claude-codex.md
test -f skills/polish/references/adapter-generic-ide-model.md
test -f skills/polish/references/verdict-report-standard.md
test -f skills/polish/references/multi-model-comparison-test-spec.md

echo "[contract-lint] validating quality-verifier strict metadata contract..."
grep -q "## Required Report Metadata (Strict)" agents/quality-verifier.md
grep -q "run_id" agents/quality-verifier.md
grep -q "step_id" agents/quality-verifier.md
grep -q "## Minimal Markdown Verdict Template (Required)" agents/quality-verifier.md

echo "[contract-lint] validating Windows validation scripts..."
test -f scripts/ci/verify_docx_integrity.ps1
test -f scripts/ci/external_smoke_test.ps1

echo "[contract-lint] done"
