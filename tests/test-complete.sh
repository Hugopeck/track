#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/scripts"
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
    printf '  FAIL: %s (pattern "%s" not found)\n' "$name" "$pattern"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-complete.sh "$tmp/scripts/"
  printf '%s' "$tmp"
}

printf 'Running track-complete tests...\n'

# Test 1: Complete a todo task
repo="$(setup_repo)"
run_test "completes a task" 0 bash "$repo/scripts/track-complete.sh" "task/1.1-test-task" "https://github.com/test/pull/1"
check_contains "status set to done" "$repo/.track/tasks/1.1-test-task.md" "status: done"
check_contains "pr URL written" "$repo/.track/tasks/1.1-test-task.md" "https://github.com/test/pull/1"
rm -rf "$repo"

# Test 2: Non-task branch is a no-op
repo="$(setup_repo)"
run_test "non-task branch is no-op" 0 bash "$repo/scripts/track-complete.sh" "feature/something" ""
rm -rf "$repo"

# Test 3: Already-done task is no-op
repo="$(setup_repo)"
run_test "already-done task is no-op" 0 bash "$repo/scripts/track-complete.sh" "task/1.2-done-task" "https://github.com/test/pull/2"
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
