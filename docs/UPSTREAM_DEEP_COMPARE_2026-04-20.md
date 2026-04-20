# Upstream Deep Compare Report (2026-04-20)

## Scope
- Upstream: `C:\Users\90535\Desktop\awesome-novel-studio-upstream` (`bb72065`)
- Current repo: `C:\Users\90535\Desktop\kit_hub` (`8e7f884`)
- Method: tracked file set compare + hash compare + line-level delta scan.

## 1) File-Set Parity
- Upstream tracked files: `47`
- kit_hub tracked files: `176`
- Files present in upstream but missing in kit_hub: `0`
- Extra tracked files in kit_hub: `129`

Result:
- Upstream file set is fully covered by path presence.
- kit_hub is a superset at tracked-file level.

## 2) Exact-Match Files (Hash-identical)
- `.claude/settings.json`
- `.nojekyll`
- `LICENSE`

Exact matches: `3 / 47`.

## 3) Changed Common Files
- Common files: `47`
- Changed content among common files: `44`

Key observation:
- Upstream common file paths mostly exist, but contents are heavily modified in kit_hub.

## 4) Structural Count Differences
- Agents:
  - Upstream: `18`
  - kit_hub: `23`
- Skill directories:
  - Upstream: `10`
  - kit_hub: `11`

## 5) Severe Content Contraction (Ratio < 0.60)
Below files exist in both repos but kit_hub content is significantly shorter than upstream:

- `README_KO.md` (`0.02`)
- `skills/design/references/genre-dna-framework.md` (`0.05`)
- `skills/polish/references/12-axes.md` (`0.06`)
- `skills/design-big/SKILL.md` (`0.06`)
- `skills/design-small/SKILL.md` (`0.07`)
- `skills/plot-hook/SKILL.md` (`0.07`)
- `skills/propose/SKILL.md` (`0.11`)
- `skills/create/SKILL.md` (`0.25`)
- `skills/polish/SKILL.md` (`0.21`)
- `skills/rewrite/SKILL.md` (`0.17`)
- `agents/quality-verifier.md` (`0.29`)
- `agents/episode-creator.md` (`0.29`)
- `index.html` (`0.42`)

Note:
- Ratio = `kit_hub line count / upstream line count`.

## 6) Metadata/Plugin Identity Divergence
`plugin.json` and `marketplace.json` are not aligned with upstream identity metadata:
- Upstream plugin identity: `novel-studio` / `awesome-ai-studio` / `MJbae`
- kit_hub plugin identity: `novel-engine` / `local-writing-studio` / `local-dev-team`

## 7) Added Capability Surface in kit_hub (not in upstream)
kit_hub includes additional tracked modules absent in upstream:
- New agents: `tdk-polisher`, `tdk-layout-agent`, `export-approval-gate`, `export-validator`, `book-exporter`
- Runner/CI stack: `scripts/run_pipeline.ps1`, `scripts/install.ps1`, `scripts/ci/*`
- Contract and ops docs under `docs/`
- Regression/golden fixtures under `tests/`

## 8) Final Comparison Verdict
- File-path coverage of upstream: **complete** (no missing upstream tracked file paths).
- Content parity with upstream: **not equivalent** (44/47 common files changed).
- Current state is **upstream-derived but not upstream-identical**.
