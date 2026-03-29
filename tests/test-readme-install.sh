#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
README_FILE='README.md'

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

assert_not_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if contains_literal "$pattern" "$file"; then
    fail "$name"
  else
    pass "$name"
  fi
}

printf 'Running README install regression tests...\n\n'

assert_contains 'README uses shared clone path' "$README_FILE" '~/.local/share/agent-skills/track'
assert_contains 'README uses install.sh' "$README_FILE" '~/.local/share/agent-skills/track/install.sh'
assert_contains 'README mentions shared skill symlink dir' "$README_FILE" '~/.agents/skills/'
assert_contains 'OpenCode example uses AGENTS' "$README_FILE" '"instructions": ["AGENTS.md"]'
assert_contains 'platform table uses installed skills wording' "$README_FILE" '| Claude Code | Full support via installed skills |'
assert_contains 'troubleshooting uses install.sh refresh' "$README_FILE" 'Re-run `~/.local/share/agent-skills/track/install.sh` to refresh the skill symlinks'
assert_not_contains 'README no longer references old claude skill path' "$README_FILE" '~/.claude/skills/track'
assert_not_contains 'README no longer references local setup script' "$README_FILE" '`./setup`'
assert_not_contains 'README no longer references plugin-dir testing' "$README_FILE" 'claude --plugin-dir ./path/to/track'
assert_not_contains 'README no longer references plugin registry install' "$README_FILE" 'claude plugin install hugopeck/track'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
