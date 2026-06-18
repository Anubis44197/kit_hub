# Novel Config

project:
  name: "Boğazda Bir Akşam"
  target_platform: "PRINT_BOOK"
  target_genre: "gizem"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "English"
  tdk_enforcement: true

book_mode:
  profile: "print_preview"
  enabled: true
  dialogue_style: "dash"

create_quality:
  min_characters: 6500
  max_characters: 14000
  dialogue_ratio_min: 0.20
  dialogue_ratio_max: 0.70

book_package:
  front_matter:
    title_page: true
    copyright_page: true
    preface: true
    table_of_contents: true
  cover:
    brief_required: true
    front_cover_prompt_required: true
    back_cover_copy_required: true
  print_readiness:
    trim_size: "A5"
    docx_required: true
    compatibility_test_required: true

writing_profile:
  writing_type: "novel"
  target_reader: "Turkish adult commercial fiction reader"
  structure_model: "four_act_longform_novel"
  evidence_policy: "fictional; factual claims require source placeholders"

longform:
  target_pages: 360
  target_words: 150000
  target_chapters: 60
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
