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

echo "[contract-lint] validating mojibake guard..."
mojibake_pattern="$(printf '\\303|\\304|\\305|\\357\\277\\275')"
mojibake_hits="$(grep -R -n -E "$mojibake_pattern" README.md RELEASE_CHECKLIST.md docs index.html runtime scripts skills \
  | grep -v '^scripts/run_pipeline.ps1:' \
  | grep -v '^scripts/ci/tdk_local_rule_check.py:' \
  | grep -v '^skills/polish/references/tdk-official-writing-rules.md:' || true)"
if [ -n "$mojibake_hits" ]; then
  echo "$mojibake_hits"
  echo "Unexpected mojibake markers found"
  exit 1
fi

echo "[contract-lint] validating mandatory export gate..."
grep -q "export-approval-gate" skills/export-word/SKILL.md
grep -q "export-validator" skills/export-word/SKILL.md

echo "[contract-lint] validating proposal-first revision gate..."
test -f scripts/revision_proposals.ps1
test -f scripts/apply_revision.ps1
test -f scripts/ci/revision_proposal_gate_test.ps1
grep -q "Proposal-first revision" skills/rewrite/SKILL.md
grep -q "revision-proposals-approval.json" skills/rewrite/SKILL.md
grep -q "revision/_workspace/revision-proposals.json" runtime/phase-contracts/rewrite.json
grep -q "revision-proposals-approval.json" runtime/phase-contracts/rewrite.json

echo "[contract-lint] validating language policy blocks..."
grep -q "Chapter/story content language must be Turkish." skills/create/SKILL.md
grep -q "Chapter/story content language must be Turkish." skills/polish/SKILL.md
grep -q "Chapter/story content language must be Turkish." skills/rewrite/SKILL.md
grep -q "Chapter/story content language must be Turkish." skills/export-word/SKILL.md

echo "[contract-lint] validating context saliency boundary..."
test -f agents/context-saliency-gate.md
test -f skills/polish/references/context-saliency-contract.md
test -f tests/golden/agents/context-saliency-gate/input.md
test -f tests/golden/agents/context-saliency-gate/expected.md
for f in runtime/phase-contracts/design-small.json runtime/phase-contracts/create.json runtime/phase-contracts/polish.json runtime/phase-contracts/rewrite.json; do
  grep -q "context-saliency-gate" "$f"
  grep -q "story-bible.json" "$f"
  grep -q "context-saliency-map.json" "$f"
done
grep -q "story-bible.json" scripts/local_phase.ps1
grep -q "context-saliency-map.json" scripts/local_phase.ps1
grep -q "context-saliency-gate_" scripts/run_pipeline.ps1
grep -q "writer_may_use_full_story_bible" scripts/ci/validate_state_reducers.ps1
grep -q "context-saliency-map.json" scripts/ide_phase_prompt.ps1

echo "[contract-lint] validating model adapter references..."
test -f skills/polish/references/shared-task-schema.md
test -f skills/polish/references/agent-skill-schema-mapping.md
test -f skills/polish/references/adapter-claude-codex.md
test -f skills/polish/references/adapter-generic-ide-model.md
test -f skills/polish/references/verdict-report-standard.md
test -f skills/polish/references/multi-model-comparison-test-spec.md
test -f skills/polish/references/tdk-source-assurance-chain.md
test -f docs/STRICT_EXECUTION_POLICY.md
test -f docs/PHASE_EVIDENCE_SCHEMA.md
test -f docs/WORKSPACE_RETENTION_POLICY.md
test -f agents/brief-interviewer.md
test -f agents/book-dna-locker.md
test -f agents/layout-profile-planner.md
test -f skills/intake/SKILL.md
test -f runtime/book-brief.schema.json
test -f runtime/layout-profile.schema.json
test -f runtime/phase-contracts/intake.json
grep -q "book-brief-approval.json" scripts/run_pipeline.ps1
grep -q "Invoke-Intake" scripts/local_phase.ps1
grep -q "runtime/book-brief.json" scripts/local_phase.ps1
grep -q "runtime/book-dna.json" scripts/local_phase.ps1
grep -q "runtime/layout-profile.json" scripts/local_phase.ps1
grep -q '"intake"' runtime/runner-config.template.json
grep -q "book-brief-approval.json" runtime/runner-config.ide-manual.template.json
grep -q "current-run.json" scripts/run_pipeline.ps1
grep -q "Invoke-RunRetention" scripts/run_pipeline.ps1
grep -q "Ensure-UserApproval" scripts/run_pipeline.ps1
grep -q "Validate-PhaseContracts" scripts/run_pipeline.ps1
grep -q "Validate-AgentCompliance" scripts/run_pipeline.ps1
grep -q "Validate-AgentGovernanceCatalog" scripts/run_pipeline.ps1
grep -q "Write-RunJournalEvent" scripts/run_pipeline.ps1
grep -q "contract_hashes" scripts/run_pipeline.ps1
grep -q "Validate-CommandSafety" scripts/run_pipeline.ps1
grep -q "Validate-ArtifactSizeBudget" scripts/run_pipeline.ps1
grep -q "Assert-NoForbiddenPatterns" scripts/run_pipeline.ps1
grep -q "Validate-EpisodeTextQuality" scripts/run_pipeline.ps1
grep -q "Validate-StateReducers" scripts/run_pipeline.ps1
grep -q "require_user_approvals" runtime/runner-config.template.json
grep -q "enforce_phase_contracts" runtime/runner-config.template.json
grep -q "enable_negative_enforcement" runtime/runner-config.template.json
grep -q "enable_text_quality_gates" runtime/runner-config.template.json
grep -q "enable_command_safety" runtime/runner-config.template.json
grep -q "enable_artifact_size_budget" runtime/runner-config.template.json
grep -q "text_quality_gates" runtime/runner-config.template.json
grep -q "contract_hashes" runtime/agent-compliance.schema.json
grep -q "contract_hashes" docs/PHASE_EVIDENCE_SCHEMA.md
grep -q "contract_hashes" docs/AGENT_COMPLIANCE_ENFORCEMENT.md
grep -q "contract_hashes" scripts/ci/write_agent_compliance.ps1
grep -q "front-matter-editor" scripts/local_phase.ps1
grep -q "cover-designer" scripts/local_phase.ps1
grep -q "revision/_state/book-plan.json" scripts/local_phase.ps1
grep -q "revision/_state/chapter-plan.json" scripts/local_phase.ps1
grep -q "revision/_state/layout-plan.json" scripts/local_phase.ps1

echo "[contract-lint] validating quality-verifier strict metadata contract..."
grep -q "## Required Report Metadata (Strict)" agents/quality-verifier.md
grep -q "run_id" agents/quality-verifier.md
grep -q "step_id" agents/quality-verifier.md
grep -q "## Minimal Markdown Verdict Template (Required)" agents/quality-verifier.md

echo "[contract-lint] validating Windows validation scripts..."
test -f scripts/ci/verify_docx_integrity.ps1
test -f scripts/ci/external_smoke_test.ps1
test -f scripts/ci/extended_readiness_check.ps1
test -f scripts/ci/tdk_dict_check.py
test -f scripts/ci/tdk_dict_check.ps1

echo "[contract-lint] done"
