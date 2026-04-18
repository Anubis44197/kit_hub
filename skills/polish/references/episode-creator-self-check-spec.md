# Episode Creator Self-Check Spec

Run deterministic checks after draft generation.

## Required Checks
- repetition ratio
- dialogue/narration balance
- scene transition clarity
- locked fact consistency

## Required Output
- `{WORK_DIR}/_workspace/03_episode-creator_selfcheck_EP{NNN}.json`

## Required Fields
- `episode`
- `repetition_ratio`
- `dialogue_ratio`
- `transition_clarity_score`
- `locked_fact_mismatches`
- `pass` (bool)

## Thresholds
- repetition ratio <= 0.12
- transition clarity >= 80
- locked_fact_mismatches == 0
