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
  cp "$SCAFFOLD_SCRIPTS"/track-complete.sh "$tmp/.track/scripts/"
  cat > "$tmp/.track/tasks/1.4-related-task.md" <<'TASK'
---
id: "1.4"
title: "Related task"
status: todo
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
Related fixture.

## Acceptance Criteria
- [ ] Done

## Notes
None.
TASK
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

assert_file_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$file"
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

printf 'Running track-complete tests...\n\n'

# Single-task branch-only completion
repo="$(setup_repo)"
run_capture bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/14'
assert_code 'single-task branch-only completion works' 0
assert_file_contains 'single-task marks done' "$repo/.track/tasks/1.1-test-task.md" 'status: done'
cleanup_capture
rm -rf "$repo"

# Also-Completed marks additional tasks done
repo="$(setup_repo)"
run_capture env PR_BODY=$'Track-Task: 1.1\nAlso-Completed: 1.4' PR_TITLE='[1.1] primary task' TRACK_COMPLETED_AT='2026-03-27T10:11:12Z' bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/11'
assert_code 'also-completed succeeds' 0
assert_file_contains 'primary task marked done' "$repo/.track/tasks/1.1-test-task.md" 'status: done'
assert_file_contains 'also-completed task marked done' "$repo/.track/tasks/1.4-related-task.md" 'status: done'
assert_file_contains 'also-completed writes pr url' "$repo/.track/tasks/1.4-related-task.md" 'pr: "https://github.com/test/pull/11"'
assert_file_contains 'completion uses merged date' "$repo/.track/tasks/1.1-test-task.md" 'updated: 2026-03-27'
cleanup_capture
rm -rf "$repo"

# Already-done task is skipped
repo="$(setup_repo)"
run_capture env PR_BODY=$'Track-Task: 1.1\nAlso-Completed: 1.2' PR_TITLE='[1.1] with done task' bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/12'
assert_code 'also-completed with already-done task succeeds' 0
assert_stdout_contains 'already-done task is skipped' 'Skipping terminal task 1.2 (done).'
cleanup_capture
rm -rf "$repo"

# Missing also-completed task fails preflight
repo="$(setup_repo)"
before_status="$(grep -n '^status:' "$repo/.track/tasks/1.1-test-task.md")"
run_capture env PR_BODY=$'Track-Task: 1.1\nAlso-Completed: 9.9' PR_TITLE='[1.1] missing also' bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/13'
assert_code 'missing also-completed task fails before writes' 1
assert_stderr_contains 'missing task surfaced during preflight' 'No task file found for 9.9'
after_status="$(grep -n '^status:' "$repo/.track/tasks/1.1-test-task.md")"
if [[ "$before_status" == "$after_status" ]]; then
  pass 'preflight failure leaves primary task untouched'
else
  fail 'preflight failure leaves primary task untouched'
fi
cleanup_capture
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
