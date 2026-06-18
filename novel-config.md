# Novel Config

project:
  name: "Konu Bekleniyor"
  target_platform: "PRINT_BOOK"
  target_genre: "user_defined_after_topic"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "Turkish"
  tdk_enforcement: true

book_mode:
  profile: "topic_required"
  enabled: false
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
  writing_type: "user_defined_after_topic"
  target_reader: "user_defined_after_topic"
  structure_model: "selected_after_topic"
  evidence_policy: "fictional; factual claims require source placeholders"

longform:
  target_pages: 0
  target_words: 0
  target_chapters: 0
  generation_strategy: "topic_required_before_generation"
  state_dir: "revision/_state/"
  require_character_state: true
  require_plot_ledger: true
  require_chapter_summaries: true
  require_style_profile: true
  require_continuity_ledger: true
  require_writing_type_profile: true
  require_editorial_quality_scorecard: true
  max_chapters_per_generation_batch: 3
