#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULESET_FILE="$SCRIPT_DIR/../skills/setup-track/assets/track-ruleset.json"
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

assert_contains() {
  local name="$1"
  local pattern="$2"

  if grep -Fq -- "$pattern" "$RULESET_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern: %s\n' "$pattern"
  fi
}

assert_not_contains() {
  local name="$1"
  local pattern="$2"

  if grep -Fq -- "$pattern" "$RULESET_FILE"; then
    fail "$name"
    printf '    unexpected pattern: %s\n' "$pattern"
  else
    pass "$name"
  fi
}

assert_count() {
  local name="$1"
  local pattern="$2"
  local expected="$3"
  local actual

  actual="$(grep -F -c -- "$pattern" "$RULESET_FILE")"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    pattern=%s expected=%s got=%s\n' "$pattern" "$expected" "$actual"
  fi
}

printf 'Running ruleset tests...\n\n'

if [[ -f "$RULESET_FILE" ]]; then
  pass 'ruleset file exists'
else
  fail 'ruleset file exists'
  printf '    missing file: %s\n' "$RULESET_FILE"
fi

if [[ -s "$RULESET_FILE" ]]; then
  pass 'ruleset file is non-empty'
else
  fail 'ruleset file is non-empty'
fi

COMPACT_CONTENT="$(tr -d '[:space:]' < "$RULESET_FILE")"
FIRST_CHAR="$(printf '%s' "$COMPACT_CONTENT" | awk '{ print substr($0, 1, 1) }')"
LAST_CHAR="$(printf '%s' "$COMPACT_CONTENT" | awk '{ print substr($0, length($0), 1) }')"

if [[ "$FIRST_CHAR" == '{' ]]; then
  pass 'first non-whitespace character is opening brace'
else
  fail 'first non-whitespace character is opening brace'
  printf '    got: %s\n' "$FIRST_CHAR"
fi

if [[ "$LAST_CHAR" == '}' ]]; then
  pass 'last non-whitespace character is closing brace'
else
  fail 'last non-whitespace character is closing brace'
  printf '    got: %s\n' "$LAST_CHAR"
fi

assert_contains 'ruleset name is Track Protection' '"name": "Track Protection"'
assert_contains 'target is branch' '"target": "branch"'
assert_contains 'enforcement is active' '"enforcement": "active"'
assert_contains 'targets main branch' 'refs/heads/main'
assert_contains 'targets master branch' 'refs/heads/master'

assert_count 'contains five rule entries' '"type": ' 5
assert_count 'deletion rule appears once' '"type": "deletion"' 1
assert_count 'non-fast-forward rule appears once' '"type": "non_fast_forward"' 1
assert_count 'linear history rule appears once' '"type": "required_linear_history"' 1
assert_count 'pull request rule appears once' '"type": "pull_request"' 1
assert_count 'required status checks rule appears once' '"type": "required_status_checks"' 1

assert_contains 'dismiss stale reviews on push is enabled' '"dismiss_stale_reviews_on_push": true'
assert_contains 'approval count is zero' '"required_approving_review_count": 0'
assert_contains 'code owner review is not required' '"require_code_owner_review": false'
assert_contains 'last push approval is not required' '"require_last_push_approval": false'
assert_contains 'review thread resolution is not required' '"required_review_thread_resolution": false'

assert_contains 'strict status check policy is enabled' '"strict_required_status_checks_policy": true'
assert_count 'contains exactly three status check contexts' '"context": ' 3
assert_contains 'requires Track Validate status check' '"context": "Track Validate"'
assert_contains 'requires Track PR Lint status check' '"context": "Track PR Lint"'
assert_contains 'requires conventional commit lint status check' '"context": "conventional-commit-lint"'

assert_not_contains 'does not pin integration id' 'integration_id'
assert_not_contains 'does not restrict merge methods' 'allowed_merge_methods'
assert_not_contains 'does not require specific reviewers' 'required_reviewers'

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
