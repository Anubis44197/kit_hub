#!/usr/bin/env bash
set -euo pipefail

CFG="${1:-tests/fixtures/sample-project/novel-config.md}"

echo "[config-validate] file: $CFG"
test -f "$CFG"

need_key() {
  local k="$1"
  grep -qE "^[[:space:]]*${k}:[[:space:]]*" "$CFG" || {
    echo "Missing required key: $k"
    exit 1
  }
}

need_key "project"
need_key "name"
need_key "target_platform"
need_key "target_genre"
need_key "episode_dir"
need_key "work_dir"
need_key "design_dir"

need_key "language_profile"
need_key "locale"
need_key "content_language"
need_key "interface_language"
need_key "disallowed_scripts"

need_key "book_mode"
need_key "enabled"
need_key "profile"

platform="$(grep -E "^[[:space:]]*target_platform:[[:space:]]*" "$CFG" | head -n1 | sed -E 's/.*:[[:space:]]*\"?([^\"#]+)\"?.*/\1/' | tr -d ' ')"
case "$platform" in
  NOVELPIA|MUNPIA|KAKAO_PAGE|NAVER_SERIES|RIDI|GENERIC_BOOK) ;;
  *)
    echo "Invalid target_platform: $platform"
    exit 1
    ;;
esac

locale="$(grep -E "^[[:space:]]*locale:[[:space:]]*" "$CFG" | head -n1 | sed -E 's/.*:[[:space:]]*\"?([^\"#]+)\"?.*/\1/' | tr -d ' ')"
[ "$locale" = "tr-TR" ] || { echo "Invalid locale: $locale"; exit 1; }

content_lang="$(grep -E "^[[:space:]]*content_language:[[:space:]]*" "$CFG" | head -n1 | sed -E 's/.*:[[:space:]]*\"?([^\"#]+)\"?.*/\1/' | tr -d ' ')"
[ "$content_lang" = "Turkish" ] || { echo "Invalid content_language: $content_lang"; exit 1; }

profile="$(grep -E "^[[:space:]]*profile:[[:space:]]*" "$CFG" | head -n1 | sed -E 's/.*:[[:space:]]*\"?([^\"#]+)\"?.*/\1/' | tr -d ' ')"
case "$profile" in
  web_novel|print_preview|ebook) ;;
  *)
    echo "Invalid book_mode.profile: $profile"
    exit 1
    ;;
esac

echo "[config-validate] done"
