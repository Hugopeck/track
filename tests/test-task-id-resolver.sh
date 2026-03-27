#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/init/scaffold/track/scripts/track-common.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

assert_code() {
  local name="$1"
  local expected="$2"
  if [[ "$RUN_EXIT" -eq "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected=%s got=%s\n' "$expected" "$RUN_EXIT"
  fi
}

assert_eq() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected=%q got=%q\n' "$expected" "$actual"
  fi
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    missing=%q in %q\n' "$needle" "$haystack"
  fi
}

run_resolve() {
  local body="${1-}"
  local labels="${2-}"
  local title="${3-}"
  local branch="${4-}"
  RUN_EXIT=0
  track_resolve_task_ids "$body" "$labels" "$title" "$branch" || RUN_EXIT=$?
}

printf 'Running task ID resolver tests...\n\n'

run_resolve $'Track-Task: 1.1\nTrack-Task: 1.3' '' '[1.1] batch' 'task/1.1-test-task'
assert_code 'body batch resolves' 0
assert_eq 'body batch mode' "$TRACK_RESOLUTION_MODE" 'batch'
assert_eq 'body batch source' "$TRACK_RESOLVED_SOURCE" 'body'
assert_eq 'body batch ids' "$TRACK_RESOLVED_TASK_IDS" $'1.1\n1.3'

run_resolve '' 'track:1.1,track:1.3' '' 'feature/labels'
assert_code 'label batch resolves' 0
assert_eq 'label batch mode' "$TRACK_RESOLUTION_MODE" 'batch'
assert_eq 'label batch source' "$TRACK_RESOLVED_SOURCE" 'labels'
assert_eq 'label batch ids' "$TRACK_RESOLVED_TASK_IDS" $'1.1\n1.3'

run_resolve $'Track-Task: 1.1\nTrack-Task: 1.3' '' '[1.1] subset title' 'task/1.1-test-task'
assert_code 'body batch with title subset passes' 0

run_resolve $'Track-Task: 1.1\nTrack-Task: 1.3' '' '[1.2] foreign title' 'task/1.1-test-task'
assert_code 'body batch with foreign title fails' 2
assert_contains 'body batch title conflict surfaced' "$TRACK_RESOLVER_ERROR" 'PR title references task'

run_resolve $'Track-Task: 1.1\nTrack-Task: 1.3' '' '[1.1] title' 'task/1.2-done-task'
assert_code 'body batch with foreign branch fails' 2
assert_contains 'body batch branch conflict surfaced' "$TRACK_RESOLVER_ERROR" 'PR branch references task'

run_resolve '' '' '[1.1] [1.3] title-only batch' ''
assert_code 'title-only multi id does not activate batch' 2
assert_contains 'title-only multi id explains explicit batch' "$TRACK_RESOLVER_ERROR" 'explicit batch declaration'

run_resolve $'Track-Task: 1.1\nTrack-Task: 1.1\nTrack-Task: 1.3' '' '' ''
assert_code 'duplicate body ids dedupe cleanly' 0
assert_eq 'duplicate body ids deduped' "$TRACK_RESOLVED_TASK_IDS" $'1.1\n1.3'
assert_eq 'deduped count preserved' "$TRACK_RESOLVED_TASK_COUNT" '2'

run_resolve 'Track-Task: 1.3' '' '[1.3] single' 'task/1.3-dependent-task'
assert_code 'single task still resolves' 0
assert_eq 'single mode remains supported' "$TRACK_RESOLUTION_MODE" 'single'
assert_eq 'single source prefers body' "$TRACK_RESOLVED_SOURCE" 'body'
assert_eq 'single resolved id' "$TRACK_RESOLVED_TASK_ID" '1.3'

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
