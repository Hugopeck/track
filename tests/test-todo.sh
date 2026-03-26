#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
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
    printf '  FAIL: %s (pattern "%s" not found in %s)\n' "$name" "$pattern" "$file"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-todo.sh "$tmp/.track/scripts/"
  # Initialize a git repo so track-todo.sh doesn't fail on git commands
  (cd "$tmp" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
  printf '%s' "$tmp"
}

printf 'Running track-todo tests...\n'

# Test 1: TODO generation succeeds in local+offline mode
repo="$(setup_repo)"
run_test "local+offline generates TODO.md" 0 bash "$repo/.track/scripts/track-todo.sh" --local --offline --output "$repo/TODO.md"

# Test 2: Output contains expected content
if [[ -f "$repo/TODO.md" ]]; then
  check_contains "TODO.md contains project title" "$repo/TODO.md" "Test Project"
  check_contains "TODO.md contains task ID" "$repo/TODO.md" "1.1"
  check_contains "TODO.md contains Work Items header" "$repo/TODO.md" "Work Items"
else
  printf '  FAIL: TODO.md was not created\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
