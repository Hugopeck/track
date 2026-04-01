#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"
TASK_STATUS_HELPER="$ROOT_DIR/.track/scripts/track-task-status.sh"
if [[ ! -f "$TASK_STATUS_HELPER" ]]; then
  TASK_STATUS_HELPER="$ROOT_DIR/skills/work/scripts/track-task-status.sh"
fi
# shellcheck source=./track-task-status.sh
source "$TASK_STATUS_HELPER"

COMPLETE_SCRIPT="$ROOT_DIR/.track/scripts/track-complete.sh"
if [[ ! -f "$COMPLETE_SCRIPT" ]]; then
  COMPLETE_SCRIPT="$ROOT_DIR/skills/work/scripts/track-complete.sh"
fi

SYNC_ACTION="${1:-}"
TASK_ID_OVERRIDE="${2:-${TRACK_TASK_ID:-}}"
TASK_BRANCH="${TASK_BRANCH:-${GITHUB_HEAD_REF:-}}"
PR_URL="${PR_URL:-}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"
PR_LABELS="${PR_LABELS:-}"
PR_DRAFT="${TRACK_PR_DRAFT:-false}"
PR_MERGED="${TRACK_PR_MERGED:-false}"
SYNCED_AT="${TRACK_STATUS_SYNCED_AT:-}"

print_info() {
  printf '%s\n' "$1"
}

print_error() {
  printf 'Error: %s\n' "$1" >&2
}

usage() {
  cat >&2 <<'EOF'
Usage: bash .track/scripts/track-sync-pr-status.sh <opened|ready_for_review|converted_to_draft|reopened|closed> [task_id]
EOF
}

is_truthy() {
  case "${1:-}" in
    true|TRUE|1|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

sync_date() {
  local date_part

  if [[ -n "$SYNCED_AT" ]]; then
    date_part="${SYNCED_AT%%T*}"
    date_part="${date_part%% *}"
    if [[ "$date_part" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      printf '%s\n' "$date_part"
      return 0
    fi
  fi

  date -u +'%Y-%m-%d'
}

find_task_file_by_id() {
  find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name "$1-*.md" | head -n 1
}

resolve_task_id() {
  local resolver_code

  if [[ -n "$TASK_ID_OVERRIDE" ]]; then
    TRACK_RESOLVED_TASK_ID="$TASK_ID_OVERRIDE"
    TRACK_RESOLVED_SOURCE='argument'
    return 0
  fi

  if track_resolve_task_id "$PR_BODY" "$PR_LABELS" "$PR_TITLE" "$TASK_BRANCH"; then
    return 0
  else
    resolver_code=$?
  fi


  case "$resolver_code" in
    1)
      print_info 'Not a Track PR; nothing to sync.'
      exit 0
      ;;
    2|3)
      print_error "$TRACK_RESOLVER_ERROR"
      exit 1
      ;;
    *)
      print_error 'Unexpected task resolver failure.'
      exit 1
      ;;
  esac
}

desired_status() {
  case "$SYNC_ACTION" in
    opened|reopened)
      if is_truthy "$PR_DRAFT"; then
        printf 'active\n'
      else
        printf 'review\n'
      fi
      ;;
    ready_for_review)
      printf 'review\n'
      ;;
    converted_to_draft)
      printf 'active\n'
      ;;
    closed)
      if is_truthy "$PR_MERGED"; then
        printf 'done\n'
      else
        printf 'todo\n'
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ -z "$SYNC_ACTION" ]]; then
  usage
  exit 1
fi

if ! TARGET_STATUS="$(desired_status)"; then
  print_error "unsupported PR lifecycle action '$SYNC_ACTION'"
  usage
  exit 1
fi

resolve_task_id

if [[ "$SYNC_ACTION" == 'closed' ]] && is_truthy "$PR_MERGED"; then
  bash "$COMPLETE_SCRIPT" "$TASK_BRANCH" "$PR_URL"
  exit 0
fi

TASK_FILE="$(find_task_file_by_id "$TRACK_RESOLVED_TASK_ID")"
if [[ -z "$TASK_FILE" ]]; then
  print_error "No task file found for $TRACK_RESOLVED_TASK_ID; sync cannot continue."
  exit 1
fi

if ! track_parse_task_file "$TASK_FILE"; then
  print_error "$TASK_FILE: $TRACK_parse_error"
  exit 1
fi

case "$SYNC_ACTION" in
  opened|ready_for_review|converted_to_draft|reopened)
    case "$TRACK_status" in
      blocked)
        print_error "Refusing to sync $SYNC_ACTION onto blocked task $TRACK_RESOLVED_TASK_ID."
        exit 1
        ;;
      done|cancelled)
        print_error "Refusing to sync $SYNC_ACTION onto terminal task $TRACK_RESOLVED_TASK_ID ($TRACK_status)."
        exit 1
        ;;
    esac
    ;;
  closed)
    case "$TRACK_status" in
      blocked|cancelled)
        print_info "Task $TRACK_RESOLVED_TASK_ID remains $TRACK_status after closed unmerged PR."
        exit 0
        ;;
      done)
        print_error "Refusing to reset terminal task $TRACK_RESOLVED_TASK_ID from done to todo."
        exit 1
        ;;
    esac
    ;;
esac

UPDATED_DATE="$(sync_date)"

if track_write_task_status "$TASK_FILE" "$TARGET_STATUS" "$UPDATED_DATE"; then
  print_info "Updated $TASK_FILE to $TARGET_STATUS (resolved from $TRACK_RESOLVED_SOURCE)."
  exit 0
else
  write_code=$?
fi


case "$write_code" in
  1)
    print_info "Task $TRACK_RESOLVED_TASK_ID already matches $TARGET_STATUS."
    exit 0
    ;;
  *)
    print_error "Failed to write $TARGET_STATUS to $TASK_FILE."
    exit 1
    ;;
esac
