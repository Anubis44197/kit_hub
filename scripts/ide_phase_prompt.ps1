param(
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Show-CommonHeader {
  param([string]$PhaseName)
  $contractPath = Join-Path $ProjectRoot "runtime/phase-contracts/$PhaseName.json"
  $agentSequence = @()
  if (Test-Path -LiteralPath $contractPath -PathType Leaf) {
    try {
      $contract = [System.IO.File]::ReadAllText($contractPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
      $agentSequence = @($contract.agent_sequence | ForEach-Object { [string]$_ })
    }
    catch {
      $agentSequence = @()
    }
  }
  Write-Host "IDE AGENT TASK: $PhaseName"
  Write-Host ""
  Write-Host "Work inside this repository only:"
  Write-Host $ProjectRoot
  Write-Host ""
  Write-Host "Rules:"
  Write-Host "- Story/book content must be Turkish."
  Write-Host "- Preserve valid UTF-8 Turkish characters."
  Write-Host "- Do not invent ISBN, publisher, barcode, copyright owner, or official approval."
  Write-Host "- Follow runtime/agent-registry.json and runtime/phase-contracts/$PhaseName.json; do not add agents or outputs outside the contract."
  Write-Host "- Write the required files; the runner will validate artifacts after you finish."
  Write-Host "- Do not use unresolved placeholder text such as plan_required, to_be_confirmed, TBD, TODO, or fill in later."
  Write-Host "- Do not load stale project, sample manuscript, unrelated DOCX, or old test content as story context."
  Write-Host "- When Story Bible files exist, use chapter-specific context from context-saliency-map.json instead of dumping the full raw Story Bible into writer prompts."
  Write-Host "- Write runtime/agent-compliance/$PhaseName.json last with full schema fields, artifact_hashes, contract_hashes, agent_statuses, and contract_status PASS; use scripts/ci/write_agent_compliance.ps1 instead of hand-writing it."
  Write-Host "- Compliance output_artifacts must list concrete files only; wildcards such as episode/ep*.md are rejected."
  if ($agentSequence.Count -gt 0) {
    Write-Host ""
    Write-Host "Agent execution order:"
    for ($i = 0; $i -lt $agentSequence.Count; $i++) {
      Write-Host ("{0}. {1}" -f ($i + 1), $agentSequence[$i])
    }
    Write-Host ""
    Write-Host "Coordination rule: specialist agents produce evidence first; chief-editor-orchestrator runs last and may block PASS if any evidence, state update, or approval is missing."
  }
  Write-Host ""
}

Show-CommonHeader -PhaseName $Phase

switch ($Phase) {
  "intake" {
    Write-Host "Goal: ask/structure the user brief before story proposals or manuscript writing."
    Write-Host "Required outputs:"
    Write-Host "- runtime/book-brief.json"
    Write-Host "- runtime/book-dna.json"
    Write-Host "- runtime/layout-profile.json"
    Write-Host "- runtime/approvals/book-brief-approval.json with approved=false until the user accepts the brief"
    Write-Host "The brief must include structured question IDs and answers for writing type, target length/pages, reader, genre, character policy, setting, POV/tense, style, boundaries, and publication package."
  }
  "propose" {
    Write-Host "Goal: expand runtime/book-request.md into book proposals."
    Write-Host "Required outputs:"
    Write-Host "- _workspace/01_proposals.md"
    Write-Host "- one *_proposal.md file at repo root"
  }
  "design-big" {
    Write-Host "Goal: create reviewable full-book architecture, chapter plan, layout plan, and longform state. Do not write manuscript chapters."
    Write-Host "Required outputs:"
    Write-Host "- novel-config.md"
    Write-Host "- design/01_concept_bootstrap.md"
    Write-Host "- design/02_character_core.md"
    Write-Host "- design/03_macro_plot_hooks.md"
    Write-Host "- design/04_book_plan.md"
    Write-Host "- design/05_chapter_plan.md"
    Write-Host "- design/06_layout_plan.md"
    Write-Host "- runtime/approvals/book-plan-approval.json with accepted_targets and approved=false until the user accepts the visible plan"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/layout-plan.json"
    Write-Host "- revision/_state/longform-plan.json"
    Write-Host "- revision/_state/character-state.json"
    Write-Host "- revision/_state/plot-ledger.json"
    Write-Host "- revision/_state/chapter-summaries.json"
    Write-Host "- revision/_state/continuity-ledger.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "- revision/_state/style-profile.json"
    Write-Host "- revision/_state/writing-type-profile.json"
    Write-Host "- revision/_state/genre-structure-template.json"
    Write-Host "- revision/_state/editorial-quality-scorecard.json"
    Write-Host "- revision/_state/llm-adapter-contract.json"
    Write-Host "Stop after these outputs. The user must approve runtime/approvals/book-plan-approval.json before design-small."
  }
  "design-small" {
    Write-Host "Goal: create chapter-range scene and continuity plan after book-plan approval."
    Write-Host "Required approval:"
    Write-Host "- runtime/approvals/book-plan-approval.json must have approved=true"
    Write-Host "Required input state:"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/layout-plan.json"
    Write-Host "- revision/_state/longform-plan.json"
    Write-Host "- revision/_state/character-state.json"
    Write-Host "- revision/_state/plot-ledger.json"
    Write-Host "- revision/_state/continuity-ledger.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "Required outputs:"
    Write-Host "- design/*scene_plan*.md"
    Write-Host "- design/*_character-detail_*.md"
    Write-Host "- design/*_plot-detail_*.md"
    Write-Host "- revision/_workspace/context-saliency-gate_EP*.json"
    Write-Host "- revision/_workspace/context-saliency-gate_EP*.md"
  }
  "create" {
    Write-Host "Goal: draft chapters from design/state files."
    Write-Host "Required input state:"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/character-state.json"
    Write-Host "- revision/_state/plot-ledger.json"
    Write-Host "- revision/_state/knowledge-graph.json"
    Write-Host "- revision/_state/continuity-ledger.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "Required outputs:"
    Write-Host "- revision/_workspace/context-saliency-gate_EP*.json"
    Write-Host "- revision/_workspace/context-saliency-gate_EP*.md"
    Write-Host "- episode/ep001.md and following selected chapter files"
    Write-Host "- revision/_workspace/04_quality-verifier_verdict_EP*.md"
    Write-Host "- revision/_workspace/08_tdk-polisher_issues_EP*.json"
    Write-Host "- revision/_workspace/08_tdk-polisher_report_EP*.md"
    Write-Host "- revision/_workspace/09_tdk-layout_issues_EP*.json"
    Write-Host "- revision/_workspace/09_tdk-layout_report_EP*.md"
    Write-Host "- updated revision/_state/*.json"
  }
  "polish" {
    Write-Host "Goal: run editorial and language polish."
    Write-Host "Required input state:"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/character-state.json"
    Write-Host "- revision/_state/plot-ledger.json"
    Write-Host "- revision/_state/knowledge-graph.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "Required outputs:"
    Write-Host "- revision/_workspace/revision-reviewer_EP*.md"
    Write-Host "- revision/_workspace/07_developmental-editor_report_EP*.md"
    Write-Host "- revision/_workspace/07_continuity-editor_report_EP*.md"
    Write-Host "- revision/_workspace/08_line-editor_report_EP*.md"
    Write-Host "- revision/_workspace/08_copy-editor_report_EP*.md"
    Write-Host "- revision/_workspace/08_tdk-polisher_issues_EP*.json"
  }
  "rewrite" {
    Write-Host "Goal: repair only real structural/quality failures."
    Write-Host "Required input state:"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/character-state.json"
    Write-Host "- revision/_state/plot-ledger.json"
    Write-Host "- revision/_state/knowledge-graph.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "Required outputs:"
    Write-Host "- revision/_workspace/*rewrite*report*.md"
    Write-Host "- revision/_workspace/04_quality-verifier_verdict_EP*.md"
    Write-Host "- revision/_workspace/08_tdk-polisher_issues_EP*.json"
  }
  "export" {
    Write-Host "Goal: build complete review-ready book package."
    Write-Host "Required input state:"
    Write-Host "- revision/_state/open-source-story-model.json"
    Write-Host "- revision/_state/story-bible.json"
    Write-Host "- revision/_state/book-plan.json"
    Write-Host "- revision/_state/chapter-plan.json"
    Write-Host "- revision/_state/layout-plan.json"
    Write-Host "- revision/_state/llm-adapter-contract.json"
    Write-Host "- revision/_state/chapter-continuity-chain.json"
    Write-Host "- revision/_state/context-saliency-map.json"
    Write-Host "Required outputs:"
    Write-Host "- revision/_workspace/11_front-matter_*.md"
    Write-Host "- revision/_workspace/11_front-matter_toc.json"
    Write-Host "- revision/_workspace/11_front-matter_publication-metadata.json"
    Write-Host "- revision/_workspace/12_cover-design_manifest.json"
    Write-Host "- revision/_workspace/14_publication-compliance_verdict_EP*.json"
    Write-Host "- revision/_workspace/10_export-validator_verdict_EP*.json"
    Write-Host "- revision/_workspace/10_export-word_manifest_EP*.json"
    Write-Host "- revision/export/*.docx"
  }
}
