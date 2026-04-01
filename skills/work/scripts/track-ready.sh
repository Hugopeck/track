#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

SYNC_SCRIPT="$ROOT_DIR/.track/scripts/track-sync-pr-status.sh"
if [[ ! -f "$SYNC_SCRIPT" ]]; then
  SYNC_SCRIPT="$ROOT_DIR/skills/work/scripts/track-sync-pr-status.sh"
fi

VALIDATE_SCRIPT="$ROOT_DIR/.track/scripts/track-validate.sh"
if [[ ! -f "$VALIDATE_SCRIPT" ]]; then
  VALIDATE_SCRIPT="$ROOT_DIR/skills/validate/scripts/track-validate.sh"
fi

TASK_ID="${1:-}"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"

print_error() {
  printf 'Error: %s\n' "$1" >&2
}

usage() {
  printf 'Usage: bash .track/scripts/track-ready.sh <task_id>\n' >&2
}

resolve_task_id() {
  if [[ -n "$TASK_ID" ]]; then
    printf '%s\n' "$TASK_ID"
    return 0
  fi

  track_task_id_from_branch "$CURRENT_BRANCH" >/dev/null 2>&1 || true
  if [[ -n "$TRACK_PARSED_TASK_ID" ]]; then
    printf '%s\n' "$TRACK_PARSED_TASK_ID"
    return 0
  fi

  return 1
}

TASK_ID="$(resolve_task_id || true)"
if [[ -z "$TASK_ID" ]]; then
  usage
  exit 1
fi

TASK_FILE="$(find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name "$TASK_ID-*.md" | head -n 1)"
if [[ -z "$TASK_FILE" ]]; then
  print_error "Task $TASK_ID not found."
  exit 1
fi

if ! track_parse_task_file "$TASK_FILE"; then
  print_error "$TASK_FILE: $TRACK_parse_error"
  exit 1
fi

DEFAULT_TITLE="feat(track): [$TASK_ID] $TRACK_title"
DEFAULT_BODY="Track-Task: $TASK_ID"
TASK_BRANCH="${CURRENT_BRANCH:-task/$TASK_ID-local}"

env \
  TASK_BRANCH="$TASK_BRANCH" \
  PR_TITLE="${PR_TITLE:-$DEFAULT_TITLE}" \
  PR_BODY="${PR_BODY:-$DEFAULT_BODY}" \
  PR_LABELS="${PR_LABELS:-}" \
  TRACK_PR_DRAFT='false' \
  bash "$SYNC_SCRIPT" ready_for_review "$TASK_ID"

bash "$VALIDATE_SCRIPT"
printf 'Task %s synced to review.\n' "$TASK_ID"
