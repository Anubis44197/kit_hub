# Third-Party Attribution

KitHub adapts planning patterns from open source writing systems. Unless a file explicitly says otherwise, KitHub does not vendor or embed upstream GUI/runtime source code from these projects. The current integration records patterns as contracts and generated state files.

## Open Source Writing Systems

### Manuskript

- Repository: `https://github.com/olivierkes/manuskript`
- License: GPL-3.0-or-later
- Adapted pattern: character fields, plot fields, plot-step fields, world fields, outline fields, summary levels, POV, goal, status, compile flag, revisions and word/character count.
- KitHub mapping: `revision/_state/open-source-story-model.json.character_model`, `plot_model`, `world_model`, and `outline_model`.

### novelWriter

- Repository: `https://github.com/vkbo/novelWriter`
- License: GPL-3.0
- Adapted pattern: plain-text project tree, novel/plot/character/world roots, chapter and scene documents, synopsis metadata, tags and cross-reference indexing.
- KitHub mapping: `revision/_state/open-source-story-model.json.outline_model` and `cross_reference_model`.

### bibisco

- Repository: `https://github.com/andreafeccomandi/bibisco`
- License: GPL-3.0
- Adapted pattern: premise, fabula, narrative strands, geographic setting, temporal setting, social setting, chapter/scene/revision workflow and deep character understanding.
- KitHub mapping: `revision/_state/open-source-story-model.json.character_model`, `plot_model`, and `world_model`.

### STORM

- Repository: `https://github.com/stanford-oval/storm`
- License: MIT
- Adapted pattern: pre-writing stage, question-driven outline, human steering, source grounding and research-heavy planning workflow.
- KitHub mapping: `revision/_state/open-source-story-model.json.research_outline_model`.

## Policy

- If upstream source code is copied into this repository later, keep it isolated under a clearly named directory and preserve the original license headers.
- If only ideas, data-shape patterns, or workflow contracts are adapted, record the source here and in `skills/polish/references/open-source-novel-editor-patterns.md`.
- Reader-facing book exports must not include upstream attribution text unless the user explicitly asks for a technical appendix.
