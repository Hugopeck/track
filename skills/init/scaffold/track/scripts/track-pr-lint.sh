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
PR_NUMBER="${PR_NUMBER:-}"

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

if track_resolve_task_ids "$PR_BODY" "$PR_LABELS" "$PR_TITLE" "$HEAD_REF"; then
  RESOLVE_EXIT=0
else
  RESOLVE_EXIT=$?
fi
if [[ $RESOLVE_EXIT -ne 0 ]]; then
  case "$RESOLVE_EXIT" in
    1) print_error "Could not resolve a Track task for this PR. Add one of: PR body 'Track-Task: {id}', label 'track:{id}', title '[{id}]'/'({id})', or branch 'task/{id}-{slug}'." ;;
    2|3) print_error "$TRACK_RESOLVER_ERROR" ;;
    *) print_error 'unexpected task resolver failure' ;;
  esac
  exit "$EXIT_CODE"
fi

if [[ "$TRACK_RESOLUTION_MODE" == 'batch' ]]; then
  print_info "Resolved tasks: $(track_join_ids_csv "$TRACK_RESOLVED_TASK_IDS") (source: $TRACK_RESOLVED_SOURCE)"
else
  print_info "Resolved task: $TRACK_RESOLVED_TASK_ID (source: $TRACK_RESOLVED_SOURCE)"
fi

TASK_FILES_FOUND=()
while IFS= read -r resolved_task_id || [[ -n "$resolved_task_id" ]]; do
  [[ -z "$resolved_task_id" ]] && continue
  task_file="$(find "$TASK_DIR" -maxdepth 1 -type f -name "${resolved_task_id}-*.md" | head -n 1)"
  if [[ -z "$task_file" ]]; then
    print_error "No task file found for ID '$resolved_task_id' in .track/tasks/"
    continue
  fi
  if ! track_parse_task_file "$task_file"; then
    print_error "$task_file: $TRACK_parse_error"
    continue
  fi
  TASK_FILES_FOUND+=("$task_file")
done <<< "$TRACK_RESOLVED_TASK_IDS"

if [[ $EXIT_CODE -ne 0 ]]; then
  exit "$EXIT_CODE"
fi

if track_task_ids_from_branch "$HEAD_REF"; then
  if [[ "$HEAD_REF" =~ ^task/([0-9]+\.[0-9]+)-([a-z0-9-]+)$ ]]; then
    branch_task_id="${BASH_REMATCH[1]}"
    BRANCH_SLUG="${BASH_REMATCH[2]}"
    TASK_FILE="$(find "$TASK_DIR" -maxdepth 1 -type f -name "${branch_task_id}-*.md" | head -n 1)"
    TASK_BASENAME="$(basename "$TASK_FILE" .md)"
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
