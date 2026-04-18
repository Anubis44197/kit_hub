# Test Run Findings (2026-04-18)

Scope:
- User-side IDE run for EP001 flow verification.
- Intended workspace: `C:\Users\90535\Desktop\kit_hub_run\test-run`

## Critical Findings

1. Wrong workspace path used during run
- Observed path: `C:\Users\90535\Desktop\kit_hub-main\test-run\...`
- Expected path: `C:\Users\90535\Desktop\kit_hub_run\test-run\...`
- Risk: results are not from the intended clean clone and can hide environment drift.

2. Turkish text encoding is broken (mojibake)
- `ep001.md` contains corrupted characters instead of valid Turkish letters.
- Risk: TDK validation and publication quality become invalid.

3. `08_tdk-polisher_issues_EP001.json` does not follow required contract
- Observed schema uses `issues_found`/`type`/`correction` style fields.
- Required contract expects `issues[]` with:
  - `id`
  - `issue_type`
  - `severity`
  - `span`
  - `original_text`
  - `suggested_text`
  - `auto_fixable`
- Risk: downstream gate consumers cannot parse reliably.

4. `09_tdk-layout_issues_EP001.json` does not follow required contract
- Observed schema uses `layout_issues` and non-standard fields.
- Required contract expects `issues[]` with:
  - `id`
  - `layout_issue_type`
  - `severity`
  - `span`
  - `detail`
  - `auto_fixable`
- Risk: layout gate and export validators cannot consume deterministic output.

5. `quality-verifier` output is incomplete for strict contract usage
- Verdict exists (`PASS`) but report is simplified and lacks stricter metadata structure expected by hardened flow references.
- Risk: false-positive pass decisions in automated pipelines.

6. Script-policy check statement is incomplete
- Output note mentioned only partial prohibited set in text ("Hangul/Katakana").
- Required disallowed set is: Hangul, Han, Hiragana, Katakana.
- Risk: policy drift and incomplete compliance checks.

## Immediate Fix Plan

1. Re-run in correct workspace only:
- `C:\Users\90535\Desktop\kit_hub_run\test-run`

2. Force UTF-8 read/write behavior for all generated files.

3. Regenerate EP001 artifacts using strict repo contracts:
- `08_tdk-polisher_issues_EP001.json`
- `09_tdk-layout_issues_EP001.json`
- `quality-verifier_EP001.md`
- `episode/ep001.md` (canonical writeback from layout output when `book_mode.enabled=true`)

4. Re-validate by inspecting full raw file contents, not summary text only.

## Status Update (After Repair Run)

Resolved:
- Workspace path corrected to `C:\Users\90535\Desktop\kit_hub_run\test-run`.
- Turkish mojibake issue resolved in `episode/ep001.md` (clean Turkish characters provided).
- `08_tdk-polisher_issues_EP001.json` repaired to contract shape with required top-level metadata.
- `09_tdk-layout_issues_EP001.json` repaired to contract issue-item shape.
- Enum normalization completed:
  - `issue_type`: `PUNCTUATION`
  - `layout_issue_type`: `PARAGRAPH_SPACING`
- Mode normalization completed:
  - `mode`: `CREATE`
- Severity normalization completed:
  - allowed set only: `critical | major | minor`
- Span normalization completed:
  - `span`: `{ "start_line": <int>, "end_line": <int> }`

Still Open:
- Export gate flow (`export-approval-gate` + `export-validator` + manifest) has not been executed yet in this external test run.
- `quality-verifier` markdown remains minimal; not yet upgraded to richer runtime metadata format in the external run artifacts.

Next Verification Target:
1. Run export scenario with approval=false and verify `BLOCKED` + `E_EXPORT_APPROVAL`.
2. Run export scenario with approval=true and verify `READY`/`EXPORTED` manifest output.
3. Append findings from both scenarios into this file.

## Export Gate Test Update (EP001)

Observed from external run:
- Final validator state reported as `READY`.
- Manifest reported:
  - `source_text`: `revision/_workspace/09_tdk-layout_bookmode_EP001.md`
  - `output_docx`: `revision/export/EP001.docx`
  - `profile`: `web_novel`
  - `status`: `EXPORTED`
- Summary reported export success and expected source/profile linkage.

Assessment:
- Scenario-2 target is satisfied at report level (`READY` + `EXPORTED`).
- Scenario-1 (`approval=false` => `BLOCKED` + `E_EXPORT_APPROVAL`) was claimed as executed in sequence, but raw blocked-state file content was not provided in the final evidence bundle.

Residual verification gap:
- Capture and archive explicit Scenario-1 validator output lines showing:
  - `Verdict: BLOCKED`
  - `Error Code: E_EXPORT_APPROVAL`

## Export Gate Evidence Closure

Scenario-1 raw validator evidence received:
- `Verdict: BLOCKED`
- `Error Code: E_EXPORT_APPROVAL`
- `Reason: explicit user consent missing`

Final export-gate verification status:
- Scenario-1 (approval=false): VERIFIED
- Scenario-2 (approval=true): VERIFIED
- EP001 export gate behavior: PASS (fully validated)

## DOCX Export Validation Risk (Critical)

Observed from external report:
- `revision/export/EP001.docx` size reported as `32 bytes`.

Assessment:
- A valid DOCX is a ZIP-based Office package and is normally at least several KB.
- `32 bytes` strongly indicates placeholder/truncated/invalid output, not a real Word document package.
- Therefore prior `Overall: PASS` compatibility claim is not reliable.

Status:
- DOCX generation quality: FAILED (critical)
- Export gate logic: still VERIFIED

Required proof for closure:
1. File magic header must start with `PK` (`50 4B 03 04`).
2. Archive must open as ZIP.
3. `word/document.xml` must exist inside package.
4. File size should be realistically non-trivial (not tiny placeholder bytes).

## DOCX Export Integrity Closure

External evidence received:
- File size: `14727` bytes
- Header bytes: `50 4B 03 04 14 00 06 00`
- ZIP structure includes:
  - `[Content_Types].xml`
  - `_rels/.rels`
  - `word/document.xml`
  - `word/_rels/document.xml.rels`
  - `word/theme/theme1.xml`
  - `word/settings.xml`
  - `word/styles.xml`
  - `word/webSettings.xml`
  - `word/fontTable.xml`
  - `docProps/core.xml`
  - `docProps/app.xml`
- Manifest updated with:
  - `status: EXPORTED`
  - `file_exists: true`
  - `file_size_bytes: 14727`
- Compatibility report marked overall PASS with strict checks.

Final status:
- Export gate behavior: PASS
- DOCX structural integrity: PASS
- EP001 external end-to-end validation: PASS

## Core Pipeline Validation - EP002

Observed outputs:
- `08_tdk-polisher_issues_EP002.json`: contract fields present, enum/severity/span format compliant.
- `09_tdk-layout_issues_EP002.json`: layout issue schema compliant.
- `quality-verifier_EP002.md`: verdict reported as `PASS`.
- Canonical writeback completed:
  - `episode/ep002.md` generated from create->tdk->layout->verifier flow under `book_mode.enabled=true`.

Result:
- EP002 core pipeline behavior: PASS
- No blocking contract failure reported in external run artifacts.
