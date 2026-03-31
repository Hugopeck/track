#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE='skills/todo/SKILL.md'

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

printf 'Running refresh-track skill regression tests...\n\n'

if [[ -f "$SKILL_FILE" ]]; then
  pass 'skill file exists'
else
  fail 'skill file missing'
fi

assert_contains 'frontmatter names the skill' 'name: refresh-track'
assert_contains 'description mentions shared views' "Regenerate Track's shared views"
assert_contains 'disable model invocation retained' 'disable-model-invocation: true'
assert_contains 'bash allowed' '  - Bash'
assert_contains 'read allowed' '  - Read'
assert_contains 'owns section present' '## What This Skill Owns'
assert_contains 'operating modes present' '## Operating Modes'
assert_contains 'definition of done present' '## Definition of Done'
assert_contains 'closing matrix present' '## Closing Message Matrix'
assert_contains 'do not present' '## Do Not'
assert_contains 'command renamed' '/track:refresh-track'
assert_contains 'forwards user flags' 'Do not override user-supplied flags with auto-detection'
assert_contains 'script path retained' '.track/scripts/track-todo.sh'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
