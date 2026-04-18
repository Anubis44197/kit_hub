# Project Config Template

```yaml
project:
  name: "My Novel"
  target_platform: "NOVELPIA"
  target_genre: "genre"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

design_documents:
  bootstrap: "design/my_bootstrap.md"
  character_core: "design/my_character.md"
  character_detail: "design/my_character.md"

ep_range_table:
  - range: "EP001-EP025"
    label: "Arc 1"
    plot_guide: "design/my_plot-hook.md"

guard_rails:
  - "Immutable project rule"

custom_axes:
  SAMPLE_AXIS: "Project-specific diagnostic axis"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "English"
  tdk_enforcement: true
  tdk_polisher_mandatory: true
  preserve_literary_voice: true
  disallowed_scripts:
    - "Hangul"
    - "Han"
    - "Hiragana"
    - "Katakana"

book_mode:
  profile: "web_novel"                   # web_novel | print_preview | ebook
  enabled: true
  layout_agent_mandatory_when_enabled: true
  paragraph_max_lines_hint: 8
  dialogue_style: "quote"  # quote | dash
  chapter_heading_style: "BOLUM"
  avoid_wall_of_text: true
  line_end_split_check: true

export_word:
  enabled: true
  require_explicit_user_approval: true
  block_on_critical_tdk_or_layout: true
  default_episode_range: "EP001-EP025"
  output_strategy: "single_docx"          # single_docx | multi_docx
  output_dir: "export/"
  style_profile: "novel-book-default"
  chapter_segmentation: "by_episode"       # by_episode | by_arc
  page_end_behavior: "chapter_new_page"    # auto | chapter_new_page
  summary_report_required: true
  compatibility_test_required: true

security_profile:
  name: "offline_first_secure"
  network_egress: "blocked"          # blocked | allowlisted
  external_upload: "blocked"         # blocked | allowed
  allowlisted_domains: []
  pii_redaction_in_reports: true
  workdir_isolation_required: true

source_mode:
  enabled: false
  attribution_required: true
  copyright_check_required: true
```
