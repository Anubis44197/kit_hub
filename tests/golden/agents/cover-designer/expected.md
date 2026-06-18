# Golden Expected Output - cover-designer

Expected contract for `cover-designer` agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must not contain placeholder text, TODO markers, or simulated completion claims except explicit print metadata placeholders.
- Required metadata, verdict tokens, issue arrays, manifests, or report sections must follow the agent/skill contract for this role.
- Turkish cover copy must remain valid UTF-8 and must not contain mojibake markers.
- Visual direction must avoid copyrighted character references and unverifiable marketing claims.

