---
name: propose
description: "Generate three differentiated book proposals from genre, concept, audience, and publication-format constraints."
prompt_version: "1.0.0"
---

# Propose Skill

## Purpose
Create 3 proposal candidates and help the user pick one.

## Flow
1. Parse inputs: genre, concept, target reader, format, length, and tone.
2. Normalize/validate publication format values (`PRINT_BOOK`, `EBOOK`, `GENERIC_BOOK`).
3. Run research (`domain-researcher`) for genre, reader expectations, and comparable works.
4. Run proposal generation (`proposal-generator`).
5. Present side-by-side comparison and capture user selection.
6. Save selected proposal document and suggest next step (`design-big`).

## Outputs
- `_workspace/00_research/*`
- `_workspace/01_proposals.md`
- `{title}_proposal.md`
