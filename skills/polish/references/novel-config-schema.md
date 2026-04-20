# Novel Config Schema (Baseline)

This schema defines mandatory fields for `novel-config.md` YAML blocks.

## Required Sections
- `project`
- `language_profile`
- `book_mode`

## `project` Required Fields
- `name`
- `target_platform`
- `target_genre`
- `episode_dir`
- `work_dir`
- `design_dir`

## Canonical `target_platform` Values
- `NOVELPIA`
- `MUNPIA`
- `KAKAO_PAGE`
- `NAVER_SERIES`
- `RIDI`
- `GENERIC_BOOK`

## `language_profile` Required Fields
- `locale`
- `content_language`
- `interface_language`
- `disallowed_scripts`

Rules:
- `locale` must be `tr-TR`.
- `content_language` must be `Turkish`.
- `interface_language` should be `English`.

## `book_mode` Required Fields
- `enabled`
- `profile`
- `dialogue_style`

Canonical profiles:
- `web_novel`
- `print_preview`
- `ebook`

## Optional `ep_range_table`
If present, each item range must match:
- `EPNNN-EPNNN`

Ranges must be non-overlapping.

## Optional `create_quality` Block (Recommended)
If present, these keys are used as hard verifier gates:
- `min_characters` (int)
- `max_characters` (int)
- `min_scene_blocks` (int)
- `dialogue_ratio_min` (0.0-1.0)
- `dialogue_ratio_max` (0.0-1.0)

## Optional `request_contract` Block (Recommended)
If present, verifier must enforce it as a dedicated compliance axis.
Suggested keys:
- `content_objective`
- `min_output_length`
- `must_include` (list)
- `must_avoid` (list)
