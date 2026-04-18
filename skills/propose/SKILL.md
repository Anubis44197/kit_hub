---
name: propose
description: "Generate three differentiated web-novel proposals from genre, concept, and target platform constraints."
prompt_version: "1.0.0"
---

# Propose Skill

## Purpose
Create 3 proposal candidates and help the user pick one.

## Flow
1. Parse inputs: genre, concept, platform.
2. Normalize/validate platform values.
3. Run research (`domain-researcher`) for genre/platform/comparable works.
4. Run proposal generation (`proposal-generator`).
5. Present side-by-side comparison and capture user selection.
6. Save selected proposal document and suggest next step (`design-big`).

## Outputs
- `_workspace/00_research/*`
- `_workspace/01_proposals.md`
- `{title}_proposal.md`
