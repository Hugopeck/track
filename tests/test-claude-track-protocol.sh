#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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

assert_contains 'repo CLAUDE uses Track-Task as primary linkage' 'CLAUDE.md' 'Always add `Track-Task: {id}` to the PR body.'
assert_contains 'repo CLAUDE documents Track-Task' 'CLAUDE.md' 'Track-Task: {id}'
assert_contains 'repo CLAUDE documents Also-Completed' 'CLAUDE.md' 'Also-Completed: {id}'
assert_contains 'scaffold CLAUDE uses Track-Task as primary linkage' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Always add `Track-Task: {id}` to the PR body.'
assert_contains 'scaffold CLAUDE documents Track-Task' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Track-Task: {id}'
assert_contains 'scaffold CLAUDE documents Also-Completed' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Also-Completed:'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
