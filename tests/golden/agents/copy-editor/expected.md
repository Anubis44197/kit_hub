# Golden Expected Output - copy-editor

Expected contract for copy-editor agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, issue table, correction policy, remaining risks, and PASS/REWRITE/BLOCKED verdict.
- Output must check TDK-sensitive spelling, punctuation, dialogue style, terminology consistency, and mojibake absence.
- Turkish story text must remain valid UTF-8 and must not contain mojibake markers.
