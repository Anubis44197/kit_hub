---
name: export-word
description: "Export a complete validated book package to DOCX using approval, front matter, cover brief, and book-mode style gates."
prompt_version: "1.0.0"
---

# Export Word Skill

## Purpose
Export book text to `.docx` only after explicit user approval and pre-export validation.

## Language Policy
- Chapter/story content language must be Turkish.
- Skill/agent contracts and tooling instructions remain English.
- Preserve valid UTF-8 Turkish characters; mojibake or unexplained non-Turkish script usage must block print-ready export.

## Security, Privacy, and Copyright Policy
- Apply PII redaction policy to reports/manifests: `references/pii-redaction-policy.md`.
- Apply copyright checklist when source mode is enabled: `references/copyright-compliance-checklist.md`.
- Enforce offline-first profile unless explicitly overridden: `references/offline-first-secure-profile.md`.
- Respect WORK_DIR isolation boundaries: `references/workdir-isolation-policy.md`.

## Runtime Metadata Contract
- Every export run must have a `run_id` in format: `RUN-YYYYMMDD-HHMMSS-XXXX`.
- Every pipeline step must have a `step_id` in format: `export-word-<step-number>`.
- All generated reports must include `run_id` and `step_id` in header metadata.
- Export flow must update `{WORK_DIR}/_workspace/run-summary.json` after each step.
- For blocked/failed steps, `error_code` must come from `references/error-code-glossary.md`.
- Export flow must emit `{WORK_DIR}/_workspace/pipeline-metrics.json`.
- Export flow must emit `{WORK_DIR}/_workspace/pipeline-bottleneck-report.md`.

## Model Routing Policy
- Model selection must follow:
  - `skills/polish/references/model-capability-matrix.md`
  - `skills/polish/references/model-fallback-timeout-policy.md`
- A/B prompt experiments must follow:
  - `skills/polish/references/prompt-ab-experiment-spec.md`

## Model Adapter Contract
- Shared task envelope must follow:
  - `skills/polish/references/shared-task-schema.md`
- Agent/skill mapping must follow:
  - `skills/polish/references/agent-skill-schema-mapping.md`
- Adapter behavior must follow:
  - `skills/polish/references/adapter-claude-codex.md`
  - `skills/polish/references/adapter-generic-ide-model.md`
- Verdict/report format must follow:
  - `skills/polish/references/verdict-report-standard.md`
- Inter-agent handoff payload must follow:
  - `skills/polish/references/handoff-contract.md`
- Official language/publication rules must follow:
  - `skills/polish/references/tdk-official-writing-rules.md`
  - `skills/polish/references/tdk-print-submission-rules.md`
  - `skills/polish/references/source-citation-style-tdk.md`
  - `skills/polish/references/publication-metadata-checklist.md`
  - `skills/polish/references/isbn-kunye-bandrol-checklist.md`

## Pipeline
1. Approval check (`export-approval-gate`) [mandatory]
2. Export readiness validation (`export-validator`) [mandatory]
3. Source validation (`tdk-polisher` and `tdk-layout-agent` artifacts) [mandatory]
4. Front matter build/validation (`front-matter-editor`) [mandatory for complete book package]
5. Cover package brief (`cover-designer`) [mandatory for complete book package]
6. Publication metadata compliance (`publication-compliance-checker`) [mandatory before print-ready claim]
7. DOCX build (`book-exporter`)
8. Export summary report

## Source Priority
- If `book_mode.enabled=true`, source text must come from:
  - `{WORK_DIR}/_workspace/09_tdk-layout_bookmode_EP{NNN}.md`
- If `book_mode.enabled=false`, source text must come from:
  - `{WORK_DIR}/_workspace/08_tdk-polisher_polished_EP{NNN}.md`

## Mandatory Gates
- Do not create `.docx` without explicit user consent artifact.
- If any critical TDK/layout issue remains unresolved, block export.
- If selected episode source file is missing, stop with `artifact-missing` error.
- Do not run `book-exporter` unless `export-validator` verdict is `READY`.
- Do not mark the book package print-ready unless front matter and cover design manifest exist.
- Do not mark the book package print-ready unless publication-compliance verdict is `READY`.
- Do not invent ISBN, publisher, author identity, copyright owner, barcode, or final cover artwork.
- Do not claim bandrol completion, ministry approval, ISBN assignment, or publisher approval from local export.

## Outputs
- `{WORK_DIR}/export/{project_name}_EP{RANGE}.docx`
- `{WORK_DIR}/_workspace/11_front-matter_*.md`
- `{WORK_DIR}/_workspace/11_front-matter_toc.json`
- `{WORK_DIR}/_workspace/12_cover-design_brief.md`
- `{WORK_DIR}/_workspace/12_cover-design_manifest.json`
- `{WORK_DIR}/_workspace/14_publication-compliance_report_EP{RANGE}.md`
- `{WORK_DIR}/_workspace/14_publication-compliance_verdict_EP{RANGE}.json`
- `{WORK_DIR}/_workspace/10_export-validator_report_EP{RANGE}.md`
- `{WORK_DIR}/_workspace/10_export-validator_verdict_EP{RANGE}.json`
- `{WORK_DIR}/_workspace/10_export-word_report_EP{RANGE}.md`
- `{WORK_DIR}/_workspace/10_export-word_manifest_EP{RANGE}.json`

## Batch Export Mode
- Supported range inputs:
  - single: `EP007`
  - continuous range: `EP001-EP025`
  - list: `EP001,EP003,EP008`
- Output strategy:
  - `single_docx`: merge selected episodes into one DOCX
  - `multi_docx`: one DOCX per selected episode
- Deterministic file naming:
  - single: `{project_name}_EP{RANGE}.docx`
  - multi: `{project_name}_EP{NNN}.docx`
- Manifest must include:
  - `batch_mode`
  - `selected_episodes`
  - `output_strategy`
  - `produced_files`

## Manifest Contract
- `project_name`
- `episode_range`
- `source_mode` (`book_mode` | `tdk_only`)
- `source_files`
- `style_profile`
- `approval_artifact`
- `front_matter_files`
- `cover_design_manifest`
- `publication_compliance_verdict`
- `blocked` (bool)
- `block_reasons`
- `output_docx_path`

## Export Summary Report Contract
The summary report must include:
- selected episode range
- selected episodes list (resolved)
- output strategy (`single_docx` or `multi_docx`)
- approval verdict and artifact id
- export-validator verdict
- source mode and source files
- applied style profile name
- front matter status
- cover brief status
- publication metadata / ISBN / kunye compliance status
- block reasons (if blocked)
- produced docx path (if success)
