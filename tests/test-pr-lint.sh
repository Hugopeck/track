#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-pr-lint.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

run_capture() {
  STDOUT_FILE="$(mktemp)"
  STDERR_FILE="$(mktemp)"
  RUN_EXIT=0
  "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || RUN_EXIT=$?
}

assert_code() {
  local name="$1"
  local expected="$2"
  if [[ $RUN_EXIT -eq $expected ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected=%s got=%s\n' "$expected" "$RUN_EXIT"
  fi
}

assert_stdout_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDOUT_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stdout pattern: %s\n' "$pattern"
  fi
}

assert_stderr_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDERR_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stderr pattern: %s\n' "$pattern"
  fi
}

cleanup_capture() {
  rm -f "$STDOUT_FILE" "$STDERR_FILE"
}

printf 'Running track-pr-lint tests...\n\n'

repo="$(setup_repo)"

# Single task from body resolves
run_capture env GITHUB_HEAD_REF='task/1.1-test-task' PR_BODY='Track-Task: 1.1' PR_TITLE='[1.1] Single lint' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'single task from body passes' 0
assert_stdout_contains 'body resolves single task' 'Resolved task: 1.1 (source: body)'
cleanup_capture

# Single task from title resolves
run_capture env GITHUB_HEAD_REF='feature/no-body' PR_TITLE='[1.1] Title only' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'single task from title passes' 0
assert_stdout_contains 'title resolves single task' 'Resolved task: 1.1 (source: title)'
cleanup_capture

# Single task from branch resolves
run_capture env GITHUB_HEAD_REF='task/1.1-test-task' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'single task from branch passes' 0
assert_stdout_contains 'branch resolves single task' 'Resolved task: 1.1 (source: branch)'
cleanup_capture

# Multiple Track-Task lines in body errors
run_capture env GITHUB_HEAD_REF='task/1.1-test-task' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 1.4' PR_TITLE='[1.1] Multi body' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'multiple Track-Task lines in body errors' 1
assert_stderr_contains 'multiple body error surfaced' 'multiple Track-Task values'
cleanup_capture

# Non-Track PR gracefully skips
run_capture env GITHUB_HEAD_REF='feature/no-signal' PR_TITLE='Regular title' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'non-Track PR skips gracefully' 0
assert_stdout_contains 'skip message shown' 'Not a Track PR'
cleanup_capture

rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
