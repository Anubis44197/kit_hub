# Sample Novel Config

Use this fixture for CI smoke checks only.

```yaml
project:
  name: "Fixture Novel"
  target_platform: "PRINT_BOOK"
  target_genre: "thriller"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "English"

book_mode:
  profile: "print_preview"
  enabled: true
  dialogue_style: "quote"

book_package:
  front_matter:
    title_page: true
    copyright_page: true
    dedication: false
    preface: true
    table_of_contents: true
  cover:
    brief_required: true
    back_cover_copy_required: true
  print_readiness:
    trim_size: "A5"
    docx_required: true
    compatibility_test_required: true

chapter_range_table:
  - range: "EP001-EP010"
    label: "Arc 1"
  - range: "EP011-EP025"
    label: "Arc 2"
```
