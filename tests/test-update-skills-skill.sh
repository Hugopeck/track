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
  local pattern="$2"
  if contains_literal "$pattern" "$SKILL_FILE"; then
    pass "$name"
  else
    fail "$name"
  fi
}

printf 'Running update-skills skill regression tests...\n\n'

if [[ -f "$SKILL_FILE" ]]; then
  pass 'skill file exists'
else
  fail 'skill file missing'
fi

assert_contains 'frontmatter names the skill' 'name: update-skills'
assert_contains 'skill auto-loads' 'auto-load: true'
assert_contains 'command renamed' '/update-skills'
assert_contains 'owns section present' '## What This Skill Owns'
assert_contains 'operating modes present' '## Operating Modes'
assert_contains 'definition of done present' '## Definition of Done'
assert_contains 'closing matrix present' '## Closing Message Matrix'
assert_contains 'do not present' '## Do Not'
assert_contains 'session-start mode documented' 'session-start'
assert_contains 'session-start auto-run documented' 'At session start: silently check for updates'
assert_contains 'skill uses installed skill dir env' 'CLAUDE_SKILL_DIR'
assert_contains 'skill checks default clone dir for copied installs' 'TRACK_CLONE_DIR="${TRACK_CLONE_DIR:-${HOME}/.local/share/agent-skills/track}"'
assert_contains 'skill uses clone dir git repo when available' 'if [ -d "$TRACK_CLONE_DIR/.git" ]; then'
assert_contains 'skill keeps direct git lookup fallback' 'REPO="$(cd "$SKILL_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null)"'
assert_contains 'skill keeps legacy symlink fallback' 'while [ -L "$SKILL_DIR" ]'
assert_contains 'skill reads symlink target' 'readlink "$SKILL_DIR"'
assert_contains 'skill refreshes copied skill dirs' 'copy_skill_dir() {'
assert_contains 'skill copies into agent skill dir' 'copy_skill_dir "$skill" "${HOME}/.agents/skills/$name"'
assert_contains 'skill copies into claude skill dir' 'copy_skill_dir "$skill" "${HOME}/.claude/skills/$name"'
assert_contains 'skill pulls fast-forward only' 'git pull --ff-only'
assert_contains 'skill stops when repo cannot be found' 'there is nothing to update in place'
assert_contains 'up-to-date closing message documented' 'Track skills up to date.'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
