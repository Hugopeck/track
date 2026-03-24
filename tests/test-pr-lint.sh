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

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-pr-lint.sh "$tmp/scripts/"
  printf '%s' "$tmp"
}

printf 'Running track-pr-lint tests...\n'

repo="$(setup_repo)"

# Test 1: Valid task branch + title passes
run_test "valid branch and title" 0 \
  env GITHUB_HEAD_REF="task/1.1-test-task" PR_TITLE="[1.1] Test task" \
  bash "$repo/scripts/track-pr-lint.sh"

# Test 2: Non-task branch passes (skipped)
run_test "non-task branch passes" 0 \
  env GITHUB_HEAD_REF="feature/something" PR_TITLE="Some feature" \
  bash "$repo/scripts/track-pr-lint.sh"

# Test 3: Malformed task branch fails
run_test "malformed task branch fails" 1 \
  env GITHUB_HEAD_REF="task/bad-format" PR_TITLE="whatever" \
  bash "$repo/scripts/track-pr-lint.sh"

# Test 4: Missing task ID in title fails
run_test "missing task ID in title fails" 1 \
  env GITHUB_HEAD_REF="task/1.1-test-task" PR_TITLE="Some title without ID" \
  bash "$repo/scripts/track-pr-lint.sh"

# Test 5: Nonexistent task ID fails
run_test "nonexistent task ID fails" 1 \
  env GITHUB_HEAD_REF="task/99.1-nonexistent" PR_TITLE="[99.1] Nonexistent" \
  bash "$repo/scripts/track-pr-lint.sh"

# Test 6: No HEAD_REF passes (not a PR context)
run_test "no HEAD_REF passes" 0 \
  env -u GITHUB_HEAD_REF \
  bash "$repo/scripts/track-pr-lint.sh"

rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
