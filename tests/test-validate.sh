#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  local expected_exit="$2"
  shift 2
  local actual_exit=0

  "$@" >/dev/null 2>&1 || actual_exit=$?

  if [[ $actual_exit -eq $expected_exit ]]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (expected exit %d, got %d)\n' "$name" "$expected_exit" "$actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

# Create a temp dir that looks like a repo with .track/
setup_valid_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-validate.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

# Create an invalid repo (missing required field)
setup_invalid_repo() {
  local tmp
  tmp="$(setup_valid_repo)"
  cat > "$tmp/.track/tasks/1.4-bad-task.md" << 'EOF'
---
id: "1.4"
title: "Bad task"
status: invalid_status
mode: implement
priority: medium
project_id: "1"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: ""
---

## Context
Invalid status.

## Acceptance Criteria
- [ ] Something

## Notes
Bad.
EOF
  printf '%s' "$tmp"
}

printf 'Running track-validate tests...\n'

# Test 1: Valid fixtures pass validation
repo="$(setup_valid_repo)"
run_test "valid fixtures pass" 0 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Test 2: Invalid status fails validation
repo="$(setup_invalid_repo)"
run_test "invalid status fails" 1 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
