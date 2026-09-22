# Golden Expected Output - story-ledger-keeper

Expected contract for story-ledger-keeper agent outputs.

- Output must be non-empty and strictly formatted JSON matching the ledger update schema.
- Output must not contain placeholder text, TODO markers, or unverified claims.
- Extracted character states, main event summary, and continuity violations must reflect the episode text faithfully.
- Turkish text must remain valid UTF-8 without mojibake.
- Merge script operations must be append-only for events and patch-based for character states.
