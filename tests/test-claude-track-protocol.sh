#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
CANONICAL_FILE='TRACK.md'
REPO_CLAUDE_FILE='CLAUDE.md'

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

printf 'Running CLAUDE Track protocol regression tests...\n\n'

assert_contains 'canonical protocol documents Track-Task' "$CANONICAL_FILE" 'Track-Task: {id}'
assert_contains 'canonical protocol documents Also-Completed' "$CANONICAL_FILE" 'Also-Completed: {id}'
assert_contains 'canonical protocol documents source of truth' "$CANONICAL_FILE" 'source of truth for task state, task ownership, and task history'

if contains_literal 'See @AGENTS.md' "$REPO_CLAUDE_FILE"; then
  pass 'CLAUDE.md points to AGENTS.md'
else
  fail 'CLAUDE.md does not point to AGENTS.md'
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
