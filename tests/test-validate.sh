#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/assets/scripts"
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

run_validate_clean() {
  env \
    -u GITHUB_EVENT_NAME \
    -u GITHUB_HEAD_REF \
    -u PR_TITLE \
    -u PR_BODY \
    -u PR_LABELS \
    -u GH_TOKEN \
    bash "$@"
}

# Create a temp dir that looks like a repo with .track/
setup_valid_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-validate.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

# Create an invalid repo (missing required field)
setup_invalid_repo() {
  local tmp
  tmp="$(setup_valid_repo)"
  cat > "$tmp/.track/tasks/1.4-bad-task.md" << 'EOF'
---
id: "1.4"
title: "Bad task"
status: invalid_status
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
Invalid status.

## Acceptance Criteria
- [ ] Something

## Notes
Bad.
EOF
  printf '%s' "$tmp"
}

printf 'Running track-validate tests...\n'

# Test 1: Valid fixtures pass validation
repo="$(setup_valid_repo)"
run_test "valid fixtures pass" 0 run_validate_clean "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Test 2: Invalid status fails validation
repo="$(setup_invalid_repo)"
run_test "invalid status fails" 1 run_validate_clean "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Test 3: Expired plan (8 days old) gets deleted
repo="$(setup_valid_repo)"
mkdir -p "$repo/.track/plans"
expired_date="$(date -u -v-8d +%Y-%m-%d 2>/dev/null || date -u -d '8 days ago' +%Y-%m-%d)"
cat > "$repo/.track/plans/old-plan.md" << EOF
---
title: "Expired plan"
created: $expired_date
---

This plan is old.
EOF
run_validate_clean "$repo/.track/scripts/track-validate.sh" >/dev/null 2>&1 || true
if [[ ! -f "$repo/.track/plans/old-plan.md" ]]; then
  printf '  PASS: expired plan deleted\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL: expired plan not deleted\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$repo"

# Test 4: Fresh plan (1 day old) is preserved
repo="$(setup_valid_repo)"
mkdir -p "$repo/.track/plans"
fresh_date="$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d '1 day ago' +%Y-%m-%d)"
cat > "$repo/.track/plans/fresh-plan.md" << EOF
---
title: "Fresh plan"
created: $fresh_date
---

This plan is recent.
EOF
run_validate_clean "$repo/.track/scripts/track-validate.sh" >/dev/null 2>&1 || true
if [[ -f "$repo/.track/plans/fresh-plan.md" ]]; then
  printf '  PASS: fresh plan preserved\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL: fresh plan was deleted\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$repo"

# Test 5: Plan without created field triggers warning
repo="$(setup_valid_repo)"
mkdir -p "$repo/.track/plans"
cat > "$repo/.track/plans/no-date-plan.md" << 'EOF'
---
title: "No date plan"
---

Missing created field.
EOF
stderr_out="$(run_validate_clean "$repo/.track/scripts/track-validate.sh" 2>&1 >/dev/null || true)"
if echo "$stderr_out" | grep -q "missing 'created' field"; then
  printf '  PASS: missing created field warned\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL: no warning for missing created field\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
