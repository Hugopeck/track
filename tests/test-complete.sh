#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/runtime/scripts/track-common.sh"
COMPLETE_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-complete.sh"
WRITEBACK_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-complete-writeback.sh"
COMPLETE_WORKFLOW="$SCRIPT_DIR/../skills/init/assets/workflows/track-complete.yml"
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
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/"
  cp "$COMPLETE_SCRIPT" "$tmp/.track/scripts/"
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
  cat > "$tmp/.track/tasks/1.5-blocked-task.md" <<'TASK'
---
id: "1.5"
title: "Blocked task"
status: blocked
mode: implement
priority: high
project_id: "1"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - "1.1"
files:
  - "src/blocked/**"
pr: ""
blocked_reason: "Waiting on 1.1"
---

## Context
Blocked until 1.1 completes.

## Acceptance Criteria
- [ ] Work can start after 1.1 is done

## Notes
Dependency-driven blocked fixture.
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

assert_file_not_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if grep -Fq -- "$pattern" "$file"; then
    fail "$name"
    printf '    unexpected pattern %q in %s\n' "$pattern" "$file"
  else
    pass "$name"
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

if grep -Fq -- 'bash .track/scripts/track-todo.sh --local --offline >/dev/null' "$COMPLETE_WORKFLOW"; then
  pass 'complete workflow regenerates Track views'
else
  fail 'complete workflow regenerates Track views'
fi

if grep -Fq -- 'bash .track/scripts/track-complete-writeback.sh' "$COMPLETE_WORKFLOW"; then
  pass 'complete workflow delegates writeback to helper'
else
  fail 'complete workflow delegates writeback to helper'
fi

if [[ -f "$WRITEBACK_SCRIPT" ]]; then
  pass 'writeback helper script exists'
else
  fail 'writeback helper script exists'
fi

repo="$(setup_repo)"
run_capture bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/14'
assert_code 'single-task branch-only completion works' 0
assert_file_contains 'single-task marks done' "$repo/.track/tasks/1.1-test-task.md" 'status: done'
assert_file_contains 'dependency-blocked task is unblocked' "$repo/.track/tasks/1.5-blocked-task.md" 'status: todo'
assert_file_not_contains 'dependency-blocked reason removed after unblock' "$repo/.track/tasks/1.5-blocked-task.md" 'blocked_reason:'
assert_stdout_contains 'unblocked task is reported' 'Unblocked '
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env PR_BODY=$'Track-Task: 1.1\nAlso-Completed: 1.4' PR_TITLE='[1.1] primary task' TRACK_COMPLETED_AT='2026-03-27T10:11:12Z' bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/11'
assert_code 'also-completed succeeds' 0
assert_file_contains 'primary task marked done' "$repo/.track/tasks/1.1-test-task.md" 'status: done'
assert_file_contains 'also-completed task marked done' "$repo/.track/tasks/1.4-related-task.md" 'status: done'
assert_file_contains 'also-completed writes pr url' "$repo/.track/tasks/1.4-related-task.md" 'pr: "https://github.com/test/pull/11"'
assert_file_contains 'completion uses merged date' "$repo/.track/tasks/1.1-test-task.md" 'updated: 2026-03-27'
assert_file_contains 'unblocked task uses merged date' "$repo/.track/tasks/1.5-blocked-task.md" 'updated: 2026-03-27'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env PR_BODY=$'Track-Task: 1.1\nAlso-Completed: 1.2' PR_TITLE='[1.1] with done task' bash "$repo/.track/scripts/track-complete.sh" 'task/1.1-test-task' 'https://github.com/test/pull/12'
assert_code 'also-completed with already-done task succeeds' 0
assert_stdout_contains 'already-done task is skipped' 'Skipping terminal task 1.2 (done).'
cleanup_capture
rm -rf "$repo"

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
