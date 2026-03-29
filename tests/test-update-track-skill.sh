#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE='skills/update-track/SKILL.md'

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

printf 'Running update-track skill regression tests...\n\n'

assert_contains 'skill file exists' "$SKILL_FILE" 'name: update-track'
assert_contains 'skill uses installed skill dir env' "$SKILL_FILE" 'CLAUDE_SKILL_DIR'
assert_contains 'skill resolves symlink chain' "$SKILL_FILE" 'while [ -L "$SKILL_DIR" ]'
assert_contains 'skill reads symlink target' "$SKILL_FILE" 'readlink "$SKILL_DIR"'
assert_contains 'skill finds git toplevel from clone' "$SKILL_FILE" 'git rev-parse --show-toplevel'
assert_contains 'skill pulls fast-forward only' "$SKILL_FILE" 'git pull --ff-only'
assert_contains 'skill stops when repo cannot be found' "$SKILL_FILE" 'there is nothing to update in place'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
