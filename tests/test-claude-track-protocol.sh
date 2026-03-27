#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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
  if rg -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
  fi
}

printf 'Running CLAUDE Track protocol regression tests...\n\n'

assert_contains 'repo CLAUDE prefers task branch' 'CLAUDE.md' 'Prefer branch `task/{id}-{slug}` for the task before opening the PR.'
assert_contains 'repo CLAUDE documents Track-Task fallback' 'CLAUDE.md' 'Track-Task: {id}'
assert_contains 'repo CLAUDE mentions explicit batch body' 'CLAUDE.md' 'repeated `Track-Task:` lines'
assert_contains 'repo CLAUDE documents batch constraints' 'CLAUDE.md' 'at most 3 tasks, same project, `implement` mode only'
assert_contains 'scaffold CLAUDE prefers task branch' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Prefer branch `task/{id}-{slug}` for the task before opening the PR.'
assert_contains 'scaffold CLAUDE documents Track-Task fallback' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Track-Task: {id}'
assert_contains 'scaffold CLAUDE includes batch example' 'skills/init/scaffold/CLAUDE_TRACK_SECTION.md' 'Example explicit batch PR:'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
