#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL=0
PASSED=0
FAILED=0
FAILURES=()

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  name="$(basename "$test_file")"
  TOTAL=$((TOTAL + 1))
  printf '=== %s ===\n' "$name"
  if bash "$test_file"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
  fi
  printf '\n'
done

printf '========================================\n'
printf 'Total: %d | Passed: %d | Failed: %d\n' "$TOTAL" "$PASSED" "$FAILED"

if [[ $FAILED -gt 0 ]]; then
  printf '\nFailed:\n'
  for f in "${FAILURES[@]}"; do
    printf '  - %s\n' "$f"
  done
  exit 1
fi
