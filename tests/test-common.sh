#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0

# Source the common library
source "$SCAFFOLD_SCRIPTS/track-common.sh"

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

assert_exit() {
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

printf 'Running track-common tests...\n\n'

# ─── Glob overlap detection ─────────────────────────────────────────

printf '── Glob overlap detection ──\n'

# Identical paths overlap
assert_exit "identical globs overlap" 0 \
  track_globs_overlap_serialized "src/**" "src/**"

# Parent/child paths overlap
assert_exit "parent contains child" 0 \
  track_globs_overlap_serialized "src/**" "src/api/**"

# Child/parent paths overlap (reversed)
assert_exit "child contained by parent" 0 \
  track_globs_overlap_serialized "src/api/**" "src/**"

# Disjoint paths don't overlap
assert_exit "disjoint paths don't overlap" 1 \
  track_globs_overlap_serialized "src/**" "tests/**"

# Multiple globs: one overlapping pair is enough
a_globs="$(track_serialize_items "docs/**" "src/api/**")"
b_globs="$(track_serialize_items "tests/**" "src/**")"
assert_exit "multi-glob with one overlap detected" 0 \
  track_globs_overlap_serialized "$a_globs" "$b_globs"

# Multiple globs: all disjoint
a_globs="$(track_serialize_items "docs/**" "config/**")"
b_globs="$(track_serialize_items "tests/**" "src/**")"
assert_exit "multi-glob all disjoint" 1 \
  track_globs_overlap_serialized "$a_globs" "$b_globs"

# Empty glob list never overlaps
assert_exit "empty glob A doesn't overlap" 1 \
  track_globs_overlap_serialized "" "src/**"

assert_exit "empty glob B doesn't overlap" 1 \
  track_globs_overlap_serialized "src/**" ""

# Root glob (no base path) overlaps everything
assert_exit "root glob overlaps anything" 0 \
  track_globs_overlap_serialized "**" "src/**"

# Sibling directories don't overlap
assert_exit "sibling dirs don't overlap" 1 \
  track_globs_overlap_serialized "src/api/**" "src/ui/**"

# Deeply nested overlap
assert_exit "deep nesting overlaps" 0 \
  track_globs_overlap_serialized "src/api/v2/**" "src/api/**"

# ─── Priority ranking ───────────────────────────────────────────────

printf '\n── Priority ranking ──\n'

assert_eq "urgent is 0" "0" "$(track_priority_rank urgent)"
assert_eq "high is 1" "1" "$(track_priority_rank high)"
assert_eq "medium is 2" "2" "$(track_priority_rank medium)"
assert_eq "low is 3" "3" "$(track_priority_rank low)"
assert_eq "unknown is 99" "99" "$(track_priority_rank bogus)"

# ─── Status ranking ─────────────────────────────────────────────────

printf '\n── Status ranking ──\n'

assert_eq "active is 0" "0" "$(track_status_rank active)"
assert_eq "review is 1" "1" "$(track_status_rank review)"
assert_eq "todo is 2" "2" "$(track_status_rank todo)"
assert_eq "done is 3" "3" "$(track_status_rank done)"
assert_eq "cancelled is 4" "4" "$(track_status_rank cancelled)"
assert_eq "unknown status is 99" "99" "$(track_status_rank bogus)"

# ─── Terminal status ─────────────────────────────────────────────────

printf '\n── Terminal status ──\n'

assert_exit "done is terminal" 0 track_is_terminal_status done
assert_exit "cancelled is terminal" 0 track_is_terminal_status cancelled
assert_exit "todo is not terminal" 1 track_is_terminal_status todo
assert_exit "active is not terminal" 1 track_is_terminal_status active
assert_exit "review is not terminal" 1 track_is_terminal_status review

# ─── ID format detection ────────────────────────────────────────────

printf '\n── ID format detection ──\n'

assert_exit "1.1 is dotted" 0 track_is_dotted_id "1.1"
assert_exit "42.7 is dotted" 0 track_is_dotted_id "42.7"
assert_exit "100 is not dotted" 1 track_is_dotted_id "100"
assert_exit "abc is not dotted" 1 track_is_dotted_id "abc"

assert_exit "100 is legacy" 0 track_is_legacy_id "100"
assert_exit "999 is legacy" 0 track_is_legacy_id "999"
assert_exit "99 is not legacy (too short)" 1 track_is_legacy_id "99"
assert_exit "1.1 is not legacy" 1 track_is_legacy_id "1.1"

# ─── String utilities ───────────────────────────────────────────────

printf '\n── String utilities ──\n'

assert_eq "trim leading/trailing spaces" "hello" "$(track_trim "  hello  ")"
assert_eq "trim tabs" "hello" "$(track_trim "	hello	")"
assert_eq "trim empty" "" "$(track_trim "   ")"

assert_eq "strip double quotes" "hello" "$(track_strip_quotes '"hello"')"
assert_eq "strip single quotes" "hello" "$(track_strip_quotes "'hello'")"
assert_eq "no quotes unchanged" "hello" "$(track_strip_quotes 'hello')"
assert_eq "strip quotes with spaces" "hello" "$(track_strip_quotes '  "hello"  ')"

# ─── Serialization ──────────────────────────────────────────────────

printf '\n── Item serialization ──\n'

serialized="$(track_serialize_items "a" "b" "c")"
assert_eq "serialize 3 items" "a${TRACK_ITEM_SEP}b${TRACK_ITEM_SEP}c" "$serialized"

serialized="$(track_serialize_items "single")"
assert_eq "serialize 1 item" "single" "$serialized"

serialized="$(track_serialize_items)"
assert_eq "serialize 0 items" "" "$serialized"

# ─── YAML frontmatter parsing ───────────────────────────────────────

printf '\n── YAML frontmatter parsing ──\n'

# Create temp task file with all fields
tmp_task="$(mktemp)"
cat > "$tmp_task" << 'EOF'
---
id: "3.1"
title: "Parse test"
status: todo
mode: investigate
priority: urgent
project_id: "3"
created: 2026-01-15
updated: 2026-01-20
depends_on:
  - "3.0"
files:
  - "src/api/**"
  - "tests/api/**"
pr: "https://github.com/test/pull/5"
cancelled_reason: ""
---

## Context
Body.
EOF

track_parse_task_file "$tmp_task"
assert_eq "parse id" "3.1" "$TRACK_id"
assert_eq "parse title" "Parse test" "$TRACK_title"
assert_eq "parse status" "todo" "$TRACK_status"
assert_eq "parse mode" "investigate" "$TRACK_mode"
assert_eq "parse priority" "urgent" "$TRACK_priority"
assert_eq "parse project_id" "3" "$TRACK_project_id"
assert_eq "parse pr" "https://github.com/test/pull/5" "$TRACK_pr"
assert_eq "parse depends_on count" "1" "${#TRACK_depends_on[@]}"
assert_eq "parse depends_on[0]" "3.0" "${TRACK_depends_on[0]}"
assert_eq "parse files count" "2" "${#TRACK_files[@]}"
assert_eq "parse files[0]" "src/api/**" "${TRACK_files[0]}"
assert_eq "parse files[1]" "tests/api/**" "${TRACK_files[1]}"
rm -f "$tmp_task"

# Inline array syntax
tmp_task="$(mktemp)"
cat > "$tmp_task" << 'EOF'
---
id: "4.1"
title: "Inline arrays"
status: done
mode: implement
priority: low
project_id: "4"
created: 2026-01-01
updated: 2026-01-01
depends_on: ["4.0", "4.2"]
files: ["lib/**"]
pr: ""
---

## Context
Body.
EOF

track_parse_task_file "$tmp_task"
assert_eq "inline depends_on count" "2" "${#TRACK_depends_on[@]}"
assert_eq "inline depends_on[0]" "4.0" "${TRACK_depends_on[0]}"
assert_eq "inline depends_on[1]" "4.2" "${TRACK_depends_on[1]}"
assert_eq "inline files count" "1" "${#TRACK_files[@]}"
assert_eq "inline files[0]" "lib/**" "${TRACK_files[0]}"
rm -f "$tmp_task"

# Empty arrays
tmp_task="$(mktemp)"
cat > "$tmp_task" << 'EOF'
---
id: "5.1"
title: "Empty arrays"
status: todo
mode: plan
priority: medium
project_id: "5"
created: 2026-01-01
updated: 2026-01-01
depends_on: []
files: []
pr: ""
---

## Context
Body.
EOF

track_parse_task_file "$tmp_task"
assert_eq "empty depends_on count" "0" "${#TRACK_depends_on[@]}"
assert_eq "empty files count" "0" "${#TRACK_files[@]}"
rm -f "$tmp_task"

# Missing frontmatter delimiter → error
tmp_task="$(mktemp)"
printf 'no frontmatter here\n' > "$tmp_task"
assert_exit "missing opening delimiter fails" 1 track_parse_task_file "$tmp_task"
rm -f "$tmp_task"

# Unclosed frontmatter → error
tmp_task="$(mktemp)"
cat > "$tmp_task" << 'EOF'
---
id: "6.1"
title: "Unclosed"
EOF

assert_exit "unclosed frontmatter fails" 1 track_parse_task_file "$tmp_task"
rm -f "$tmp_task"

printf '\n── Results ──\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
