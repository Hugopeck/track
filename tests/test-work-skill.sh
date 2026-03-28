#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE='skills/work/SKILL.md'

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
  local pattern="$2"
  if contains_literal "$pattern" "$SKILL_FILE"; then
    pass "$name"
  else
    fail "$name"
  fi
}

assert_not_contains() {
  local name="$1"
  local pattern="$2"
  if ! contains_literal "$pattern" "$SKILL_FILE"; then
    pass "$name"
  else
    fail "$name"
  fi
}

printf 'Running work skill regression tests...\n\n'

assert_contains 'branch convention remains preferred' 'Prefer branch `task/{id}-{slug}` plus PR title `[{id}] Title` or `({id}) Title`'
assert_contains 'fallback Track-Task documented' 'Track-Task: {id}'
assert_contains 'optional label fallback documented' 'track:{id}'
assert_contains 'also-completed section documented' '## Also-Completed'
assert_contains 'also-completed syntax documented' 'Also-Completed: {id}'
assert_contains 'also-completed max documented' 'max 2'
assert_not_contains 'no batch PR section' '## Explicit Batch PRs'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
