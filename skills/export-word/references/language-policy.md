# Language Policy

## Scope
This policy applies to story content, export inputs, and generated DOCX outputs.

## Rules
- Story/chapter content language: Turkish.
- Skill/agent contract language: English.
- Preserve valid UTF-8 Turkish characters.
- Mojibake or unexplained non-Turkish script usage must be treated as a quality/export risk.

## Enforcement Points
- `tdk-polisher`: Turkish character and encoding safety check in issue report.
- `export-validator`: block print-ready export when encoding/script anomalies are detected.
- `book-exporter`: never normalize or substitute Turkish letters.

## Failure Handling
- If encoding/script anomalies are found, raise `critical` issue and set export status to `BLOCKED`.
- Require manual correction before retry.
