#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
CANONICAL_FILE='skills/init/scaffold/TRACK_PROTOCOL_SECTION.md'
REPO_CLAUDE_FILE='CLAUDE.md'
SCAFFOLD_CLAUDE_FILE='skills/init/scaffold/CLAUDE_TRACK_SECTION.md'

contains_literal() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -Fq -- "$pattern" "$file"
  else
    grep -Fq -- "$pattern" "$file"
  fi
}

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if contains_literal "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
  fi
}

extract_repo_claude_section() {
  awk '
    /^## Track — Task Coordination$/ { capture=1 }
    capture { print }
  ' "$REPO_CLAUDE_FILE"
}

printf 'Running CLAUDE Track protocol regression tests...\n\n'

assert_contains 'canonical protocol documents Track-Task' "$CANONICAL_FILE" 'Track-Task: {id}'
assert_contains 'canonical protocol documents Also-Completed' "$CANONICAL_FILE" 'Also-Completed: {id}'
assert_contains 'canonical protocol documents source of truth' "$CANONICAL_FILE" 'source of truth for task state, task ownership, and task history'

if diff -u "$CANONICAL_FILE" "$SCAFFOLD_CLAUDE_FILE" >/tmp/track-claude-scaffold-diff 2>&1; then
  pass 'scaffold CLAUDE matches canonical protocol'
else
  fail 'scaffold CLAUDE diverges from canonical protocol'
  cat /tmp/track-claude-scaffold-diff
fi

if diff -u "$CANONICAL_FILE" <(extract_repo_claude_section) >/tmp/track-claude-repo-diff 2>&1; then
  pass 'repo CLAUDE matches canonical protocol'
else
  fail 'repo CLAUDE diverges from canonical protocol'
  cat /tmp/track-claude-repo-diff
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
