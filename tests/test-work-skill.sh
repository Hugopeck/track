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

assert_contains 'quick operations section documented' '## Quick Operations'
assert_contains 'link quick operation documented' '### `link` — retroactive branch attribution'
assert_contains 'context quick operation documented' '### `context` — append to task notes'
assert_contains 'link completion requirement documented' '`link` is complete only after the JSONL line is appended successfully.'
assert_contains 'context writes task file back' 'Write the updated task file back to disk.'
assert_contains 'context validates after edit' 'Run `bash .track/scripts/track-validate.sh`.'
assert_contains 'context completion requirement documented' '`context` is complete only after the task file is written and validation passes.'
assert_contains 'hook awareness checks explicit marker one' 'contains `Deployed by track init` or `Track event emitter`'
assert_contains 'link task validation do not documented' 'Do not emit a `track.link` event without validating the task ID exists'
assert_contains 'notes append-only do not documented' 'Do not overwrite existing `## Notes` content — append only'
assert_contains 'PR body is primary linkage' 'Always include `Track-Task: {id}` on the first line of the PR body'
assert_contains 'fallback Track-Task documented' 'Track-Task: {id}'
assert_contains 'optional label fallback documented' 'track:{id}'
assert_contains 'also-completed section documented' '## Also-Completed'
assert_contains 'also-completed syntax documented' 'Also-Completed: {id}'
assert_contains 'also-completed max documented' 'max 2'
assert_not_contains 'link not added as session mode completion' 'If mode is `link`'
assert_not_contains 'context not added as session mode completion' 'If mode is `context`'
assert_not_contains 'link not added to definition of done as mode' '`link` is done when'
assert_not_contains 'context not added to definition of done as mode' '`context` is done when'
assert_not_contains 'no batch PR section' '## Explicit Batch PRs'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
