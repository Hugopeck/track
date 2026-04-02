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

# Install path and method
assert_contains 'README uses shared clone path' "$README_FILE" '~/.local/share/agent-skills/track'
assert_contains 'README uses install.sh' "$README_FILE" '~/.local/share/agent-skills/track/install.sh'
assert_contains 'README install prompt is agent-agnostic' "$README_FILE" 'Paste this into your coding agent'

# Core sections exist
assert_contains 'README has features section' "$README_FILE" '## Features'
assert_contains 'README has quick start section' "$README_FILE" '## Quick Start'
assert_contains 'README has how it works section' "$README_FILE" '## How It Works'
assert_contains 'README has commands section' "$README_FILE" '## Commands'
assert_contains 'README has requirements section' "$README_FILE" '## Requirements'
assert_contains 'README has community section' "$README_FILE" '## Community'
assert_contains 'README links to TRACK.md' "$README_FILE" '[TRACK.md](TRACK.md)'

# Key content
assert_contains 'README mentions file scope coordination' "$README_FILE" 'files:'
assert_contains 'README mentions draft PR lifecycle' "$README_FILE" 'draft PR'
assert_contains 'README mentions slash commands' "$README_FILE" '/track:work'
assert_contains 'README mentions GitHub Actions' "$README_FILE" 'GitHub Actions'
assert_contains 'README mentions MIT license' "$README_FILE" '[MIT](LICENSE)'
assert_contains 'README documents untracked workflow' "$README_FILE" 'stay untracked until one clear task deterministically matches'
assert_contains 'README command table reflects tracked or untracked work' "$README_FILE" 'Work a tracked task or stay untracked until one clear task matches'

# Track Cloud / open-core framing
assert_contains 'README has Track Cloud section' "$README_FILE" '## Track Cloud'
assert_contains 'README states free forever' "$README_FILE" 'free forever'

# Removed content stays removed
assert_not_contains 'README no longer references opencode.json' "$README_FILE" 'opencode.json'
assert_not_contains 'README no longer references Conductor' "$README_FILE" 'Conductor'
assert_not_contains 'README no longer lists Cursor in support table language' "$README_FILE" '| Cursor |'
assert_not_contains 'README no longer lists OpenCode in support table language' "$README_FILE" '| OpenCode |'
assert_not_contains 'README no longer references old claude skill path' "$README_FILE" '~/.claude/skills/track'
assert_not_contains 'README no longer references local setup script' "$README_FILE" '`./setup`'
assert_not_contains 'README no longer references plugin-dir testing' "$README_FILE" 'claude --plugin-dir ./path/to/track'
assert_not_contains 'README no longer references plugin registry install' "$README_FILE" 'claude plugin install hugopeck/track'
assert_not_contains 'README no longer references conductor.json' "$README_FILE" 'conductor.json'
assert_not_contains 'README no longer tells users to pick a task' "$README_FILE" 'Pick a task and start working:'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
