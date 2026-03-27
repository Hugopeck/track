#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
TOTAL=0
TEST_FILES=()

while IFS= read -r test_file; do
  TEST_FILES+=("$test_file")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name 'test-*.sh' | sort)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  printf 'FAIL tests/run-all.sh\n'
  printf '  reason: no test files matched tests/test-*.sh\n'
  exit 1
fi

printf 'Running %d test files...\n' "${#TEST_FILES[@]}"

for test_file in "${TEST_FILES[@]}"; do
  TOTAL=$((TOTAL + 1))
  relative_path="tests/$(basename "$test_file")"

  printf '\n==> %s\n' "$relative_path"

  if bash "$test_file"; then
    printf 'PASS %s\n' "$relative_path"
    PASS=$((PASS + 1))
  else
    printf 'FAIL %s\n' "$relative_path"
    FAIL=$((FAIL + 1))
  fi
done

printf '\nSummary: %d passed, %d failed, %d total\n' "$PASS" "$FAIL" "$TOTAL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
