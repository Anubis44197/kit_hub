# Word Compatibility Test Plan

This plan validates DOCX outputs produced by `export-word`.

## Goal
Ensure exported files open correctly in major Word-compatible clients and preserve required formatting.

## Test Matrix
- Microsoft Word (Windows)
- Microsoft Word (Mac)
- LibreOffice Writer
- Google Docs import

## Test Scenarios
1. Single episode export (`single_docx`)
2. Range export merged (`single_docx`)
3. Range export split (`multi_docx`)
4. Dialogue-heavy chapter
5. Long paragraph chapter
6. Turkish character stress sample (dotless i, dotted I, s-cedilla, g-breve, c-cedilla, o-umlaut, u-umlaut)

## Validation Checklist
- File opens without repair prompt.
- Chapter headings keep style and hierarchy.
- Paragraph indent and line spacing match style profile.
- Dialogue block separation is preserved.
- Scene-break marker rendering is preserved.
- Page size and margin settings are preserved.
- Turkish characters are preserved exactly.
- No accidental text truncation or ordering issue.

## Result Format
Create test report:
- `{WORK_DIR}/_workspace/10_export-word_compatibility_report.md`

Report fields:
- `client`
- `scenario`
- `pass` (bool)
- `issues`
- `severity`
- `repro_steps`
