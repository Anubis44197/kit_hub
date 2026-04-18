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
grep -q "platform-optimizer" skills/polish/SKILL.md
grep -q "alive-enhancer" skills/polish/SKILL.md
grep -q "revision-executor" skills/polish/SKILL.md
grep -q "tdk-polisher" skills/polish/SKILL.md
grep -q "tdk-layout-agent" skills/polish/SKILL.md
grep -q "revision-reviewer" skills/polish/SKILL.md

echo "[pipeline-smoke] validating rewrite flow contract..."
grep -q "revision-analyst" skills/rewrite/SKILL.md
grep -q "character-sculptor" skills/rewrite/SKILL.md
grep -q "episode-rewriter" skills/rewrite/SKILL.md
grep -q "tdk-polisher" skills/rewrite/SKILL.md
grep -q "tdk-layout-agent" skills/rewrite/SKILL.md
grep -q "quality-verifier" skills/rewrite/SKILL.md

echo "[pipeline-smoke] done"
