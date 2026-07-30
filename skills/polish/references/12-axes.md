# Polish Axes for Turkish Book Production

Every polish, create-verification, and rewrite-verification pass must score these axes with `PASS`, `REWRITE`, or `REVIEW_REQUIRED`. Use severity tags: `CRITICAL`, `MAJOR`, `MINOR`.

## Core 12 Axes

1. `BANNED`
   - Reader output must not contain `EP001`, scene labels, TODO/FIXME, pipeline notes, test notes, fake source claims, or internal file names.

2. `VOICE`
   - Narrator voice, character diction, period register, and emotional distance must stay stable across chapters.

3. `TITLE`
   - Reader-facing chapter titles must be literary and non-technical. Internal ids may exist only in state files and filenames.

4. `SILENCE`
   - Do not explain every feeling. Convert obvious exposition into gesture, pause, image, action, or subtext.

5. `TRANS`
   - Scene and chapter transitions must preserve time, place, cause, and character knowledge.

6. `SCENE`
   - Each chapter must contain concrete scenes, not only summary. Every scene needs purpose, conflict, turn, and consequence.

7. `LOGIC`
   - Timeline, object state, geography, numeric facts, historical facts, and character knowledge must not contradict state ledgers.

8. `SUMMARY`
   - Summary passages must compress only what is already earned. They may not replace major dramatic events promised in the plan.

9. `UNIFORM`
   - Typography, dialogue punctuation, paragraph style, heading style, and front/back matter conventions must follow the selected book profile.

10. `HOOK`
   - Chapter openings and endings must create a concrete question, pressure, discovery, or irreversible change.

11. `OPENING`
   - The first page must establish voice, atmosphere, conflict pressure, and reader promise without dumping plan notes.

12. `MOBILE`
   - Text must remain readable in editor preview and exported DOCX: no oversized paragraphs, no broken Turkish characters, no layout-only artifacts.

## ALIVE Axes

A1. `ALIVE_DIALOGUE`
   - Dialogue must reveal desire, power, fear, or withheld knowledge. Decorative talk must be cut.

A2. `ALIVE_NONVERBAL`
   - Key emotional beats need nonverbal evidence: posture, breath, gaze, touch, rhythm, object handling, spatial movement.

A3. `ALIVE_TENSION`
   - Tension points must change the situation. A scene cannot end with the same emotional and factual state it began with.

A4. `ALIVE_DISTANCE`
   - Interior monologue must match point of view and distance. It may deepen character but must not repeat the same diagnosis.

## Mandatory Verdict Rules

- Any `CRITICAL` failure in `BANNED`, `LOGIC`, `UNIFORM`, Turkish encoding, request compliance, or layout compliance blocks export.
- Any repeated chapter premise, repeated opening pattern, missing new event, or missing state update is `CRITICAL`.
- `PASS` is invalid unless the report names the checked files and the concrete evidence for each axis.
