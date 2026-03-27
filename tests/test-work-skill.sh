#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE='skills/work/SKILL.md'

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
  if rg -Fq -- "$pattern" "$SKILL_FILE"; then
    pass "$name"
  else
    fail "$name"
  fi
}

printf 'Running work skill regression tests...\n\n'

assert_contains 'branch convention remains preferred' 'Prefer branch `task/{id}-{slug}` plus PR title `[{id}] Title` or `({id}) Title`'
assert_contains 'fallback Track-Task documented' 'Track-Task: {id}'
assert_contains 'optional label fallback documented' 'track:{id}'
assert_contains 'explicit batch section documented' '## Explicit Batch PRs'
assert_contains 'repeated Track-Task syntax documented' 'repeat `Track-Task: {id}` once per task'
assert_contains 'max-three batch limit documented' 'max 3 tasks'
assert_contains 'same-project restriction documented' 'same project only'
assert_contains 'implement-only batch restriction documented' 'mode is `implement` for every task'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
