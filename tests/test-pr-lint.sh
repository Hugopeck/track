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

run_capture env GITHUB_HEAD_REF='task/1.1-test-task' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 1.4' PR_TITLE='[1.1] Batch lint' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'explicit batch via body passes' 0
assert_stdout_contains 'body batch logs resolved tasks' 'Resolved tasks: 1.1, 1.4 (source: body)'
cleanup_capture

run_capture env GITHUB_HEAD_REF='feature/labels-batch' PR_LABELS='track:1.1,track:1.4' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'explicit batch via labels passes' 0
assert_stdout_contains 'label batch logs resolved tasks' 'Resolved tasks: 1.1, 1.4 (source: labels)'
assert_stderr_contains 'label batch warns on non-track branch' 'using fallback task linkage from labels'
cleanup_capture

run_capture env GITHUB_HEAD_REF='task/1.1-test-task' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 9.9' PR_TITLE='[1.1] Missing task in batch' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'batch with missing task file fails' 1
assert_stderr_contains 'missing task file surfaced for batch' "No task file found for ID '9.9'"
cleanup_capture

run_capture env GITHUB_HEAD_REF='task/1.1-test-task' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 1.4' PR_TITLE='[1.1] inside batch' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'branch task inside canonical batch passes' 0
cleanup_capture

run_capture env GITHUB_HEAD_REF='task/1.2-done-task' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 1.4' PR_TITLE='[1.1] foreign branch' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'branch task outside canonical batch fails' 1
assert_stderr_contains 'foreign branch conflict surfaced' 'PR branch references task'
cleanup_capture

run_capture env GITHUB_HEAD_REF='feature/no-signal' PR_TITLE='Regular title' bash "$repo/.track/scripts/track-pr-lint.sh"
assert_code 'missing all task signals still fails' 1
assert_stderr_contains 'no-signal error is actionable' 'Could not resolve a Track task for this PR'
cleanup_capture

rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
