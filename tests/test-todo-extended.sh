#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
COMMON_SCRIPT="$SCRIPT_DIR/../skills/runtime/scripts/track-common.sh"
TODO_SCRIPT="$SCRIPT_DIR/../skills/todo/scripts/track-todo.sh"
TASK_STATUS_HELPER="$SCRIPT_DIR/../skills/work/scripts/track-task-status.sh"
RECONCILE_SCRIPT="$SCRIPT_DIR/../skills/work/scripts/track-reconcile.sh"
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

assert_contains() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$file"
  fi
}

assert_not_contains() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    fail "$name"
    printf '    unexpected pattern %q in %s\n' "$pattern" "$file"
  else
    pass "$name"
  fi
}

assert_exit_code() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected exit %s, got %s\n' "$expected" "$actual"
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/"
  cp "$TODO_SCRIPT" "$tmp/.track/scripts/"
  cp "$TASK_STATUS_HELPER" "$tmp/.track/scripts/"
  cp "$RECONCILE_SCRIPT" "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

write_task() {
  local path="$1"
  local id="$2"
  local title="$3"
  local status="$4"
  local priority="$5"
  local updated="$6"
  local depends_block="$7"
  local extra_fields="${8:-}"

  cat > "$path" <<TASK
---
id: "$id"
title: "$title"
status: $status
mode: implement
priority: $priority
project_id: "1"
created: 2026-01-01
updated: $updated
$depends_block
files: []
pr: ""
$extra_fields
---

## Context
Fixture task.

## Acceptance Criteria
- [ ] Fixture

## Notes
Fixture task.
TASK
}

setup_gh_mock() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail

scenario="${MOCK_SCENARIO:-stale}"

if [[ "$1 $2" == 'pr list' ]]; then
  if [[ "$*" == *'--json number,url,isDraft,headRefName,title'* ]]; then
    case "$scenario" in
      stale)
        printf '%s\t%s\t%s\t%s\t%s\n' 101 'https://example.com/pr/101' true 'task/1.1-test-task' '[1.1] Draft PR'
        printf '%s\t%s\t%s\t%s\t%s\n' 102 'https://example.com/pr/102' false 'feature/label-single' 'Ready single'
        printf '%s\t%s\t%s\t%s\t%s\n' 103 'https://example.com/pr/103' false 'task/1.3-dependent-task' '[1.3] Duplicate branch PR'
        ;;
      partial)
        printf '%s\t%s\t%s\t%s\t%s\n' 201 'https://example.com/pr/201' true 'task/1.1-test-task' '[1.1] Partial PR'
        ;;
      reconcile-safe)
        printf '%s\t%s\t%s\t%s\t%s\n' 301 'https://example.com/pr/301' true 'task/1.1-test-task' '[1.1] Draft PR'
        printf '%s\t%s\t%s\t%s\t%s\n' 302 'https://example.com/pr/302' false 'task/1.3-dependent-task' '[1.3] Ready PR'
        printf '%s\t%s\t%s\t%s\t%s\n' 303 'https://example.com/pr/303' true 'task/1.4-review-drift' '[1.4] Draft PR'
        ;;
      reconcile-conflict)
        printf '%s\t%s\t%s\t%s\t%s\n' 401 'https://example.com/pr/401' true 'task/1.5-blocked-task' '[1.5] Blocked PR'
        ;;
      *)
        echo "unexpected mock scenario: $scenario" >&2
        exit 1
        ;;
    esac
    exit 0
  fi
fi

if [[ "$1 $2" == 'pr view' ]]; then
  pr_number="$3"
  if [[ "$*" == *'--json body'* ]]; then
    case "$scenario:$pr_number" in
      stale:101) printf 'Track-Task: 1.1\n' ;;
      stale:102) printf '' ;;
      stale:103) printf '' ;;
      partial:201) exit 1 ;;
      reconcile-safe:301) printf 'Track-Task: 1.1\n' ;;
      reconcile-safe:302) printf 'Track-Task: 1.3\n' ;;
      reconcile-safe:303) printf 'Track-Task: 1.4\n' ;;
      reconcile-conflict:401) printf 'Track-Task: 1.5\n' ;;
      *)
        echo "unexpected gh invocation: $*" >&2
        exit 1
        ;;
    esac
  else
    case "$scenario:$pr_number" in
      stale:101) printf '' ;;
      stale:102) printf 'track:1.3' ;;
      stale:103) printf '' ;;
      partial:201) printf '' ;;
      reconcile-safe:301|reconcile-safe:302|reconcile-safe:303|reconcile-conflict:401) printf '' ;;
      *)
        echo "unexpected gh invocation: $*" >&2
        exit 1
        ;;
    esac
  fi
  exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
GH
  chmod +x "$dir/gh"
}

printf 'Running extended todo tests...\n\n'

repo="$(setup_repo)"
write_task "$repo/.track/tasks/1.4-cancelled-task.md" '1.4' 'Cancelled task' 'cancelled' 'low' '2026-01-02' 'depends_on: []' 'cancelled_reason: "No longer needed in fixture."'
mock_bin="$(mktemp -d)"
setup_gh_mock "$mock_bin"
PATH="$mock_bin:$PATH" MOCK_SCENARIO=stale bash "$repo/.track/scripts/track-todo.sh" --local --output "$repo/BOARD.md" >/dev/null

assert_contains 'board output written to explicit path' '# Board' "$repo/BOARD.md"
assert_contains 'todo sibling output written automatically' '# TODO' "$repo/TODO.md"
assert_contains 'projects sibling output written automatically' '# Projects Overview' "$repo/PROJECTS.md"
assert_contains 'projects completion counts cancelled tasks' '| [1](.track/projects/1-test-project.md) | Test Project | A test project for validation. | `[█████░░░░░] 50%` (2/4) | Active |' "$repo/PROJECTS.md"
assert_contains 'board shows canonical todo status with PR link' '| [1.1](.track/tasks/1.1-test-task.md) | [Test task](.track/tasks/1.1-test-task.md) | medium | — | todo · [PR](https://example.com/pr/101) |' "$repo/BOARD.md"
assert_contains 'board warns when canonical status is stale' "task '1.1' status may be stale: canonical 'todo', open draft PR suggests active; run \`bash .track/scripts/track-reconcile.sh\`." "$repo/BOARD.md"
assert_contains 'same task linked by two distinct PRs warns in board' "multiple open PRs map to task '1.3'" "$repo/BOARD.md"
assert_not_contains 'single-task PR does not warn for 1.1' "multiple open PRs map to task '1.1'" "$repo/BOARD.md"
assert_contains 'stale todo task moves to blocked queue' '- [ ] [1.1] [Test task](.track/tasks/1.1-test-task.md) *(open draft PR suggests active; run `bash .track/scripts/track-reconcile.sh`.)*' "$repo/TODO.md"
assert_contains 'todo keeps dependent task blocked' '- [ ] [1.3] [Dependent task](.track/tasks/1.3-dependent-task.md) *(Depends on 1.1; Multiple open PRs map to this task; resolve manually before continuing.)*' "$repo/TODO.md"
assert_not_contains 'stale task does not appear in ready queues' '- [ ] [1.1] [Test task](.track/tasks/1.1-test-task.md)' <(awk '/## Immediate Starts/{flag=1;next}/## Up Next/{flag=0}flag' "$repo/TODO.md")
rm -rf "$repo"

repo="$(setup_repo)"
PATH="$mock_bin:$PATH" MOCK_SCENARIO=partial bash "$repo/.track/scripts/track-todo.sh" --local --output "$repo/BOARD.md" >/dev/null
assert_contains 'board warns when GitHub lookup is partial' "GitHub PR lookup partial: open PR 'https://example.com/pr/201' body unavailable; falling back to labels/title/branch only" "$repo/BOARD.md"
assert_contains 'todo warns when GitHub lookup is partial' "GitHub PR lookup partial: open PR 'https://example.com/pr/201' body unavailable; falling back to labels/title/branch only" "$repo/TODO.md"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo/.track/tasks/1.4-review-drift.md" '1.4' 'Review drift' 'review' 'medium' '2026-01-01' 'depends_on: []'
out_file="$repo/reconcile.out"
err_file="$repo/reconcile.err"
reconcile_exit=0
PATH="$mock_bin:$PATH" MOCK_SCENARIO=reconcile-safe bash "$repo/.track/scripts/track-reconcile.sh" --no-refresh >"$out_file" 2>"$err_file" || reconcile_exit=$?
assert_exit_code 'safe reconciliation exits cleanly' 0 "$reconcile_exit"
assert_contains 'reconcile reports repaired summary' 'Reconciliation complete: 3 repaired, 0 unresolved.' "$out_file"
assert_contains 'todo task repaired to active' 'status: active' "$repo/.track/tasks/1.1-test-task.md"
assert_contains 'dependent task repaired to review' 'status: review' "$repo/.track/tasks/1.3-dependent-task.md"
assert_contains 'review drift repaired to active' 'status: active' "$repo/.track/tasks/1.4-review-drift.md"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo/.track/tasks/1.5-blocked-task.md" '1.5' 'Blocked task' 'blocked' 'high' '2026-01-01' 'depends_on: []' 'blocked_reason: "Waiting on manual approval."'
out_file="$repo/reconcile-conflict.out"
err_file="$repo/reconcile-conflict.err"
reconcile_exit=0
PATH="$mock_bin:$PATH" MOCK_SCENARIO=reconcile-conflict bash "$repo/.track/scripts/track-reconcile.sh" --no-refresh >"$out_file" 2>"$err_file" || reconcile_exit=$?
assert_exit_code 'unresolved reconciliation exits non-zero' 1 "$reconcile_exit"
assert_contains 'reconcile reports unresolved summary' 'Reconciliation complete: 0 repaired, 1 unresolved.' "$out_file"
assert_contains 'blocked conflict is reported' "task '1.5' is 'blocked' but an open draft PR exists at https://example.com/pr/401" "$out_file"
assert_contains 'blocked task stays blocked' 'status: blocked' "$repo/.track/tasks/1.5-blocked-task.md"
rm -rf "$repo" "$mock_bin"

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
