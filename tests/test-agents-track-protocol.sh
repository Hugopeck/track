#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
CANONICAL_FILE='skills/init/scaffold/TRACK_PROTOCOL_SECTION.md'
REPO_AGENTS_FILE='AGENTS.md'
SCAFFOLD_AGENTS_FILE='skills/init/scaffold/AGENTS.md'

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

extract_agents_block() {
  local file="$1"
  awk '
    /^<!-- TRACK:START -->$/ { capture=1; next }
    /^<!-- TRACK:END -->$/ { capture=0; exit }
    capture { print }
  ' "$file"
}

printf 'Running AGENTS Track protocol regression tests...\n\n'

assert_contains 'repo AGENTS includes Track block start marker' "$REPO_AGENTS_FILE" '<!-- TRACK:START -->'
assert_contains 'repo AGENTS includes Track block end marker' "$REPO_AGENTS_FILE" '<!-- TRACK:END -->'
assert_contains 'scaffold AGENTS includes Track block start marker' "$SCAFFOLD_AGENTS_FILE" '<!-- TRACK:START -->'
assert_contains 'scaffold AGENTS includes Track block end marker' "$SCAFFOLD_AGENTS_FILE" '<!-- TRACK:END -->'

if diff -u "$CANONICAL_FILE" <(extract_agents_block "$REPO_AGENTS_FILE") >/tmp/track-agents-repo-diff 2>&1; then
  pass 'repo AGENTS block matches canonical protocol'
else
  fail 'repo AGENTS block diverges from canonical protocol'
  cat /tmp/track-agents-repo-diff
fi

if diff -u "$CANONICAL_FILE" <(extract_agents_block "$SCAFFOLD_AGENTS_FILE") >/tmp/track-agents-scaffold-diff 2>&1; then
  pass 'scaffold AGENTS block matches canonical protocol'
else
  fail 'scaffold AGENTS block diverges from canonical protocol'
  cat /tmp/track-agents-scaffold-diff
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
