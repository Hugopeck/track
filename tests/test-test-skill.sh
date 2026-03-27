#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE="skills/test/SKILL.md"

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

printf 'Running test skill regression tests...\n\n'

if [[ -f "$SKILL_FILE" ]]; then
  pass 'skill file exists'
else
  fail 'skill file missing'
fi

assert_contains 'frontmatter names the skill' 'name: test'
assert_contains 'allowed tools include Bash' '  - Bash'
assert_contains 'allowed tools include Read' '  - Read'
assert_contains 'allowed tools include Glob' '  - Glob'
assert_contains 'allowed tools include Grep' '  - Grep'
assert_contains 'allowed tools include Agent' '  - Agent'
assert_contains 'owns section present' '## What This Skill Owns'
assert_contains 'operating modes present' '## Operating Modes'
assert_contains 'definition of done present' '## Definition of Done'
assert_contains 'closing matrix present' '## Closing Message Matrix'
assert_contains 'do not present' '## Do Not'
assert_contains 'scripts mode documented' '- `scripts` — run `bash tests/run-all.sh`'
assert_contains 'skills mode documented' '- `skills` — run headless smoke tests for Track skills in isolated worktrees;'
assert_contains 'full mode documented' '- `full` — run `scripts`, then `skills`, and emit one unified report'
assert_contains 'single mode documented' '- `single` — run exactly one named script or one named skill'
assert_contains 'runner dependency documented' 'tests/run-all.sh'
assert_contains 'validate smoke test documented' '#### `validate`'
assert_contains 'todo smoke test documented' '#### `todo`'
assert_contains 'headless invocation documented' 'claude -p "/track:{skill} {skill_args}"'
assert_contains 'json output documented' '--output-format json'
assert_contains 'bare mode documented' '--bare'
assert_contains 'budget cap documented' '--max-budget-usd 0.50'
assert_contains 'isolated worktree documented' 'git worktree add --detach'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
