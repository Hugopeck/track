#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/runtime/scripts/track-common.sh"
VALIDATE_SCRIPT="$SCRIPT_DIR/../skills/validate/scripts/track-validate.sh"
TODO_SCRIPT="$SCRIPT_DIR/../skills/todo/scripts/track-todo.sh"
COMPLETE_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-complete.sh"
TASK_STATUS_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-task-status.sh"
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

check_contains() {
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

check_not_contains() {
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

check_order() {
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
    printf '  FAIL: %s (expected "%s" before "%s")\n' "$name" "$first" "$second"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"

  mkdir -p "$tmp/.track"/{projects,tasks,scripts}
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/"
  cp "$VALIDATE_SCRIPT" "$tmp/.track/scripts/"
  cp "$TODO_SCRIPT" "$tmp/.track/scripts/"
  cp "$TASK_STATUS_SCRIPT" "$tmp/.track/scripts/"
  cp "$COMPLETE_SCRIPT" "$tmp/.track/scripts/"

  cat > "$tmp/.track/projects/1-api-foundations.md" <<'EOF'
---
id: "1"
title: "API Foundations"
priority: high
status: active
created: 2026-01-01
updated: 2026-01-01
---

# API Foundations

## Goal
Ship the core API building blocks needed for follow-on tasks.

## Why Now
Project 1 unblocks the rest of the roadmap.

## In Scope
- API plumbing
- Follow-up integration

## Out Of Scope
- Launch operations

## Shared Context
This project owns the backend setup.

## Dependency Notes
Task 1.2 depends on 1.1.

## Success Definition
Project 1 tasks flow cleanly through the lifecycle.

## Candidate Task Seeds
- Foundation plumbing
- Blocked follow-up
EOF

  cat > "$tmp/.track/projects/2-platform-launch.md" <<'EOF'
---
id: "2"
title: "Platform Launch"
priority: urgent
status: active
created: 2026-01-01
updated: 2026-01-01
---

# Platform Launch

## Goal
Prepare launch operations for the next release.

## Why Now
Launch work is the highest-priority track item.

## In Scope
- Release kickoff

## Out Of Scope
- Backend follow-up tasks

## Shared Context
This project tracks launch preparation.

## Dependency Notes
Independent from project 1.

## Success Definition
Launch tasks are visible at the top of TODO.md.

## Candidate Task Seeds
- Urgent launch checklist
EOF

  cat > "$tmp/.track/tasks/1.1-foundation-plumbing.md" <<'EOF'
---
id: "1.1"
title: "Foundation plumbing"
status: todo
mode: implement
priority: high
project_id: "1"
created: 2026-03-20
updated: 2026-03-20
depends_on: []
files:
  - "src/api/**"
pr: ""
---

## Context
Set up the foundation that later work depends on.

## Acceptance Criteria
- [ ] Plumbing is ready for follow-on tasks

## Notes
This task should be completed by the lifecycle test.
EOF

  cat > "$tmp/.track/tasks/1.2-blocked-follow-up.md" <<'EOF'
---
id: "1.2"
title: "Blocked follow-up"
status: todo
mode: implement
priority: medium
project_id: "1"
created: 2026-03-20
updated: 2026-03-20
depends_on:
  - "1.1"
files:
  - "src/ui/**"
pr: ""
---

## Context
This task should stay blocked until task 1.1 is done.

## Acceptance Criteria
- [ ] Follow-up work can start after 1.1 completes

## Notes
Used to verify immediate-start dependency handoff.
EOF

  cat > "$tmp/.track/tasks/1.3-archived-note.md" <<'EOF'
---
id: "1.3"
title: "Archived note"
status: done
mode: implement
priority: low
project_id: "1"
created: 2026-03-19
updated: 2026-03-21
depends_on: []
files:
  - "docs/**"
pr: "https://github.com/test/repo/pull/11"
---

## Context
Historical task to keep a done row in the project table.

## Acceptance Criteria
- [x] Historical work is preserved

## Notes
Used to verify terminal tasks sort after open work.
EOF

  cat > "$tmp/.track/tasks/2.1-urgent-launch-checklist.md" <<'EOF'
---
id: "2.1"
title: "Urgent launch checklist"
status: todo
mode: implement
priority: urgent
project_id: "2"
created: 2026-03-20
updated: 2026-03-20
depends_on: []
files:
  - "ops/**"
pr: ""
---

## Context
Highest-priority task in a separate project.

## Acceptance Criteria
- [ ] Launch prep can begin immediately

## Notes
Used to verify project grouping order.
EOF

  (cd "$tmp" && git init -q >/dev/null 2>&1)

  printf '%s' "$tmp"
}

printf 'Running E2E lifecycle tests...\n'

repo="$(setup_repo)"
today="$(date -u +'%Y-%m-%d')"
board_before="$repo/BOARD-before.md"
board_after="$repo/BOARD-after.md"
completed_task="$repo/.track/tasks/1.1-foundation-plumbing.md"
completed_pr='https://github.com/test/repo/pull/73'

run_test "initial validation passes" 0 run_validate_clean "$repo/.track/scripts/track-validate.sh"
run_test "pull_request context tolerates pre-sync todo state" 0 env PATH='/usr/bin:/bin' GITHUB_EVENT_NAME='pull_request' GITHUB_HEAD_REF='task/1.1-foundation-plumbing' PR_TITLE='[1.1] Foundation plumbing' PR_BODY='Track-Task: 1.1' bash "$repo/.track/scripts/track-validate.sh"
run_test "initial Track view generation passes" 0 bash "$repo/.track/scripts/track-todo.sh" --local --offline --output "$board_before"

if [[ -f "$board_before" && -f "$repo/TODO.md" && -f "$repo/PROJECTS.md" ]]; then
  check_contains "BOARD includes project 2 section" "$board_before" "## [Project 2: Platform Launch]"
  check_contains "BOARD includes project 1 section" "$board_before" "## [Project 1: API Foundations]"
  check_order "projects sorted by highest-priority open task" "$board_before" "## [Project 2: Platform Launch]" "## [Project 1: API Foundations]"
  check_order "project 1 open tasks sort before done tasks" "$board_before" "| [1.1](.track/tasks/1.1-foundation-plumbing.md) |" "| [1.2](.track/tasks/1.2-blocked-follow-up.md) |"
  check_order "project 1 done task sorts last" "$board_before" "| [1.2](.track/tasks/1.2-blocked-follow-up.md) |" "| [1.3](.track/tasks/1.3-archived-note.md) |"
  check_contains "independent task is an immediate start" "$repo/TODO.md" '- [ ] [2.1] [Urgent launch checklist](.track/tasks/2.1-urgent-launch-checklist.md)'
  check_contains "dependency source is an immediate start" "$repo/TODO.md" '- [ ] [1.1] [Foundation plumbing](.track/tasks/1.1-foundation-plumbing.md)'
  check_contains "dependent task stays blocked before completion" "$repo/TODO.md" '- [ ] [1.2] [Blocked follow-up](.track/tasks/1.2-blocked-follow-up.md) *(Depends on 1.1)*'
  check_contains "PROJECTS includes project 2 summary" "$repo/PROJECTS.md" "| [2](.track/projects/2-platform-launch.md) | Platform Launch |"
  check_contains "PROJECTS includes project 1 summary" "$repo/PROJECTS.md" "| [1](.track/projects/1-api-foundations.md) | API Foundations |"
else
  printf '  FAIL: initial Track views were not created\n'
  FAIL=$((FAIL + 1))
fi

run_test "completion updates dependency task" 0 bash "$repo/.track/scripts/track-complete.sh" "task/1.1-foundation-plumbing" "$completed_pr"
check_contains "completed task status set to done" "$completed_task" 'status: done'
check_contains "completed task PR URL recorded" "$completed_task" "pr: \"$completed_pr\""
check_contains "completed task updated date recorded" "$completed_task" "updated: $today"

run_test "validation after completion passes" 0 run_validate_clean "$repo/.track/scripts/track-validate.sh"
run_test "Track view regeneration after completion passes" 0 bash "$repo/.track/scripts/track-todo.sh" --local --offline --output "$board_after"

if [[ -f "$board_after" && -f "$repo/TODO.md" ]]; then
  check_contains "dependent task becomes immediate start after completion" "$repo/TODO.md" '- [ ] [1.2] [Blocked follow-up](.track/tasks/1.2-blocked-follow-up.md)'
else
  printf '  FAIL: updated Track views were not created\n'
  FAIL=$((FAIL + 1))
fi

rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
