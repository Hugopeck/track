#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRITEBACK_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-complete-writeback.sh"
MANIFEST_FILE="$SCRIPT_DIR/../skills/setup-track/assets/install-manifest.json"
REPO_COMPLETE_WORKFLOW="$SCRIPT_DIR/../.github/workflows/track-complete.yml"
COMPLETE_WORKFLOW="$SCRIPT_DIR/../skills/setup-track/assets/workflows/track-complete.yml"
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

run_capture() {
  STDOUT_FILE="$(mktemp)"
  STDERR_FILE="$(mktemp)"
  RUN_EXIT=0
  "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || RUN_EXIT=$?
}

cleanup_capture() {
  rm -f "$STDOUT_FILE" "$STDERR_FILE"
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

assert_stdout_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDOUT_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stdout pattern: %s\n' "$pattern"
  fi
}

assert_file_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$file"
  fi
}

assert_text_contains() {
  local name="$1"
  local text="$2"
  local pattern="$3"
  if printf '%s' "$text" | grep -Fq -- "$pattern"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$text"
  fi
}

assert_files_equal() {
  local name="$1"
  local left="$2"
  local right="$3"
  if cmp -s "$left" "$right"; then
    pass "$name"
  else
    fail "$name"
    printf '    files differ: %s %s\n' "$left" "$right"
  fi
}

setup_remote_repo() {
  local tmp bare work mode
  mode="$1"
  tmp="$(mktemp -d)"
  bare="$tmp/remote.git"
  work="$tmp/work"

  git init --bare -q "$bare"

  if [[ "$mode" == 'reject-main' ]]; then
    cat > "$bare/hooks/update" <<'HOOK'
#!/usr/bin/env bash
ref="$1"
if [[ "$ref" == 'refs/heads/main' ]]; then
  echo 'pushes to main are blocked' >&2
  exit 1
fi
exit 0
HOOK
    chmod +x "$bare/hooks/update"
  fi

  git clone -q "$bare" "$work" >/dev/null 2>&1
  (
    cd "$work"
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    mkdir -p .track/tasks
    cat > .track/tasks/1.1-test-task.md <<'TASK'
---
id: "1.1"
title: "Test task"
status: review
mode: implement
priority: high
project_id: "1"
created: 2026-03-31
updated: 2026-03-31
depends_on: []
files: []
pr: ""
---

## Context
Fixture.

## Acceptance Criteria
- [ ] Done

## Notes
Fixture.
TASK
    git add .track/tasks/1.1-test-task.md
    git commit -q -m 'chore: add fixture task'
    git branch -M main
    git push -q origin main
  )

  printf '%s\n%s' "$tmp" "$work"
}

printf 'Running track-complete-writeback tests...\n\n'

if [[ -f "$WRITEBACK_SCRIPT" ]]; then
  pass 'writeback helper exists'
else
  fail 'writeback helper exists'
fi

if grep -Fq -- 'track-complete-writeback.sh' "$MANIFEST_FILE"; then
  pass 'manifest installs writeback helper'
else
  fail 'manifest installs writeback helper'
fi

if grep -Fq -- 'pull-requests: write' "$COMPLETE_WORKFLOW"; then
  pass 'workflow can open writeback PRs'
else
  fail 'workflow can open writeback PRs'
fi

if grep -Fq -- 'bash .track/scripts/track-complete-writeback.sh' "$COMPLETE_WORKFLOW"; then
  pass 'workflow uses writeback helper'
else
  fail 'workflow uses writeback helper'
fi

assert_files_equal 'track-complete workflow matches asset copy' "$REPO_COMPLETE_WORKFLOW" "$COMPLETE_WORKFLOW"

if grep -Fq -- 'completion-writeback-metadata:' "$COMPLETE_WORKFLOW"; then
  pass 'workflow defines writeback metadata job'
else
  fail 'workflow defines writeback metadata job'
fi

if grep -Fq -- 'WRITEBACK_BRANCH: track/complete-${{ github.event.pull_request.number }}' "$COMPLETE_WORKFLOW"; then
  pass 'workflow names writeback branch deterministically'
else
  fail 'workflow names writeback branch deterministically'
fi

if grep -Fq -- 'gh pr list \' "$COMPLETE_WORKFLOW"; then
  pass 'workflow looks up writeback PR'
else
  fail 'workflow looks up writeback PR'
fi

if grep -Fq -- 'Expected open writeback PR for $WRITEBACK_BRANCH, but none was found.' "$COMPLETE_WORKFLOW"; then
  pass 'workflow errors when branch exists without PR'
else
  fail 'workflow errors when branch exists without PR'
fi

if grep -Fq -- "-f context='Track Validate'" "$COMPLETE_WORKFLOW"; then
  pass 'workflow posts Track Validate status'
else
  fail 'workflow posts Track Validate status'
fi

if grep -Fq -- "-f context='Track PR Lint'" "$COMPLETE_WORKFLOW"; then
  pass 'workflow posts Track PR Lint status'
else
  fail 'workflow posts Track PR Lint status'
fi

if grep -Fq -- "-f context='conventional-commit-lint'" "$COMPLETE_WORKFLOW"; then
  pass 'workflow posts conventional-commit-lint status'
else
  fail 'workflow posts conventional-commit-lint status'
fi

if grep -Fq -- 'Mark Track Validate pending' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark Track Validate success' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark Track Validate failure' "$COMPLETE_WORKFLOW"; then
  pass 'workflow covers Track Validate pending success failure'
else
  fail 'workflow covers Track Validate pending success failure'
fi

if grep -Fq -- 'Mark Track PR Lint pending' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark Track PR Lint success' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark Track PR Lint failure' "$COMPLETE_WORKFLOW"; then
  pass 'workflow covers Track PR Lint pending success failure'
else
  fail 'workflow covers Track PR Lint pending success failure'
fi

if grep -Fq -- 'Mark conventional-commit-lint pending' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark conventional-commit-lint success' "$COMPLETE_WORKFLOW" && grep -Fq -- 'Mark conventional-commit-lint failure' "$COMPLETE_WORKFLOW"; then
  pass 'workflow covers conventional-commit-lint pending success failure'
else
  fail 'workflow covers conventional-commit-lint pending success failure'
fi

if grep -Fq -- 'bash .track/scripts/track-validate.sh' "$COMPLETE_WORKFLOW"; then
  pass 'workflow runs track validate on writeback head'
else
  fail 'workflow runs track validate on writeback head'
fi

if grep -Fq -- 'bash .track/scripts/track-pr-lint.sh' "$COMPLETE_WORKFLOW"; then
  pass 'workflow runs track pr lint on writeback head'
else
  fail 'workflow runs track pr lint on writeback head'
fi

if grep -Fq -- 'bash .track/scripts/track-conventional-commit-lint.sh' "$COMPLETE_WORKFLOW"; then
  pass 'workflow runs conventional commit lint on writeback head'
else
  fail 'workflow runs conventional commit lint on writeback head'
fi

if grep -Fq -- 'writeback head has no parent commit; cannot lint commit range' "$COMPLETE_WORKFLOW"; then
  pass 'workflow errors clearly when writeback head has no parent'
else
  fail 'workflow errors clearly when writeback head has no parent'
fi

repo_info="$(setup_remote_repo allow-main)"
tmp_dir="${repo_info%%$'\n'*}"
repo="${repo_info#*$'\n'}"
cd "$repo"
printf 'updated\n' >> .track/tasks/1.1-test-task.md
run_capture env BASE_REF='main' PR_NUMBER='66' PR_URL='https://github.com/test/repo/pull/66' bash "$WRITEBACK_SCRIPT"
assert_code 'direct push succeeds when main is writable' 0
assert_stdout_contains 'direct push path is reported' 'Pushed completion writeback directly to main.'
remote_subject="$(git --git-dir="$tmp_dir/remote.git" log --format=%s -1 refs/heads/main)"
assert_text_contains 'remote main received writeback commit' "$remote_subject" 'fix(track): complete merged task'
cleanup_capture
cd "$SCRIPT_DIR"
rm -rf "$tmp_dir"

repo_info="$(setup_remote_repo reject-main)"
tmp_dir="${repo_info%%$'\n'*}"
repo="${repo_info#*$'\n'}"
mock_bin="$tmp_dir/mock-bin"
gh_log="$tmp_dir/gh.log"
mkdir -p "$mock_bin"
cat > "$mock_bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'pr list')
    printf '%s' "${GH_PR_LIST_OUTPUT:-null}"
    ;;
  'pr create')
    printf '%s\n' "$*" >> "$GH_LOG_FILE"
    printf 'https://github.com/test/repo/pull/99\n'
    ;;
  *)
    echo "unsupported gh invocation: $*" >&2
    exit 1
    ;;
esac
GH
chmod +x "$mock_bin/gh"
cd "$repo"
printf 'updated\n' >> .track/tasks/1.1-test-task.md
run_capture env PATH="$mock_bin:$PATH" GH_LOG_FILE="$gh_log" GH_PR_LIST_OUTPUT='null' BASE_REF='main' PR_NUMBER='66' PR_URL='https://github.com/test/repo/pull/66' WRITEBACK_BRANCH='track/complete-66' WRITEBACK_TITLE='fix(track): complete merged task for #66' bash "$WRITEBACK_SCRIPT"
assert_code 'writeback falls back to PR when main rejects push' 0
assert_stdout_contains 'fallback path is reported' 'Direct push to main failed; opening writeback PR.'
assert_stdout_contains 'fallback opens PR' 'Opened completion writeback PR from track/complete-66.'
assert_file_contains 'fallback created PR with expected title' "$gh_log" '--title fix(track): complete merged task for #66'
if git --git-dir="$tmp_dir/remote.git" show-ref --verify --quiet refs/heads/track/complete-66; then
  pass 'fallback pushes writeback branch'
else
  fail 'fallback pushes writeback branch'
fi
cleanup_capture
cd "$SCRIPT_DIR"
rm -rf "$tmp_dir"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
