#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASK_DIR="$ROOT_DIR/.track/tasks"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

EXIT_CODE=0
HEAD_REF="${GITHUB_HEAD_REF:-}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"
PR_LABELS="${PR_LABELS:-}"

print_error() {
  printf 'Error: %s\n' "$1" >&2
  EXIT_CODE=1
}

print_warning() {
  printf 'Warning: %s\n' "$1" >&2
}

print_info() {
  printf '%s\n' "$1"
}

if [[ -z "$HEAD_REF" ]]; then
  print_info 'No HEAD_REF set; skipping PR lint (not a pull request context).'
  exit 0
fi

if track_resolve_task_id "$PR_BODY" "$PR_LABELS" "$PR_TITLE" "$HEAD_REF"; then
  RESOLVE_EXIT=0
else
  RESOLVE_EXIT=$?
fi
if [[ $RESOLVE_EXIT -ne 0 ]]; then
  case "$RESOLVE_EXIT" in
    1) print_info "Not a Track PR; skipping lint." ; exit 0 ;;
    2|3) print_error "$TRACK_RESOLVER_ERROR" ;;
    *) print_error 'unexpected task resolver failure' ;;
  esac
  exit "$EXIT_CODE"
fi

print_info "Resolved task: $TRACK_RESOLVED_TASK_ID (source: $TRACK_RESOLVED_SOURCE)"

task_file="$(find "$TASK_DIR" -maxdepth 1 -type f -name "${TRACK_RESOLVED_TASK_ID}-*.md" | head -n 1)"
if [[ -z "$task_file" ]]; then
  print_error "No task file found for ID '$TRACK_RESOLVED_TASK_ID' in .track/tasks/"
  exit "$EXIT_CODE"
fi

if ! track_parse_task_file "$task_file"; then
  print_error "$task_file: $TRACK_parse_error"
  exit "$EXIT_CODE"
fi

if track_task_id_from_branch "$HEAD_REF"; then
  if [[ "$HEAD_REF" =~ ^task/([0-9]+\.[0-9]+)-([a-z0-9-]+)$ ]]; then
    branch_task_id="${BASH_REMATCH[1]}"
    BRANCH_SLUG="${BASH_REMATCH[2]}"
    TASK_BASENAME="$(basename "$task_file" .md)"
    EXPECTED_SLUG="${TASK_BASENAME#"${branch_task_id}-"}"
    print_info "Branch task ID: $branch_task_id"
    print_info "Branch slug: $BRANCH_SLUG"

    if [[ "$BRANCH_SLUG" != "$EXPECTED_SLUG" ]]; then
      print_warning "Branch slug '$BRANCH_SLUG' doesn't match task file slug '$EXPECTED_SLUG' (task file: $TASK_BASENAME.md)"
    fi
  fi
else
  print_warning "Branch '$HEAD_REF' is not a Track branch; using fallback task linkage from $TRACK_RESOLVED_SOURCE"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  print_info 'Track PR lint passed.'
fi

exit "$EXIT_CODE"
