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

assert_contains 'tracked mode documented' '`tracked` — the session is attached to a specific task'
assert_contains 'untracked mode documented' '`untracked` — no task was supplied and no tracked context safely applies'
assert_contains 'empty mode documented' '`empty` — no open tasks exist'
assert_contains 'mode promotion rule documented' 'The only allowed mode change is `untracked` → `tracked` via deterministic'
assert_contains 'untracked work explicitly valid' 'Untracked work is valid. Do not force queue selection from `TODO.md`.'
assert_contains 'tracked session section documented' '## Tracked Session'
assert_contains 'untracked session section documented' '## Untracked Session'
assert_contains 'deterministic auto-patch section documented' '## Deterministic Auto-Patch'
assert_contains 'track-start remains documented' 'bash .track/scripts/track-start.sh {id}'
assert_contains 'tracked PR linkage documented' 'For tracked PRs, keep `Track-Task: {id}` as the primary body linkage.'
assert_contains 'evidence label MET documented' '`MET`'
assert_contains 'evidence label PARTIAL documented' '`PARTIAL`'
assert_contains 'evidence label UNVERIFIED documented' '`UNVERIFIED`'
assert_contains 'reference file documented' 'references/session-handoff.md'
assert_contains 'do not pick from TODO documented' 'Do not pick a task from `TODO.md`.'
assert_not_contains 'quick operations section removed' '## Quick Operations'
assert_not_contains 'link quick operation removed' '### `link` — retroactive branch attribution'
assert_not_contains 'context quick operation removed' '### `context` — append to task notes'
assert_not_contains 'pick mode removed' '`pick` —'
assert_not_contains 'resume mode removed' '`resume` —'
assert_contains 'track-ready explicitly banned' 'Do not teach or call `bash .track/scripts/track-ready.sh {id}`.'
assert_not_contains 'track-ready never taught as a run step' 'run `bash .track/scripts/track-ready.sh {id}`'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
