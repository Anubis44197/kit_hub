# Project Config Template

```yaml
project:
  name: "My Novel"
  target_platform: "PRINT_BOOK"          # GENERIC_BOOK | PRINT_BOOK | EBOOK
  target_genre: "genre"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

design_documents:
  bootstrap: "design/my_bootstrap.md"
  character_core: "design/my_character.md"
  character_detail: "design/my_character.md"

chapter_range_table:
  - range: "EP001-EP025"                 # legacy file ids; reader-facing label is chapter
    label: "Part 1"
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

book_mode:
  profile: "print_preview"               # print_preview | ebook
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

book_package:
  front_matter:
    title_page: true
    copyright_page: true
    dedication: false
    preface: true
    table_of_contents: true
  body:
    chapter_ids_use_legacy_episode_files: true
    require_full_arc_resolution: true
    require_character_consistency_tracker: true
  back_matter:
    acknowledgements: false
    author_note: true
  cover:
    brief_required: true
    front_cover_prompt_required: true
    back_cover_copy_required: true
    spine_text_required_when_print: true
  print_readiness:
    trim_size: "A5"
    docx_required: true
    cover_brief_required: true
    compatibility_test_required: true

writing_profile:
  writing_type: "novel"                 # novel | story | novella | essay | memoir | biography | research_book | self_help | business_book | academic
  target_reader: "Turkish adult commercial fiction reader"
  structure_model: "four_act_longform_novel"
  evidence_policy: "fictional; factual claims require source placeholders"

longform:
  target_pages: 360                    # supports 300-500+ page projects
  target_words: 150000
  target_chapters: 60
  words_per_chapter: 2500
  generation_strategy: "chunked_chapter_state"
  state_dir: "revision/_state/"
  require_character_state: true
  require_plot_ledger: true
  require_chapter_summaries: true
  require_style_profile: true
  require_continuity_ledger: true
  require_writing_type_profile: true
  require_editorial_quality_scorecard: true
  max_chapters_per_generation_batch: 3

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
