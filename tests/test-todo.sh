#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/runtime/scripts/track-common.sh"
TODO_SCRIPT="$SCRIPT_DIR/../skills/todo/scripts/track-todo.sh"
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

check_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -q "$pattern" "$file"; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (pattern "%s" not found in %s)\n' "$name" "$pattern" "$file"
    FAIL=$((FAIL + 1))
  fi
}

check_not_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -q "$pattern" "$file"; then
    printf '  FAIL: %s (pattern "%s" unexpectedly found in %s)\n' "$name" "$pattern" "$file"
    FAIL=$((FAIL + 1))
  else
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/"
  cp "$TODO_SCRIPT" "$tmp/.track/scripts/"
  # Initialize a git repo so track-todo.sh doesn't fail on git commands
  (cd "$tmp" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
  printf '%s' "$tmp"
}

printf 'Running track-todo tests...\n'

# Test 1: view generation succeeds in local+offline mode
repo="$(setup_repo)"
run_test "local+offline generates Track views" 0 bash "$repo/.track/scripts/track-todo.sh" --local --offline --output "$repo/BOARD.md"

# Test 2: Outputs contain expected content
if [[ -f "$repo/BOARD.md" && -f "$repo/TODO.md" && -f "$repo/PROJECTS.md" ]]; then
  check_contains "BOARD.md contains board header" "$repo/BOARD.md" "# Board"
  check_contains "BOARD.md contains project title" "$repo/BOARD.md" "Test Project"
  check_contains "BOARD.md contains task ID" "$repo/BOARD.md" "1.1"
  check_not_contains "BOARD.md no longer contains immediate starts" "$repo/BOARD.md" "## Immediate Starts"
  check_contains "TODO.md contains todo header" "$repo/TODO.md" "# TODO"
  check_contains "TODO.md contains immediate starts section" "$repo/TODO.md" "## Immediate Starts"
  check_contains "TODO.md contains blocked section" "$repo/TODO.md" "## Blocked"
  check_contains "PROJECTS.md contains projects header" "$repo/PROJECTS.md" "# Projects Overview"
  check_contains "footer text lands in BOARD.md" "$repo/BOARD.md" 'projects derived from `.track/` state.'
  check_contains "footer text lands in TODO.md" "$repo/TODO.md" 'projects derived from `.track/` state.'
  check_contains "footer text lands in PROJECTS.md" "$repo/PROJECTS.md" 'projects derived from `.track/` state.'
  check_not_contains "BOARD.md does not start with footer" <(head -n 3 "$repo/BOARD.md") 'Generated from `'
  check_not_contains "TODO.md does not start with footer" <(head -n 3 "$repo/TODO.md") 'Generated from `'
  check_not_contains "PROJECTS.md does not start with footer" <(head -n 3 "$repo/PROJECTS.md") 'Generated from `'
else
  printf '  FAIL: one or more Track view files were not created\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
