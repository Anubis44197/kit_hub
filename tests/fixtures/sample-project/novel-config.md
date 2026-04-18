# Sample Novel Config

Use this fixture for CI smoke checks only.

```yaml
project:
  name: "Fixture Novel"
  target_platform: "NOVELPIA"
  target_genre: "thriller"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "English"
  disallowed_scripts:
    - "Hangul"
    - "Han"
    - "Hiragana"
    - "Katakana"

book_mode:
  profile: "web_novel"
  enabled: true
  dialogue_style: "quote"

ep_range_table:
  - range: "EP001-EP010"
    label: "Arc 1"
  - range: "EP011-EP025"
    label: "Arc 2"
```
