#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
PREFS_FILE="skills/init/scaffold/conductor-git-preferences.md"
README_FILE="README.md"
INIT_SKILL_FILE="skills/init/SKILL.md"

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

printf 'Running Conductor preference regression tests...\n\n'

assert_contains 'canonical file has create PR section' "$PREFS_FILE" '## Create PR preferences'
assert_contains 'canonical file uses Track-Task as primary linkage' "$PREFS_FILE" 'Always put `Track-Task: {id}` on the first line of the PR body.'
assert_contains 'canonical file keeps Also-Completed guidance' "$PREFS_FILE" 'Also-Completed: {id}'
assert_contains 'canonical file keeps ask-dont-guess safety' "$PREFS_FILE" 'stop and ask instead of guessing'
assert_contains 'canonical file includes conventional commit format' "$PREFS_FILE" '`type(scope): description`'
assert_contains 'canonical file identifies primary task first' "$PREFS_FILE" 'Identify the primary Track task in this PR before writing anything.'
assert_contains 'canonical file tells agent to read task sources first' "$PREFS_FILE" 'Read `TODO.md`, `.track/tasks/`, and `CLAUDE.md` first.'

assert_contains 'README surfaces recommended Conductor preferences' "$README_FILE" '### Recommended Conductor Git preferences'
assert_contains 'README says settings are optional but recommended' "$README_FILE" 'These settings are optional, but strongly recommended.'
assert_contains 'README says prompts live in Conductor UI' "$README_FILE" 'These prompts live in the Conductor UI — not in `conductor.json`.'
assert_contains 'README references canonical prompt file' "$README_FILE" 'skills/init/scaffold/conductor-git-preferences.md'
assert_contains 'README includes create PR block heading' "$README_FILE" '#### Create PR preferences'
assert_contains 'README includes create PR block' "$README_FILE" '#### Create PR preferences'
assert_contains 'README tells agent to identify primary task first' "$README_FILE" 'Identify the primary Track task in this PR before writing anything.'
assert_contains 'README includes conventional commit format' "$README_FILE" '`type(scope): description`'
assert_contains 'README includes Track-Task fallback' "$README_FILE" 'Track-Task: {id}'
assert_contains 'README includes Also-Completed guidance' "$README_FILE" 'Also-Completed: {id}'

assert_contains 'init skill reads canonical prompt file' "$INIT_SKILL_FILE" '${CLAUDE_SKILL_DIR}/scaffold/conductor-git-preferences.md'
assert_contains 'init skill points to Conductor Settings Git' "$INIT_SKILL_FILE" 'Conductor Settings → Git for this repo'
assert_contains 'init skill keeps step advisory' "$INIT_SKILL_FILE" 'Do not block init on this step — Track still works without these preferences'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
