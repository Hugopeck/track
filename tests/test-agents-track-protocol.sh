#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
CANONICAL_FILE='TRACK.md'
REPO_AGENTS_FILE='AGENTS.md'

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

extract_track_block() {
  local file="$1"
  awk '
    /^<!-- TRACK:START -->$/ { capture=1; next }
    /^<!-- TRACK:END -->$/ { capture=0; exit }
    capture { print }
  ' "$file"
}

printf 'Running AGENTS Track protocol regression tests...\n\n'

assert_contains 'TRACK.md exists and has Track heading' "$CANONICAL_FILE" '## Track — Task Coordination'
assert_contains 'repo AGENTS includes Track block start marker' "$REPO_AGENTS_FILE" '<!-- TRACK:START -->'
assert_contains 'repo AGENTS includes Track block end marker' "$REPO_AGENTS_FILE" '<!-- TRACK:END -->'

if diff -u "$CANONICAL_FILE" <(extract_track_block "$REPO_AGENTS_FILE") >/tmp/track-agents-repo-diff 2>&1; then
  pass 'repo AGENTS Track block matches TRACK.md'
else
  fail 'repo AGENTS Track block diverges from TRACK.md'
  cat /tmp/track-agents-repo-diff
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
