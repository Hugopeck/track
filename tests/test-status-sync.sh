#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/runtime/scripts/track-common.sh"
VALIDATE_SCRIPT="$SCRIPT_DIR/../skills/validate/scripts/track-validate.sh"
TASK_STATUS_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-task-status.sh"
SYNC_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-sync-pr-status.sh"
START_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-start.sh"
READY_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-ready.sh"
COMPLETE_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-complete.sh"
MANIFEST_FILE="$SCRIPT_DIR/../skills/setup-track/assets/install-manifest.json"
STATUS_WORKFLOW="$SCRIPT_DIR/../.github/workflows/track-status-sync.yml"
ASSET_STATUS_WORKFLOW="$SCRIPT_DIR/../skills/setup-track/assets/workflows/track-status-sync.yml"
VALIDATE_WORKFLOW="$SCRIPT_DIR/../.github/workflows/track-validate.yml"
ASSET_VALIDATE_WORKFLOW="$SCRIPT_DIR/../skills/setup-track/assets/workflows/track-validate.yml"
PR_LINT_WORKFLOW="$SCRIPT_DIR/../.github/workflows/track-pr-lint.yml"
ASSET_PR_LINT_WORKFLOW="$SCRIPT_DIR/../skills/setup-track/assets/workflows/track-pr-lint.yml"
PASS=0
FAIL=0
TODAY="$(date -u +'%Y-%m-%d')"

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

run_capture() {
  STDOUT_FILE="$(mktemp)"
  STDERR_FILE="$(mktemp)"
  RUN_EXIT=0
  "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || RUN_EXIT=$?
}

cleanup_capture() {
  rm -f "$STDOUT_FILE" "$STDERR_FILE"
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

assert_literal_in_file() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$file"
  fi
}

assert_files_equal() {
  local name="$1"
  local left="$2"
  local right="$3"
  if cmp -s "$left" "$right"; then
    pass "$name"
  else
    fail "$name"
    printf '    files differ: %s %s\n' "$left" "$right"
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/"
  cp "$VALIDATE_SCRIPT" "$tmp/.track/scripts/"
  cp "$TASK_STATUS_SCRIPT" "$tmp/.track/scripts/"
  cp "$SYNC_SCRIPT" "$tmp/.track/scripts/"
  cp "$START_SCRIPT" "$tmp/.track/scripts/"
  cp "$READY_SCRIPT" "$tmp/.track/scripts/"
  cp "$COMPLETE_SCRIPT" "$tmp/.track/scripts/"

  cat > "$tmp/.track/tasks/1.4-cancelled-task.md" <<'TASK'
---
id: "1.4"
title: "Cancelled task"
status: cancelled
mode: implement
priority: low
project_id: "1"
created: 2026-01-01
updated: 2026-01-02
depends_on: []
files: []
pr: ""
cancelled_reason: "No longer needed"
---

## Context
Cancelled fixture.

## Acceptance Criteria
- [ ] Never happens

## Notes
Cancelled fixture.
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

  printf '%s\n' "$tmp"
}

printf 'Running track status sync tests...\n\n'

if [[ -f "$SYNC_SCRIPT" ]]; then
  pass 'sync script exists'
else
  fail 'sync script exists'
fi

if [[ -f "$START_SCRIPT" ]]; then
  pass 'start wrapper exists'
else
  fail 'start wrapper exists'
fi

if [[ -f "$READY_SCRIPT" ]]; then
  pass 'ready wrapper exists'
else
  fail 'ready wrapper exists'
fi

assert_files_equal 'status-sync workflow matches asset copy' "$STATUS_WORKFLOW" "$ASSET_STATUS_WORKFLOW"
assert_files_equal 'validate workflow matches asset copy' "$VALIDATE_WORKFLOW" "$ASSET_VALIDATE_WORKFLOW"
assert_files_equal 'pr-lint workflow matches asset copy' "$PR_LINT_WORKFLOW" "$ASSET_PR_LINT_WORKFLOW"

assert_literal_in_file 'manifest installs sync script' 'track-sync-pr-status.sh' "$MANIFEST_FILE"
assert_literal_in_file 'manifest installs start wrapper' 'track-start.sh' "$MANIFEST_FILE"
assert_literal_in_file 'manifest installs ready wrapper' 'track-ready.sh' "$MANIFEST_FILE"
assert_literal_in_file 'manifest installs status-sync workflow' 'track-status-sync.yml' "$MANIFEST_FILE"

assert_literal_in_file 'status-sync workflow listens to lifecycle events' 'types: [opened, reopened, ready_for_review, converted_to_draft, closed]' "$STATUS_WORKFLOW"
assert_literal_in_file 'status-sync workflow runs sync script' 'bash .track/scripts/track-sync-pr-status.sh "$TRACK_SYNC_EVENT"' "$STATUS_WORKFLOW"
assert_literal_in_file 'status-sync workflow regenerates views' 'bash .track/scripts/track-todo.sh --local --offline >/dev/null' "$STATUS_WORKFLOW"
assert_literal_in_file 'status-sync workflow delegates writeback' 'bash .track/scripts/track-complete-writeback.sh' "$STATUS_WORKFLOW"
assert_literal_in_file 'status-sync workflow calls validate workflow' 'uses: ./.github/workflows/track-validate.yml' "$STATUS_WORKFLOW"
assert_literal_in_file 'status-sync workflow calls pr-lint workflow' 'uses: ./.github/workflows/track-pr-lint.yml' "$STATUS_WORKFLOW"
assert_literal_in_file 'validate workflow supports workflow_call' 'workflow_call:' "$VALIDATE_WORKFLOW"
assert_literal_in_file 'validate workflow runs on pull_request synchronize' 'types: [synchronize, edited, labeled, unlabeled]' "$VALIDATE_WORKFLOW"
assert_literal_in_file 'pr-lint workflow runs on pull_request synchronize' 'types: [synchronize, edited, labeled, unlabeled]' "$PR_LINT_WORKFLOW"
assert_literal_in_file 'validate workflow accepts checkout_repository input' 'checkout_repository:' "$VALIDATE_WORKFLOW"
assert_literal_in_file 'pr-lint workflow supports workflow_call' 'workflow_call:' "$PR_LINT_WORKFLOW"
assert_literal_in_file 'pr-lint workflow accepts checkout_repository input' 'checkout_repository:' "$PR_LINT_WORKFLOW"

repo="$(setup_repo)"
run_capture env TRACK_PR_DRAFT='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened 1.1
assert_code 'opened draft sets active' 0
assert_file_contains 'opened draft writes active' "$repo/.track/tasks/1.1-test-task.md" 'status: active'
assert_file_contains 'opened draft updates date' "$repo/.track/tasks/1.1-test-task.md" "updated: $TODAY"
assert_stdout_contains 'opened draft reports active update' 'to active'
cleanup_capture

run_capture bash "$repo/.track/scripts/track-sync-pr-status.sh" ready_for_review 1.1
assert_code 'ready_for_review sets review' 0
assert_file_contains 'ready_for_review writes review' "$repo/.track/tasks/1.1-test-task.md" 'status: review'
cleanup_capture

run_capture bash "$repo/.track/scripts/track-sync-pr-status.sh" converted_to_draft 1.1
assert_code 'converted_to_draft sets active' 0
assert_file_contains 'converted_to_draft writes active' "$repo/.track/tasks/1.1-test-task.md" 'status: active'
cleanup_capture

run_capture env TRACK_PR_DRAFT='false' bash "$repo/.track/scripts/track-sync-pr-status.sh" reopened 1.1
assert_code 'reopened ready sets review' 0
assert_file_contains 'reopened ready writes review' "$repo/.track/tasks/1.1-test-task.md" 'status: review'
cleanup_capture

run_capture bash "$repo/.track/scripts/track-sync-pr-status.sh" closed 1.1
assert_code 'closed unmerged resets todo' 0
assert_file_contains 'closed unmerged writes todo' "$repo/.track/tasks/1.1-test-task.md" 'status: todo'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env TRACK_PR_DRAFT='false' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened 1.1
assert_code 'opened ready sets review' 0
assert_file_contains 'opened ready writes review' "$repo/.track/tasks/1.1-test-task.md" 'status: review'
cleanup_capture

run_capture env TRACK_PR_DRAFT='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" reopened 1.1
assert_code 'reopened draft sets active' 0
assert_file_contains 'reopened draft writes active' "$repo/.track/tasks/1.1-test-task.md" 'status: active'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env TRACK_PR_DRAFT='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened 1.5
assert_code 'blocked task rejects opened sync' 1
assert_stderr_contains 'blocked task error surfaced' 'blocked task 1.5'
cleanup_capture

run_capture bash "$repo/.track/scripts/track-sync-pr-status.sh" closed 1.5
assert_code 'blocked task stays blocked on closed unmerged' 0
assert_file_contains 'blocked task remains blocked' "$repo/.track/tasks/1.5-blocked-task.md" 'status: blocked'
assert_stdout_contains 'blocked close reports no reset' 'remains blocked'
cleanup_capture

run_capture env TRACK_PR_DRAFT='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened 1.2
assert_code 'done task rejects opened sync' 1
assert_stderr_contains 'done task error surfaced' 'terminal task 1.2 (done)'
cleanup_capture

run_capture env TRACK_PR_DRAFT='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened 1.4
assert_code 'cancelled task rejects opened sync' 1
assert_stderr_contains 'cancelled task error surfaced' 'terminal task 1.4 (cancelled)'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env TASK_BRANCH='feature/no-signal' PR_TITLE='Regular title' bash "$repo/.track/scripts/track-sync-pr-status.sh" opened
assert_code 'non-Track PR skips gracefully' 0
assert_stdout_contains 'non-Track skip message shown' 'Not a Track PR; nothing to sync.'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
run_capture env TASK_BRANCH='task/1.1-test-task' PR_TITLE='feat(track): [1.1] merge test' PR_URL='https://github.com/test/repo/pull/25' TRACK_PR_MERGED='true' bash "$repo/.track/scripts/track-sync-pr-status.sh" closed
assert_code 'merged close delegates to complete path' 0
assert_file_contains 'merged close writes done' "$repo/.track/tasks/1.1-test-task.md" 'status: done'
assert_file_contains 'merged close writes pr url' "$repo/.track/tasks/1.1-test-task.md" 'pr: "https://github.com/test/repo/pull/25"'
assert_file_contains 'merged close unblocks dependent task' "$repo/.track/tasks/1.5-blocked-task.md" 'status: todo'
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo)"
current_dir="$(pwd)"
cd "$repo"
run_capture bash .track/scripts/track-start.sh 1.1
assert_code 'start wrapper sets active and validates' 0
assert_file_contains 'start wrapper writes active' .track/tasks/1.1-test-task.md 'status: active'
assert_stdout_contains 'start wrapper reports success' 'Task 1.1 synced to active.'
cleanup_capture

run_capture bash .track/scripts/track-ready.sh 1.1
assert_code 'ready wrapper sets review and validates' 0
assert_file_contains 'ready wrapper writes review' .track/tasks/1.1-test-task.md 'status: review'
assert_stdout_contains 'ready wrapper reports success' 'Task 1.1 synced to review.'
cleanup_capture
cd "$current_dir"
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
