# Language Policy

## Scope
This policy applies to story content, export inputs, and generated DOCX outputs.

## Rules
- Story/chapter content language: Turkish.
- Skill/agent contract language: English.
- Disallowed scripts in story content:
  - Hangul
  - Han
  - Hiragana
  - Katakana

## Enforcement Points
- `tdk-polisher`: script safety check in issue report.
- `export-validator`: block export when disallowed scripts are detected.
- `book-exporter`: never normalize or substitute Turkish letters.

## Failure Handling
- If disallowed scripts are found, raise `critical` issue and set export status to `BLOCKED`.
- Require manual correction before retry.
