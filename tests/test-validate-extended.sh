#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0
repo=''
bare_dir=''

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

run_capture() {
  STDOUT_FILE="$(mktemp)"
  STDERR_FILE="$(mktemp)"
  RUN_EXIT=0
  "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || RUN_EXIT=$?
}

assert_code() {
  local name="$1"
  local expected="$2"
  if [[ $RUN_EXIT -eq $expected ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected=%s got=%s\n' "$expected" "$RUN_EXIT"
  fi
}

assert_stderr_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDERR_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stderr pattern: %s\n' "$pattern"
  fi
}

cleanup_capture() {
  rm -f "$STDOUT_FILE" "$STDERR_FILE"
}

run_validate_clean() {
  env \
    -u GITHUB_EVENT_NAME \
    -u GITHUB_HEAD_REF \
    -u PR_TITLE \
    -u PR_BODY \
    -u PR_LABELS \
    -u GH_TOKEN \
    "$@"
}

setup_repo() {
  local tmp bare
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-validate.sh "$tmp/.track/scripts/"

  git -C "$tmp" init -b main >/dev/null
  git -C "$tmp" config user.email test@example.com
  git -C "$tmp" config user.name test

  bare="$(mktemp -d)"
  git init --bare "$bare/origin.git" >/dev/null
  git -C "$tmp" remote add origin "$bare/origin.git"

  repo="$tmp"
  bare_dir="$bare"
}

write_task() {
  local repo_dir="$1"
  local filename="$2"
  local content="$3"
  printf '%s' "$content" > "$repo_dir/.track/tasks/$filename"
}

commit_and_push_main() {
  local repo_dir="$1"
  git -C "$repo_dir" add .track >/dev/null
  git -C "$repo_dir" commit -m 'fixtures' >/dev/null
  git -C "$repo_dir" push -u origin main >/dev/null
  git -C "$repo_dir" fetch origin main:refs/remotes/origin/main >/dev/null 2>/dev/null
}

write_gh_mock() {
  local dir="$1"
  local mode="$2"
  mkdir -p "$dir"
  cat > "$dir/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
mode="__MODE__"

if [[ "$1 $2" == 'pr list' && "$*" == *'--head'* ]]; then
  printf 'true\n'
  exit 0
fi

if [[ "$1 $2" == 'pr list' ]]; then
  case "$mode" in
    different-prs)
      printf '%s\t%s\t%s\t%s\t%s\n' 201 'https://example.com/pr/201' true 'task/1.1-test-task' '[1.1] First'
      printf '%s\t%s\t%s\t%s\t%s\n' 202 'https://example.com/pr/202' true 'feature/second' '[1.3] Second'
      ;;
    single-pr)
      printf '%s\t%s\t%s\t%s\t%s\n' 201 'https://example.com/pr/201' true 'task/1.1-test-task' '[1.1] Single'
      ;;
  esac
  exit 0
fi

if [[ "$1 $2" == 'pr view' ]]; then
  case "$3" in
    201)
      if [[ "$*" == *'--json body'* ]]; then
        printf 'Track-Task: 1.1\n'
      else
        printf ''
      fi
      ;;
    202)
      if [[ "$*" == *'--json body'* ]]; then
        printf 'Track-Task: 1.3\n'
      else
        printf ''
      fi
      ;;
  esac
  exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
GH
  sed -i.bak "s/__MODE__/$mode/" "$dir/gh" && rm -f "$dir/gh.bak"
  chmod +x "$dir/gh"
}

active_task_1_1='---
id: "1.1"
title: "Test task"
status: active
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
A valid test task.

## Acceptance Criteria
- [ ] Tests pass

## Notes
Test fixture.
'

active_task_1_3='---
id: "1.3"
title: "Dependent task"
status: active
mode: implement
priority: high
project_id: "1"
created: 2026-01-01
updated: 2026-01-01
depends_on:
  - "1.1"
files:
  - "src/**"
pr: ""
---

## Context
Depends on 1.1.

## Acceptance Criteria
- [ ] Integration complete

## Notes
Fixture with dependency.
'

printf 'Running extended validation tests...\n\n'

# Two active tasks in different PRs with unresolved dependency fails
setup_repo
write_task "$repo" '1.1-test-task.md' "$active_task_1_1"
write_task "$repo" '1.3-dependent-task.md' "$active_task_1_3"
commit_and_push_main "$repo"
mock_bin="$(mktemp -d)"
write_gh_mock "$mock_bin" different-prs
run_capture run_validate_clean env PATH="$mock_bin:$PATH" bash "$repo/.track/scripts/track-validate.sh"
assert_code 'active task depending on active task in different PR fails' 1
assert_stderr_contains 'cross-pr dependency error surfaced' 'include it in the same PR'
cleanup_capture
rm -rf "$repo" "$bare_dir" "$mock_bin"

# PR context with single Track-Task resolves correctly
setup_repo
write_task "$repo" '1.1-test-task.md' "$active_task_1_1"
commit_and_push_main "$repo"
mock_bin="$(mktemp -d)"
write_gh_mock "$mock_bin" single-pr
run_capture env PATH="$mock_bin:$PATH" TRACK_DEFAULT_BRANCH='skip-main' GITHUB_EVENT_NAME='pull_request' GITHUB_HEAD_REF='task/1.1-test-task' PR_TITLE='[1.1] Single context' PR_BODY='Track-Task: 1.1' bash "$repo/.track/scripts/track-validate.sh"
assert_code 'PR context with single Track-Task resolves' 0
cleanup_capture
rm -rf "$repo" "$bare_dir" "$mock_bin"

# PR context with multiple Track-Task lines errors
setup_repo
write_task "$repo" '1.1-test-task.md' "$active_task_1_1"
write_task "$repo" '1.3-dependent-task.md' "$active_task_1_3"
commit_and_push_main "$repo"
mock_bin="$(mktemp -d)"
write_gh_mock "$mock_bin" single-pr
run_capture env PATH="$mock_bin:$PATH" TRACK_DEFAULT_BRANCH='skip-main' GITHUB_EVENT_NAME='pull_request' GITHUB_HEAD_REF='task/1.1-test-task' PR_TITLE='[1.1] Multi body' PR_BODY=$'Track-Task: 1.1\nTrack-Task: 1.3' bash "$repo/.track/scripts/track-validate.sh"
assert_code 'PR context with multiple Track-Task lines errors' 1
assert_stderr_contains 'multiple Track-Task error surfaced' 'multiple Track-Task values'
cleanup_capture
rm -rf "$repo" "$bare_dir" "$mock_bin"

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
