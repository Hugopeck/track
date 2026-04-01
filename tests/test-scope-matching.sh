#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/../scripts/lib/track-common.sh"
TRACK_ITEM_SEP=$'\034'
PASS=0
FAIL=0

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (expected "%s", got "%s")\n' "$name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.track/tasks" "$tmp/.track/scripts"
  cp "$COMMON_SCRIPT" "$tmp/.track/scripts/track-common.sh"
  printf '%s' "$tmp"
}

write_task() {
  local repo="$1"
  local filename="$2"
  local task_id="$3"
  local status="$4"
  local files_block="$5"

  cat > "$repo/.track/tasks/$filename" <<EOF_TASK
---
id: "$task_id"
title: "Task $task_id"
status: $status
mode: implement
priority: medium
project_id: "1"
created: 2026-03-30
updated: 2026-03-30
depends_on: []
files:
$files_block
pr: ""
---

## Context
Test fixture.

## Acceptance Criteria
- [ ] Test fixture

## Notes
EOF_TASK
}

run_match() {
  local repo="$1"
  shift
  local output

  output="$({
    source "$repo/.track/scripts/track-common.sh"
    local exit_code=0
    track_match_files_to_task "$@" || exit_code=$?
    printf '%s|%s|%s|%s\n' \
      "$exit_code" \
      "$TRACK_MATCH_CONFIDENCE" \
      "$TRACK_MATCHED_TASK_IDS_SERIALIZED" \
      "$TRACK_MATCH_ERROR"
  })"

  printf '%s' "$output"
}

printf 'Running scope matching tests...\n\n'

repo="$(setup_repo)"
write_task "$repo" "1.1-api-task.md" "1.1" "todo" '  - "src/api/**"'
write_task "$repo" "1.2-docs-task.md" "1.2" "todo" '  - "docs/**"'
result="$(run_match "$repo" "src/api/server.sh")"
assert_eq "single match result" "0|deterministic|1.1|" "$result"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo" "1.1-src-task.md" "1.1" "todo" '  - "src/**"'
write_task "$repo" "1.2-api-task.md" "1.2" "review" '  - "src/api/**"'
result="$(run_match "$repo" "src/api/server.sh")"
assert_eq "multiple match result" "0|ambiguous|1.1${TRACK_ITEM_SEP}1.2|" "$result"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo" "1.1-src-task.md" "1.1" "todo" '  - "src/**"'
write_task "$repo" "1.2-docs-task.md" "1.2" "active" '  - "docs/**"'
result="$(run_match "$repo" "scripts/deploy.sh")"
assert_eq "no match result" "1|unmatched||" "$result"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo" "1.1-done-task.md" "1.1" "done" '  - "src/**"'
write_task "$repo" "1.2-cancelled-task.md" "1.2" "cancelled" '  - "src/api/**"'
result="$(run_match "$repo" "src/api/server.sh")"
assert_eq "terminal tasks ignored" "1|unmatched||" "$result"
rm -rf "$repo"

repo="$(setup_repo)"
write_task "$repo" "1.1-valid-task.md" "1.1" "todo" '  - "src/**"'
cat > "$repo/.track/tasks/1.2-bad-task.md" <<'EOF_BAD'
---
id: "1.2"
title: "Bad task"
status: todo
EOF_BAD
result="$(run_match "$repo" "src/api/server.sh")"
case "$result" in
  2\|\|\|*frontmatter\ never\ closed*)
    printf '  PASS: malformed task file returns error\n'
    PASS=$((PASS + 1))
    ;;
  *)
    printf '  FAIL: malformed task file returns error (got "%s")\n' "$result"
    FAIL=$((FAIL + 1))
    ;;
esac
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
