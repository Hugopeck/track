#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0
LAST_STDOUT=''
LAST_STDERR=''
LAST_TODO=''

run_capture() {
  local name="$1"
  local expected_exit="$2"
  shift 2
  local actual_exit=0

  LAST_STDOUT="$(mktemp)"
  LAST_STDERR="$(mktemp)"
  "$@" >"$LAST_STDOUT" 2>"$LAST_STDERR" || actual_exit=$?

  if [[ $actual_exit -eq $expected_exit ]]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (expected exit %d, got %d)\n' "$name" "$expected_exit" "$actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -Fq -- "$pattern" "$file"; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (pattern "%s" not found in %s)\n' "$name" "$pattern" "$file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -Fq -- "$pattern" "$file"; then
    printf '  FAIL: %s (unexpected pattern "%s" found in %s)\n' "$name" "$pattern" "$file"
    FAIL=$((FAIL + 1))
  else
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  fi
}

assert_file_empty() {
  local name="$1"
  local file="$2"

  if [[ ! -s "$file" ]]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (expected empty file %s)\n' "$name" "$file"
    FAIL=$((FAIL + 1))
  fi
}

assert_line_order() {
  local name="$1"
  local file="$2"
  local first="$3"
  local second="$4"
  local first_line second_line

  first_line="$(grep -nF -- "$first" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$file" | head -n 1 | cut -d: -f1)"

  if [[ -n "$first_line" && -n "$second_line" && $first_line -lt $second_line ]]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (order not satisfied: "%s" before "%s")\n' "$name" "$first" "$second"
    FAIL=$((FAIL + 1))
  fi
}

cleanup_capture() {
  rm -f "${LAST_STDOUT:-}" "${LAST_STDERR:-}"
  LAST_STDOUT=''
  LAST_STDERR=''
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-todo.sh "$tmp/.track/scripts/"

  mkdir -p "$tmp/.test-bin"
  cat > "$tmp/.test-bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${TRACK_TEST_GH_OPEN_PR_LINES:-}" ]]; then
  printf '%b' "$TRACK_TEST_GH_OPEN_PR_LINES"
fi
GH
  chmod +x "$tmp/.test-bin/gh"

  printf '%s' "$tmp"
}

finalize_repo_with_git() {
  local repo="$1"
  git -C "$repo" init -q
  git -C "$repo" checkout -q -b main
  git -C "$repo" add -A
  git -C "$repo" -c user.email=test@example.com -c user.name='Track Tests' commit -q -m 'init fixture'

  git init -q --bare "$repo/origin.git"
  git -C "$repo" remote add origin "$repo/origin.git"
  git -C "$repo" push -q -u origin main
}

write_task() {
  local dir="$1"
  local filename="$2"
  local content="$3"
  printf '%s' "$content" > "$dir/.track/tasks/$filename"
}

write_project() {
  local dir="$1"
  local filename="$2"
  local content="$3"
  printf '%s' "$content" > "$dir/.track/projects/$filename"
}

extract_section() {
  local file="$1"
  local heading="$2"
  local out
  out="$(mktemp)"
  awk -v heading="$heading" '
    $0 == heading { in_section = 1; print; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file" > "$out"
  printf '%s' "$out"
}

run_todo_shared_capture() {
  local name="$1"
  local expected_exit="$2"
  local repo="$3"
  LAST_TODO="$repo/TODO-shared.md"
  run_capture "$name" "$expected_exit" \
    env PATH="$repo/.test-bin:$PATH" TRACK_TEST_GH_OPEN_PR_LINES="${TRACK_TEST_GH_OPEN_PR_LINES:-}" \
    bash -c 'cd "$1" && bash .track/scripts/track-todo.sh --output "$2"' _ "$repo" "$LAST_TODO"
}

run_todo_offline_capture() {
  local name="$1"
  local expected_exit="$2"
  local repo="$3"
  LAST_TODO="$repo/TODO-offline.md"
  run_capture "$name" "$expected_exit" \
    bash -c 'cd "$1" && bash .track/scripts/track-todo.sh --local --offline --output "$2"' _ "$repo" "$LAST_TODO"
}

printf 'Running extended TODO tests...\n\n'

printf '── Shared-mode TODO coverage ──\n'

repo="$(setup_repo)"
write_task "$repo" "1.4-active-task.md" "---
id: \"1.4\"
title: \"Active task\"
status: active
mode: implement
priority: low
project_id: \"1\"
created: 2026-01-03
updated: 2026-01-03
depends_on: []
files: []
pr: \"\"
---

## Context
Active work item.

## Acceptance Criteria
- [ ] Active

## Notes
None."
write_task "$repo" "1.5-low-backlog.md" "---
id: \"1.5\"
title: \"Low backlog\"
status: todo
mode: implement
priority: low
project_id: \"1\"
created: 2026-01-03
updated: 2026-01-03
depends_on: []
files: []
pr: \"\"
---

## Context
Low-priority backlog.

## Acceptance Criteria
- [ ] Backlog

## Notes
None."
write_task "$repo" "1.6-urgent-ready.md" "---
id: \"1.6\"
title: \"Urgent ready\"
status: todo
mode: implement
priority: urgent
project_id: \"1\"
created: 2026-01-03
updated: 2026-01-03
depends_on: []
files: []
pr: \"\"
---

## Context
Urgent ready task.

## Acceptance Criteria
- [ ] Ready

## Notes
None."
write_task "$repo" "1.7-overlap-active.md" "---
id: \"1.7\"
title: \"Overlap active\"
status: active
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-03
updated: 2026-01-03
depends_on: []
files:
  - \"src/api/**\"
pr: \"\"
---

## Context
Active overlapping task.

## Acceptance Criteria
- [ ] Active

## Notes
None."
write_task "$repo" "1.8-overlap-blocked.md" "---
id: \"1.8\"
title: \"Overlap blocked\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-03
updated: 2026-01-03
depends_on: []
files:
  - \"src/**\"
pr: \"\"
---

## Context
Blocked by overlapping files.

## Acceptance Criteria
- [ ] Blocked

## Notes
None."
write_project "$repo" "2-cross-project.md" "# Cross Project

## Goal
Second project for dependency rendering.
"
write_task "$repo" "2.1-cross-project-followup.md" "---
id: \"2.1\"
title: \"Cross project follow-up\"
status: todo
mode: implement
priority: high
project_id: \"2\"
created: 2026-01-03
updated: 2026-01-03
depends_on:
  - \"1.2\"
files:
  - \"docs/**\"
pr: \"\"
---

## Context
Depends on another project.

## Acceptance Criteria
- [ ] Follow up

## Notes
None."
write_project "$repo" "3-empty-project.md" "# Empty Project

## Goal
Project with no tasks.
"
finalize_repo_with_git "$repo"
TRACK_TEST_GH_OPEN_PR_LINES=$'https://example.test/pr/1\ttrue\ttask/1.4-active-task\tmain\tOPEN\nhttps://example.test/pr/2\ttrue\ttask/1.7-overlap-active\tmain\tOPEN\n' \
  run_todo_shared_capture "shared TODO generation succeeds" 0 "$repo"
assert_file_contains "shared TODO stdout includes output path" "$LAST_STDOUT" "Wrote $repo/TODO-shared.md"
assert_file_empty "shared TODO keeps stderr empty" "$LAST_STDERR"
assert_line_order "active tasks sort before todo tasks" "$LAST_TODO" "| [1.4](.track/tasks/1.4-active-task.md)" "| [1.6](.track/tasks/1.6-urgent-ready.md)"
assert_line_order "urgent todo sorts before low todo" "$LAST_TODO" "| [1.6](.track/tasks/1.6-urgent-ready.md)" "| [1.5](.track/tasks/1.5-low-backlog.md)"
assert_file_contains "cross-project dependency edge is rendered" "$LAST_TODO" "1 -> 2"
assert_file_contains "empty project heading is rendered" "$LAST_TODO" "## Project 3: Empty Project"
assert_file_contains "overlap-blocked task still appears in work table" "$LAST_TODO" "| [1.8](.track/tasks/1.8-overlap-blocked.md)"
section_file="$(extract_section "$LAST_TODO" "## Immediate Starts")"
assert_file_contains "immediate starts includes unblocked urgent task" "$section_file" "Urgent ready"
assert_file_contains "immediate starts includes cross-project ready task" "$section_file" "Cross project follow-up"
assert_file_contains "immediate starts keeps ready fixture task" "$section_file" "Test task"
assert_file_not_contains "dependency-blocked task excluded from immediate starts" "$section_file" "Dependent task"
assert_file_not_contains "active task excluded from immediate starts" "$section_file" "Active task"
assert_file_not_contains "overlap-active task excluded from immediate starts" "$section_file" "Overlap active"
assert_file_not_contains "overlap-blocked task excluded from immediate starts" "$section_file" "Overlap blocked"
rm -f "$section_file"
section_file="$(extract_section "$LAST_TODO" "## Project 3: Empty Project")"
assert_file_contains "empty project still renders task table header" "$section_file" "| ID | Task | Mode | Priority | Depends | Status |"
assert_file_not_contains "empty project has no task rows" "$section_file" "| [3."
rm -f "$section_file"
cleanup_capture
rm -rf "$repo"
unset TRACK_TEST_GH_OPEN_PR_LINES

printf '\n── Warning coverage ──\n'

repo="$(setup_repo)"
run_todo_offline_capture "offline TODO generation succeeds" 0 "$repo"
assert_file_contains "offline TODO stdout includes output path" "$LAST_STDOUT" "Wrote $repo/TODO-offline.md"
assert_file_empty "offline TODO keeps stderr empty" "$LAST_STDERR"
assert_file_contains "warnings header is rendered" "$LAST_TODO" "## Warnings"
assert_file_contains "offline warning is rendered" "$LAST_TODO" "offline mode enabled; skipping GitHub PR lookup"
cleanup_capture
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
