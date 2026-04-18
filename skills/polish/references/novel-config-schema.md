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
