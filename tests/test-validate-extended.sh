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

check_stderr_contains() {
  local name="$1"
  local pattern="$2"
  local stderr_file="$3"

  if grep -q "$pattern" "$stderr_file"; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (pattern "%s" not in stderr)\n' "$name" "$pattern"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-validate.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

write_task() {
  local dir="$1"
  local filename="$2"
  local content="$3"
  printf '%s' "$content" > "$dir/.track/tasks/$filename"
}

TASK_TEMPLATE_BODY='
## Context
Test.

## Acceptance Criteria
- [ ] Done

## Notes
None.'

printf 'Running extended validation tests...\n\n'

# ─── Dependency validation ───────────────────────────────────────────

printf '── Dependency validation ──\n'

# Active task depending on non-done dependency → fail
repo="$(setup_repo)"
write_task "$repo" "1.4-active-blocked.md" "---
id: \"1.4\"
title: \"Active blocked\"
status: active
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"1.1\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "active task with non-done dep fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions active/review depends on todo" "active/review task depends on" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# Review task depending on non-done dependency → fail
repo="$(setup_repo)"
write_task "$repo" "1.4-review-blocked.md" "---
id: \"1.4\"
title: \"Review blocked\"
status: review
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"1.1\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "review task with non-done dep fails" 1 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Active task depending on done dependency → pass
repo="$(setup_repo)"
write_task "$repo" "1.4-active-unblocked.md" "---
id: \"1.4\"
title: \"Active unblocked\"
status: active
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"1.2\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "active task with done dep passes" 0 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Dependency on missing task → fail
repo="$(setup_repo)"
write_task "$repo" "1.4-missing-dep.md" "---
id: \"1.4\"
title: \"Missing dep\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"99.1\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "dependency on missing task fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions missing task" "missing task" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# Self-dependency → fail
repo="$(setup_repo)"
write_task "$repo" "1.4-self-dep.md" "---
id: \"1.4\"
title: \"Self dep\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"1.4\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "self-dependency fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions self-reference" "may not reference task itself" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# Todo task with non-done dep → pass (only active/review are blocked)
repo="$(setup_repo)"
write_task "$repo" "1.4-todo-with-dep.md" "---
id: \"1.4\"
title: \"Todo with dep\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - \"1.1\"
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "todo task with non-done dep passes" 0 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# ─── Duplicate IDs ───────────────────────────────────────────────────

printf '\n── Duplicate IDs ──\n'

repo="$(setup_repo)"
write_task "$repo" "1.1-duplicate.md" "---
id: \"1.1\"
title: \"Duplicate\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "duplicate task ID fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions duplicate" "duplicate task id" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# ─── Legacy ID handling ─────────────────────────────────────────────

printf '\n── Legacy ID handling ──\n'

# Valid legacy ID: done + project_id 0 → pass
repo="$(setup_repo)"
# Add project 0 brief
cat > "$repo/.track/projects/0-legacy.md" << 'EOF'
# Legacy

## Goal
Archive for legacy tasks.
EOF
write_task "$repo" "100-legacy-done.md" "---
id: \"100\"
title: \"Legacy done\"
status: done
mode: implement
priority: medium
project_id: \"0\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "valid legacy ID (done, project 0) passes" 0 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Legacy ID that's not done → fail
repo="$(setup_repo)"
cat > "$repo/.track/projects/0-legacy.md" << 'EOF'
# Legacy

## Goal
Archive for legacy tasks.
EOF
write_task "$repo" "100-legacy-active.md" "---
id: \"100\"
title: \"Legacy active\"
status: active
mode: implement
priority: medium
project_id: \"0\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "legacy ID with non-terminal status fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions legacy" "legacy numeric task ids" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# Legacy ID with wrong project_id → fail
repo="$(setup_repo)"
write_task "$repo" "100-legacy-wrong-project.md" "---
id: \"100\"
title: \"Legacy wrong project\"
status: done
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "legacy ID with non-zero project fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions project_id 0" "must use project_id" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# ─── Cancelled task handling ─────────────────────────────────────────

printf '\n── Cancelled task handling ──\n'

# Cancelled without reason → fail
repo="$(setup_repo)"
write_task "$repo" "1.4-cancelled-no-reason.md" "---
id: \"1.4\"
title: \"Cancelled no reason\"
status: cancelled
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "cancelled without reason fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions cancelled_reason" "cancelled_reason" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# Cancelled with reason → pass
repo="$(setup_repo)"
write_task "$repo" "1.4-cancelled-with-reason.md" "---
id: \"1.4\"
title: \"Cancelled with reason\"
status: cancelled
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
cancelled_reason: \"No longer needed\"
---
${TASK_TEMPLATE_BODY}"
run_test "cancelled with reason passes" 0 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# ─── Dotted ID / project_id mismatch ────────────────────────────────

printf '\n── Dotted ID / project mismatch ──\n'

repo="$(setup_repo)"
write_task "$repo" "1.4-wrong-project.md" "---
id: \"2.4\"
title: \"Wrong project\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "dotted ID mismatching project_id fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions dotted id mismatch" "dotted id" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# ─── Missing required sections ──────────────────────────────────────

printf '\n── Missing required sections ──\n'

repo="$(setup_repo)"
write_task "$repo" "1.4-no-sections.md" "---
id: \"1.4\"
title: \"No sections\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---

Some content without proper sections."
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "missing required sections fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions missing section" "missing required section" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# ─── Unknown project_id ─────────────────────────────────────────────

printf '\n── Unknown project_id ──\n'

repo="$(setup_repo)"
write_task "$repo" "99.1-ghost-project.md" "---
id: \"99.1\"
title: \"Ghost project\"
status: todo
mode: implement
priority: medium
project_id: \"99\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
stderr_file="$(mktemp)"
bash "$repo/.track/scripts/track-validate.sh" 2>"$stderr_file" || true
run_test "unknown project_id fails" 1 bash "$repo/.track/scripts/track-validate.sh"
check_stderr_contains "error mentions unknown project" "unknown project_id" "$stderr_file"
rm -f "$stderr_file"
rm -rf "$repo"

# ─── Invalid field values ────────────────────────────────────────────

printf '\n── Invalid field values ──\n'

# Invalid mode
repo="$(setup_repo)"
write_task "$repo" "1.4-bad-mode.md" "---
id: \"1.4\"
title: \"Bad mode\"
status: todo
mode: execute
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "invalid mode fails" 1 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

# Invalid priority
repo="$(setup_repo)"
write_task "$repo" "1.4-bad-priority.md" "---
id: \"1.4\"
title: \"Bad priority\"
status: todo
mode: implement
priority: critical
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_test "invalid priority fails" 1 bash "$repo/.track/scripts/track-validate.sh"
rm -rf "$repo"

printf '\n── Results ──\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
