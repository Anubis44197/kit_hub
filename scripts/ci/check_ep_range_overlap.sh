#!/usr/bin/env bash
set -euo pipefail

CFG="${1:-tests/fixtures/sample-project/novel-config.md}"
echo "[range-check] file: $CFG"
test -f "$CFG"

ranges="$(grep -oE 'EP[0-9]{3}-EP[0-9]{3}' "$CFG" || true)"
[ -z "$ranges" ] && { echo "[range-check] no ranges found, skip"; exit 0; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r r; do
  s="${r%-*}"
  e="${r#*-}"
  s="${s#EP}"
  e="${e#EP}"
  echo "${s} ${e} ${r}" >> "$tmp"
done <<< "$ranges"

awk '
{
  s[NR]=$1+0; e[NR]=$2+0; raw[NR]=$3;
  if (s[NR] > e[NR]) {
    printf("Invalid range order: %s\n", raw[NR]);
    bad=1;
  }
}
END{
  for(i=1;i<=NR;i++){
    for(j=i+1;j<=NR;j++){
      if(!(e[i] < s[j] || e[j] < s[i])){
        printf("Overlapping ranges: %s and %s\n", raw[i], raw[j]);
        bad=1;
      }
    }
  }
  if(bad) exit 1;
}
' "$tmp"

echo "[range-check] done"
