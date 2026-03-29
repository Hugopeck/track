#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TRACK_MD="$ROOT_DIR/TRACK.md"
AGENTS_FILE="$ROOT_DIR/AGENTS.md"

if [[ ! -f "$TRACK_MD" ]]; then
  printf 'Missing canonical Track documentation: %s\n' "$TRACK_MD" >&2
  exit 1
fi

# Replace content between <!-- TRACK:START --> and <!-- TRACK:END --> markers
# in the target file with the contents of TRACK.md.
render_track_section() {
  local target_file="$1" temp_file
  temp_file="$(mktemp)"

  if ! grep -Fq '<!-- TRACK:START -->' "$target_file"; then
    printf 'No TRACK:START marker found in %s\n' "$target_file" >&2
    rm -f "$temp_file"
    exit 1
  fi

  awk '
    /^<!-- TRACK:START -->$/ { exit }
    { print }
  ' "$target_file" > "$temp_file"

  printf '<!-- TRACK:START -->\n' >> "$temp_file"
  cat "$TRACK_MD" >> "$temp_file"
  printf '<!-- TRACK:END -->\n' >> "$temp_file"
  mv "$temp_file" "$target_file"
}

render_track_section "$AGENTS_FILE"
