#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0
LAST_STDOUT=''
LAST_STDERR=''

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
  cp "$SCAFFOLD_SCRIPTS"/track-validate.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

setup_repo_with_git() {
  local tmp
  tmp="$(setup_repo)"

  git -C "$tmp" init -q
  git -C "$tmp" checkout -q -b main
  git -C "$tmp" add -A
  git -C "$tmp" -c user.email=test@example.com -c user.name='Track Tests' commit -q -m 'init fixture'

  git init -q --bare "$tmp/origin.git"
  git -C "$tmp" remote add origin "$tmp/origin.git"
  git -C "$tmp" push -q -u origin main

  mkdir -p "$tmp/.test-bin"
  cat > "$tmp/.test-bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail

if [[ " $* " == *" --head "* ]]; then
  if [[ -n "${TRACK_TEST_GH_DRAFT_STATE:-}" ]]; then
    printf '%s\n' "$TRACK_TEST_GH_DRAFT_STATE"
  fi
  exit 0
fi

if [[ -n "${TRACK_TEST_GH_OPEN_PR_LINES:-}" ]]; then
  printf '%b' "$TRACK_TEST_GH_OPEN_PR_LINES"
fi
GH
  chmod +x "$tmp/.test-bin/gh"

  printf '%s' "$tmp"
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

run_validate_capture() {
  local name="$1"
  local expected_exit="$2"
  local repo="$3"
  shift 3

  run_capture "$name" "$expected_exit" \
    env \
      PATH="$repo/.test-bin:$PATH" \
      TRACK_TEST_GH_OPEN_PR_LINES="${TRACK_TEST_GH_OPEN_PR_LINES:-}" \
      TRACK_TEST_GH_DRAFT_STATE="${TRACK_TEST_GH_DRAFT_STATE:-}" \
      "$@" \
      bash -c 'cd "$1" && bash .track/scripts/track-validate.sh' _ "$repo"
}

TASK_TEMPLATE_BODY='
## Context
Test.

## Acceptance Criteria
- [ ] Done

## Notes
None.'

printf 'Running extended validation tests...\n\n'

printf '── Validation rules ──\n'

repo="$(setup_repo_with_git)"
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
run_validate_capture "active task with non-done dependency fails" 1 "$repo"
assert_file_contains "active dependency error text" "$LAST_STDERR" "active/review task depends on '1.1'"
assert_file_empty "active dependency keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "missing dependency target fails" 1 "$repo"
assert_file_contains "missing dependency error text" "$LAST_STDERR" "depends_on references missing task '99.1'"
assert_file_empty "missing dependency keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "self dependency fails" 1 "$repo"
assert_file_contains "self dependency error text" "$LAST_STDERR" "depends_on may not reference task itself ('1.4')"
assert_file_empty "self dependency keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "duplicate task ids fail" 1 "$repo"
assert_file_contains "duplicate id error text" "$LAST_STDERR" "duplicate task id '1.1'"
assert_file_empty "duplicate id keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_project "$repo" "0-legacy.md" "# Legacy

## Goal
Archive for legacy tasks.
"
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
run_validate_capture "legacy id with non-terminal status fails" 1 "$repo"
assert_file_contains "legacy status error text" "$LAST_STDERR" "legacy numeric task ids are only allowed"
assert_file_empty "legacy status keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "legacy id with non-zero project fails" 1 "$repo"
assert_file_contains "legacy project error text" "$LAST_STDERR" "legacy numeric task id '100' must use project_id '0'"
assert_file_empty "legacy project keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "cancelled task without reason fails" 1 "$repo"
assert_file_contains "cancelled reason error text" "$LAST_STDERR" "cancelled tasks require cancelled_reason"
assert_file_empty "cancelled reason keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "dotted id prefix mismatch fails" 1 "$repo"
assert_file_contains "dotted id mismatch error text" "$LAST_STDERR" "dotted id '2.4' prefix must equal project_id '1'"
assert_file_empty "dotted id mismatch keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
Plain text without required headings."
run_validate_capture "missing required sections fail" 1 "$repo"
assert_file_contains "missing sections error text" "$LAST_STDERR" "missing required section '## Context'"
assert_file_empty "missing sections keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "unknown project id fails" 1 "$repo"
assert_file_contains "unknown project error text" "$LAST_STDERR" "unknown project_id '99'"
assert_file_empty "unknown project keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-bad-status.md" "---
id: \"1.4\"
title: \"Bad status\"
status: queued
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
run_validate_capture "invalid status fails" 1 "$repo"
assert_file_contains "invalid status error text" "$LAST_STDERR" "invalid status 'queued'"
assert_file_empty "invalid status keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "invalid mode fails" 1 "$repo"
assert_file_contains "invalid mode error text" "$LAST_STDERR" "invalid mode 'execute'"
assert_file_empty "invalid mode keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
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
run_validate_capture "invalid priority fails" 1 "$repo"
assert_file_contains "invalid priority error text" "$LAST_STDERR" "invalid priority 'critical'"
assert_file_empty "invalid priority keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

printf '\n── Frontmatter and entrypoint coverage ──\n'

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-malformed-frontmatter.md" "---
id: \"1.4\"
title: \"Malformed frontmatter\"
status: todo
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
${TASK_TEMPLATE_BODY}"
run_validate_capture "malformed YAML frontmatter fails" 1 "$repo"
assert_file_contains "malformed YAML error text" "$LAST_STDERR" "frontmatter never closed"
assert_file_empty "malformed YAML keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-missing-priority.md" "---
id: \"1.4\"
title: \"Missing priority\"
status: todo
mode: implement
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
---
${TASK_TEMPLATE_BODY}"
run_validate_capture "missing required field fails" 1 "$repo"
assert_file_contains "missing field error text" "$LAST_STDERR" "missing required field 'priority'"
assert_file_empty "missing field keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-invalid-id.md" "---
id: \"task-1\"
title: \"Invalid id\"
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
run_validate_capture "invalid task id format fails" 1 "$repo"
assert_file_contains "invalid task id error text" "$LAST_STDERR" "must be dotted format"
assert_file_empty "invalid task id keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
rm -rf "$repo/.track/tasks"
run_validate_capture "missing .track/tasks directory fails" 1 "$repo"
assert_file_contains "missing task dir error text" "$LAST_STDERR" ".track/tasks directory not found"
assert_file_empty "missing task dir keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

printf '\n── Live PR validation coverage ──\n'

repo="$(setup_repo_with_git)"
TRACK_TEST_GH_OPEN_PR_LINES=$'https://example.test/pr/1\ttrue\ttask/9.9-missing-task\tmain\tOPEN\nhttps://example.test/pr/2\tfalse\ttask/1.2-done-task\tmain\tOPEN\nhttps://example.test/pr/3\ttrue\ttask/1.1-test-task-one\tmain\tOPEN\nhttps://example.test/pr/4\tfalse\ttask/1.1-test-task-two\tmain\tOPEN\n' \
  run_validate_capture "open PR metadata validation catches orphaned, terminal, and duplicate PRs" 1 "$repo"
assert_file_contains "open PR detects missing task on default branch" "$LAST_STDERR" "references task '9.9' but no matching task file exists on origin/main"
assert_file_contains "open PR detects terminal task on default branch" "$LAST_STDERR" "references terminal task '1.2'"
assert_file_contains "open PR detects duplicate PR mapping" "$LAST_STDERR" "multiple open PRs map to task '1.1'"
assert_file_empty "open PR validation keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"
unset TRACK_TEST_GH_OPEN_PR_LINES

printf '\n── Pull request context coverage ──\n'

repo="$(setup_repo_with_git)"
run_validate_capture \
  "implementation branch must map to an existing task" \
  1 \
  "$repo" \
  GITHUB_EVENT_NAME=pull_request \
  GITHUB_HEAD_REF=task/9.9-missing-task
assert_file_contains "branch missing-task error text" "$LAST_STDERR" "branch 'task/9.9-missing-task' references task '9.9'"
assert_file_empty "branch missing-task keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-bad-branch.md" "---
id: \"1.4\"
title: \"Bad branch task\"
status: active
mode: implement
priority: medium
project_id: \"1\"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: \"\"
${TASK_TEMPLATE_BODY}"
run_validate_capture \
  "implementation branch surfaces parse errors" \
  1 \
  "$repo" \
  GITHUB_EVENT_NAME=pull_request \
  GITHUB_HEAD_REF=task/1.4-bad-branch
assert_file_contains "branch parse error text" "$LAST_STDERR" "frontmatter never closed"
assert_file_empty "branch parse error keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-done-branch.md" "---
id: \"1.4\"
title: \"Done branch task\"
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
run_validate_capture \
  "implementation branch rejects terminal task status" \
  1 \
  "$repo" \
  GITHUB_EVENT_NAME=pull_request \
  GITHUB_HEAD_REF=task/1.4-done-branch
assert_file_contains "branch terminal-status error text" "$LAST_STDERR" "task on implementation branch may not be 'done'"
assert_file_empty "branch terminal-status keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-review-branch.md" "---
id: \"1.4\"
title: \"Review branch task\"
status: review
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
TRACK_TEST_GH_DRAFT_STATE='true' run_validate_capture \
  "draft PR requires active raw status" \
  1 \
  "$repo" \
  GITHUB_EVENT_NAME=pull_request \
  GITHUB_HEAD_REF=task/1.4-review-branch
assert_file_contains "draft PR mismatch error text" "$LAST_STDERR" "draft PR requires raw status 'active'"
assert_file_empty "draft PR mismatch keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"
unset TRACK_TEST_GH_DRAFT_STATE

repo="$(setup_repo_with_git)"
write_task "$repo" "1.4-active-branch.md" "---
id: \"1.4\"
title: \"Active branch task\"
status: active
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
TRACK_TEST_GH_DRAFT_STATE='false' run_validate_capture \
  "ready PR requires review raw status" \
  1 \
  "$repo" \
  GITHUB_EVENT_NAME=pull_request \
  GITHUB_HEAD_REF=task/1.4-active-branch
assert_file_contains "ready PR mismatch error text" "$LAST_STDERR" "ready-for-review PR requires raw status 'review'"
assert_file_empty "ready PR mismatch keeps stdout empty" "$LAST_STDOUT"
cleanup_capture
rm -rf "$repo"
unset TRACK_TEST_GH_DRAFT_STATE

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
