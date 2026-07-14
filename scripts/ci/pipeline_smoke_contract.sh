#!/usr/bin/env bash
set -euo pipefail

echo "[pipeline-smoke] validating create flow contract..."
grep -q "episode-architect" skills/create/SKILL.md
grep -q "continuity-bridge" skills/create/SKILL.md
grep -q "episode-creator" skills/create/SKILL.md
grep -q "tdk-polisher" skills/create/SKILL.md
grep -q "tdk-layout-agent" skills/create/SKILL.md
grep -q "quality-verifier" skills/create/SKILL.md

echo "[pipeline-smoke] validating polish flow contract..."
grep -q "rule-checker" skills/polish/SKILL.md
grep -q "story-analyst" skills/polish/SKILL.md
grep -q "book-structure-optimizer" skills/polish/SKILL.md
grep -q "alive-enhancer" skills/polish/SKILL.md
grep -q "revision-executor" skills/polish/SKILL.md
grep -q "line-editor" skills/polish/SKILL.md
grep -q "copy-editor" skills/polish/SKILL.md
grep -q "tdk-polisher" skills/polish/SKILL.md
grep -q "tdk-layout-agent" skills/polish/SKILL.md
grep -q "revision-reviewer" skills/polish/SKILL.md
grep -q "final-proofreader" skills/polish/SKILL.md
grep -q '"rule-checker"' runtime/phase-contracts/polish.json
grep -q '"story-analyst"' runtime/phase-contracts/polish.json
grep -q '"book-structure-optimizer"' runtime/phase-contracts/polish.json
grep -q '"alive-enhancer"' runtime/phase-contracts/polish.json
grep -q '"revision-executor"' runtime/phase-contracts/polish.json
grep -q '"tdk-layout-agent"' runtime/phase-contracts/polish.json
grep -q '"final-proofreader"' runtime/phase-contracts/polish.json

echo "[pipeline-smoke] validating rewrite flow contract..."
test -f scripts/revision_proposals.ps1
test -f scripts/apply_revision.ps1
grep -q "revision-analyst" skills/rewrite/SKILL.md
grep -q "character-sculptor" skills/rewrite/SKILL.md
grep -q "episode-rewriter" skills/rewrite/SKILL.md
grep -q "tdk-polisher" skills/rewrite/SKILL.md
grep -q "tdk-layout-agent" skills/rewrite/SKILL.md
grep -q "quality-verifier" skills/rewrite/SKILL.md
grep -q "Proposal-first revision" skills/rewrite/SKILL.md
grep -q "revision-proposals-approval.json" skills/rewrite/SKILL.md
grep -q "revision-proposals-approval.json" README.md
grep -q "revision/_workspace/revision-proposals.json" runtime/phase-contracts/rewrite.json
grep -q "revision-proposals-approval.json" runtime/phase-contracts/rewrite.json
grep -q '"character-sculptor"' runtime/phase-contracts/rewrite.json
grep -q '"tdk-layout-agent"' runtime/phase-contracts/rewrite.json

echo "[pipeline-smoke] done"
