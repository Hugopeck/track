#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/../scripts/lib/track-common.sh"
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
  track_resolve_task_id "$body" "$labels" "$title" "$branch" || RUN_EXIT=$?
}

printf 'Running task ID resolver tests...\n\n'

# Single task from body
run_resolve 'Track-Task: 1.3' '' '[1.3] single' 'task/1.3-dependent-task'
assert_code 'single task resolves from body' 0
assert_eq 'single source prefers body' "$TRACK_RESOLVED_SOURCE" 'body'
assert_eq 'single resolved id' "$TRACK_RESOLVED_TASK_ID" '1.3'

# Single task from labels
run_resolve '' 'track:2.1' '' ''
assert_code 'single task resolves from label' 0
assert_eq 'label source' "$TRACK_RESOLVED_SOURCE" 'labels'
assert_eq 'label id' "$TRACK_RESOLVED_TASK_ID" '2.1'

# Single task from title
run_resolve '' '' '[3.1] some title' ''
assert_code 'single task resolves from title' 0
assert_eq 'title source' "$TRACK_RESOLVED_SOURCE" 'title'
assert_eq 'title id' "$TRACK_RESOLVED_TASK_ID" '3.1'

# Single task from branch
run_resolve '' '' '' 'task/4.1-some-slug'
assert_code 'single task resolves from branch' 0
assert_eq 'branch source' "$TRACK_RESOLVED_SOURCE" 'branch'
assert_eq 'branch id' "$TRACK_RESOLVED_TASK_ID" '4.1'

# Multiple Track-Task lines in body errors
run_resolve $'Track-Task: 1.1\nTrack-Task: 1.3' '' '' ''
assert_code 'multiple Track-Task lines in body errors' 3
assert_contains 'multiple body ids error message' "$TRACK_RESOLVER_ERROR" 'multiple Track-Task values'

# Duplicate Track-Task (same ID) is fine
run_resolve $'Track-Task: 1.1\nTrack-Task: 1.1' '' '' ''
assert_code 'duplicate same-id Track-Task is ok' 0
assert_eq 'duplicate resolves correctly' "$TRACK_RESOLVED_TASK_ID" '1.1'

# Multiple track: labels errors
run_resolve '' 'track:1.1,track:1.3' '' ''
assert_code 'multiple track labels errors' 3
assert_contains 'multiple labels error message' "$TRACK_RESOLVER_ERROR" 'multiple track: labels'

# Multiple IDs in title errors
run_resolve '' '' '[1.1] [1.3] multi title' ''
assert_code 'multiple title IDs errors' 3
assert_contains 'multiple title error message' "$TRACK_RESOLVER_ERROR" 'multiple task IDs in PR title'

# No task found
run_resolve '' '' '' 'feature/unrelated'
assert_code 'no task found returns 1' 1
assert_contains 'no task error message' "$TRACK_RESOLVER_ERROR" 'no task ID found'

# Malformed branch
run_resolve '' '' '' 'task/bad'
assert_code 'malformed task branch errors' 3
assert_contains 'malformed branch error' "$TRACK_RESOLVER_ERROR" 'malformed task branch'

# Also-Completed parsing
TRACK_ALSO_COMPLETED_IDS=()
track_also_completed_ids_from_body $'Track-Task: 1.1\nAlso-Completed: 1.2\nAlso-Completed: 1.3'
AC_EXIT=$?
if [[ $AC_EXIT -eq 0 && ${#TRACK_ALSO_COMPLETED_IDS[@]} -eq 2 ]]; then
  pass 'also-completed parses two IDs'
else
  fail 'also-completed parses two IDs'
  printf '    exit=%s count=%s\n' "$AC_EXIT" "${#TRACK_ALSO_COMPLETED_IDS[@]}"
fi

track_also_completed_ids_from_body 'Track-Task: 1.1' || AC_EXIT=$?
if [[ ${AC_EXIT:-1} -ne 0 ]]; then
  pass 'also-completed returns 1 when none found'
else
  fail 'also-completed returns 1 when none found'
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
