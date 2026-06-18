# Golden Expected Output - research-citation-auditor

Expected contract for research-citation-auditor agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, claim table, source status, high-stakes warnings, and PASS/REWRITE/BLOCKED verdict.
- Output must separate sourced claims, author opinion, invented examples, and placeholders.
- Output must block unsourced high-stakes factual claims presented as verified.
