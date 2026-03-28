#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CANONICAL_FILE="$ROOT_DIR/skills/init/scaffold/TRACK_PROTOCOL_SECTION.md"
REPO_AGENTS_FILE="$ROOT_DIR/AGENTS.md"
SCAFFOLD_AGENTS_FILE="$ROOT_DIR/skills/init/scaffold/AGENTS.md"
SCAFFOLD_CLAUDE_FILE="$ROOT_DIR/skills/init/scaffold/CLAUDE_TRACK_SECTION.md"
REPO_CLAUDE_FILE="$ROOT_DIR/CLAUDE.md"

if [[ ! -f "$CANONICAL_FILE" ]]; then
  printf 'Missing canonical protocol file: %s\n' "$CANONICAL_FILE" >&2
  exit 1
fi

render_agents_file() {
  local target_file="$1"
  {
    printf '<!-- TRACK:START -->\n'
    cat "$CANONICAL_FILE"
    printf '<!-- TRACK:END -->\n'
  } > "$target_file"
}

render_repo_claude() {
  local temp_file
  temp_file="$(mktemp)"

  if ! rg -Fq '## Track — Task Coordination' "$REPO_CLAUDE_FILE"; then
    printf 'Missing Track section in %s\n' "$REPO_CLAUDE_FILE" >&2
    rm -f "$temp_file"
    exit 1
  fi

  awk '
    /^## Track — Task Coordination$/ { exit }
    { print }
  ' "$REPO_CLAUDE_FILE" > "$temp_file"

  cat "$CANONICAL_FILE" >> "$temp_file"
  mv "$temp_file" "$REPO_CLAUDE_FILE"
}

cat "$CANONICAL_FILE" > "$SCAFFOLD_CLAUDE_FILE"
render_agents_file "$REPO_AGENTS_FILE"
render_agents_file "$SCAFFOLD_AGENTS_FILE"
render_repo_claude
