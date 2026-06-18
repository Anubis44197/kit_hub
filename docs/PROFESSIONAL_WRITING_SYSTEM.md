# Professional Writing System

The application is structured as a book-production pipeline, not a single prompt.

## Supported Work Types
The profile layer supports novels, stories, novellas, children's books, young adult fiction, fantasy, science fiction, mystery/thriller, romance, historical fiction, essays, memoir, biography, research books, self-help, business books, and academic-style manuscripts.

## How Long Books Stay Coherent
For 200, 300, 500+ page targets, generation is chunked. The AI must keep and update:
- longform plan
- writing type profile
- structure template
- character state
- plot or argument ledger
- chapter summaries
- continuity ledger
- style profile
- editorial quality scorecard

The model writes chapter batches, updates state, then continues from the current state. This is how character consistency, plot causality, chapter order, and style continuity are preserved.

## Editorial Chain
- Developmental editor: structure, promise, pacing, act design.
- Continuity editor: timeline, character knowledge, objects, locations, unresolved threads.
- Line editor: voice, rhythm, scene-level prose quality.
- Copy editor: Turkish grammar, punctuation, dialogue style, consistency.
- Research/citation auditor: nonfiction evidence discipline.
- Final proofreader: front matter, export readiness, final formatting.

## Production Boundary
The repository includes a deterministic local adapter so the pipeline can be tested without paid model access. Real AI generation is connected by replacing the command in `runtime/runner-config.json`; the provider command must emit the same artifacts and state files.
