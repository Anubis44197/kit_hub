# Golden Expected Output - line-editor

Expected contract for line-editor agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, examples, revision targets, score deltas, and PASS/REWRITE/BLOCKED verdict.
- Output must preserve established facts, character knowledge, and style profile.
- Turkish story text must remain valid UTF-8 and must not contain mojibake markers.
