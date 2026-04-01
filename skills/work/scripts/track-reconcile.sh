#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

TASK_STATUS_HELPER="$ROOT_DIR/.track/scripts/track-task-status.sh"
if [[ -f "$TASK_STATUS_HELPER" ]]; then
  # shellcheck source=./track-task-status.sh
  source "$TASK_STATUS_HELPER"
else
  TASK_STATUS_HELPER="$ROOT_DIR/skills/work/scripts/track-task-status.sh"
  if [[ -f "$TASK_STATUS_HELPER" ]]; then
    # shellcheck source=./track-task-status.sh
    source "$TASK_STATUS_HELPER"
  fi
fi

if ! command -v track_write_task_status >/dev/null 2>&1; then
  track_write_task_status() {
    local task_file="$1"
    local status="$2"
    local updated_date="$3"
    local pr_url="${4-}"
    local remove_blocked_reason="${5:-0}"
    local tmp_file

    [[ -f "$task_file" ]] || return 2

    tmp_file="$(mktemp)"
    if ! TRACK_STATUS="$status" \
      TRACK_TODAY="$updated_date" \
      TRACK_PR_URL="$pr_url" \
      TRACK_REMOVE_BLOCKED_REASON="$remove_blocked_reason" \
      awk '
        BEGIN {
          status = ENVIRON["TRACK_STATUS"]
          today = ENVIRON["TRACK_TODAY"]
          pr_url = ENVIRON["TRACK_PR_URL"]
          remove_blocked_reason = (ENVIRON["TRACK_REMOVE_BLOCKED_REASON"] == "1")
        }
        { gsub(/\r$/, "") }
        NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
        in_frontmatter && $0 == "---" {
          if (!saw_status) print "status: " status
          if (!saw_updated) print "updated: " today
          if (pr_url != "" && !saw_pr) print "pr: \"" pr_url "\""
          in_frontmatter = 0
          print
          next
        }
        in_frontmatter && /^status:[[:space:]]*/ {
          print "status: " status
          saw_status = 1
          next
        }
        in_frontmatter && /^updated:[[:space:]]*/ {
          print "updated: " today
          saw_updated = 1
          next
        }
        in_frontmatter && /^pr:[[:space:]]*/ {
          if (pr_url != "") print "pr: \"" pr_url "\""
          else print
          saw_pr = 1
          next
        }
        in_frontmatter && remove_blocked_reason && /^blocked_reason:[[:space:]]*/ { next }
        { print }
      ' "$task_file" > "$tmp_file"; then
      rm -f "$tmp_file"
      return 2
    fi

    if cmp -s "$task_file" "$tmp_file"; then
      rm -f "$tmp_file"
      return 1
    fi

    mv "$tmp_file" "$task_file"
    return 0
  }
fi

DEFAULT_BRANCH="${TRACK_DEFAULT_BRANCH:-main}"
TODAY="$(date -u +'%Y-%m-%d')"
DRY_RUN=0
REFRESH_VIEWS=1

TASK_IDS=()
TASK_FILES=()
TASK_STATUSES=()
OPEN_PR_TASK_IDS=()
OPEN_PR_URLS=()
OPEN_PR_STATUSES=()
REPAIRS=()
UNRESOLVED=()

usage() {
  cat <<'USAGE'
Usage: bash .track/scripts/track-reconcile.sh [--dry-run] [--no-refresh]

Scans local task files against live open PR state, repairs safe canonical-status
mismatches, reports unresolved conflicts, and regenerates Track views by default.
USAGE
}

find_task_file_by_id() {
  find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name "$1-*.md" | head -n 1
}

find_open_pr_index_by_task_id() {
  local id="$1"
  local i match_count=0
  OPEN_PR_MATCH_INDEX=''
  OPEN_PR_MATCH_COUNT=0

  for ((i = 0; i < ${#OPEN_PR_TASK_IDS[@]}; i++)); do
    if [[ "${OPEN_PR_TASK_IDS[$i]}" == "$id" ]]; then
      match_count=$((match_count + 1))
      OPEN_PR_MATCH_INDEX="$i"
    fi
  done

  OPEN_PR_MATCH_COUNT="$match_count"
  [[ $match_count -eq 1 ]]
}

fetch_pr_body() {
  gh pr view "$1" --json body --template '{{.body}}' 2>/dev/null
}

fetch_pr_labels() {
  gh pr view "$1" --json labels --template '{{range $index, $label := .labels}}{{if $index}},{{end}}{{.name}}{{end}}' 2>/dev/null
}

load_tasks() {
  local task_file
  while IFS= read -r task_file; do
    if ! track_parse_task_file "$task_file"; then
      printf '%s: %s\n' "$task_file" "$TRACK_parse_error" >&2
      exit 1
    fi

    TASK_IDS+=("$TRACK_id")
    TASK_FILES+=("$task_file")
    TASK_STATUSES+=("$TRACK_status")
  done < <(find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name '*.md' | sort)
}

load_open_prs() {
  local lines number url is_draft head_ref title pr_body pr_labels resolver_code task_file

  if ! command -v gh >/dev/null 2>&1; then
    printf 'track-reconcile: gh not found; live GitHub PR state is required\n' >&2
    exit 1
  fi

  if ! lines="$(gh pr list --state open --base "$DEFAULT_BRANCH" --json number,url,isDraft,headRefName,title --template '{{range .}}{{printf "%v\t%s\t%t\t%s\t%s\n" .number .url .isDraft .headRefName .title}}{{end}}' 2>/dev/null)"; then
    printf 'track-reconcile: gh PR lookup failed\n' >&2
    exit 1
  fi

  while IFS=$'\t' read -r number url is_draft head_ref title; do
    [[ -z "$url" ]] && continue

    pr_body=''
    pr_labels=''
    if ! pr_body="$(fetch_pr_body "$number")"; then
      printf 'Warning: open PR %s body unavailable; falling back to labels/title/branch only\n' "$url" >&2
      pr_body=''
    fi
    if ! pr_labels="$(fetch_pr_labels "$number")"; then
      printf 'Warning: open PR %s labels unavailable; falling back to body/title/branch only\n' "$url" >&2
      pr_labels=''
    fi

    if track_resolve_task_id "$pr_body" "$pr_labels" "$title" "$head_ref"; then
      resolver_code=0
    else
      resolver_code=$?
    fi

    case "$resolver_code" in
      0)
        task_file="$(find_task_file_by_id "$TRACK_RESOLVED_TASK_ID")"
        if [[ -z "$task_file" ]]; then
          UNRESOLVED+=("open PR '$url' resolved to task '$TRACK_RESOLVED_TASK_ID', but no matching task file exists")
          continue
        fi
        OPEN_PR_TASK_IDS+=("$TRACK_RESOLVED_TASK_ID")
        OPEN_PR_URLS+=("$url")
        if [[ "$is_draft" == 'true' ]]; then
          OPEN_PR_STATUSES+=('active')
        else
          OPEN_PR_STATUSES+=('review')
        fi
        ;;
      1)
        UNRESOLVED+=("open PR '$url' could not be linked to a task: $TRACK_RESOLVER_ERROR")
        ;;
      2|3)
        UNRESOLVED+=("open PR '$url' could not be linked to a task: $TRACK_RESOLVER_ERROR")
        ;;
      *)
        UNRESOLVED+=("open PR '$url' could not be linked to a task: unexpected resolver failure")
        ;;
    esac
  done <<< "$lines"
}

observed_status_hint() {
  case "$1" in
    active) printf 'an open draft PR' ;;
    review) printf 'an open ready-for-review PR' ;;
    *) printf 'an open PR with status %s' "$1" ;;
  esac
}

repair_task_status() {
  local task_index="$1"
  local target_status="$2"
  local pr_url="$3"
  local remove_blocked_reason=0
  local from_status="${TASK_STATUSES[$task_index]}"

  if [[ "$target_status" == 'todo' ]]; then
    remove_blocked_reason=1
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    REPAIRS+=("${TASK_IDS[$task_index]}: would update $from_status -> $target_status from $pr_url")
    return 0
  fi

  if ! track_write_task_status "${TASK_FILES[$task_index]}" "$target_status" "$TODAY" '' "$remove_blocked_reason"; then
    printf 'track-reconcile: failed to update %s\n' "${TASK_FILES[$task_index]}" >&2
    exit 1
  fi

  TASK_STATUSES[$task_index]="$target_status"
  REPAIRS+=("${TASK_IDS[$task_index]}: updated $from_status -> $target_status from $pr_url")
}

reconcile_tasks() {
  local task_index canonical_status observed_status pr_url

  for ((task_index = 0; task_index < ${#TASK_IDS[@]}; task_index++)); do
    canonical_status="${TASK_STATUSES[$task_index]}"

    find_open_pr_index_by_task_id "${TASK_IDS[$task_index]}" || true
    if [[ ${OPEN_PR_MATCH_COUNT:-0} -gt 1 ]]; then
      UNRESOLVED+=("task '${TASK_IDS[$task_index]}' has multiple open PRs; resolve manually")
      continue
    fi

    if [[ ${OPEN_PR_MATCH_COUNT:-0} -eq 0 ]]; then
      if [[ "$canonical_status" == 'active' || "$canonical_status" == 'review' ]]; then
        UNRESOLVED+=("task '${TASK_IDS[$task_index]}' is '$canonical_status' but no linked open PR was found")
      fi
      continue
    fi

    observed_status="${OPEN_PR_STATUSES[$OPEN_PR_MATCH_INDEX]}"
    pr_url="${OPEN_PR_URLS[$OPEN_PR_MATCH_INDEX]}"

    case "$canonical_status:$observed_status" in
      todo:active|todo:review|active:review|review:active)
        repair_task_status "$task_index" "$observed_status" "$pr_url"
        ;;
      blocked:active|blocked:review|done:active|done:review|cancelled:active|cancelled:review)
        UNRESOLVED+=("task '${TASK_IDS[$task_index]}' is '$canonical_status' but $(observed_status_hint "$observed_status") exists at $pr_url")
        ;;
    esac
  done
}

refresh_views() {
  if [[ $REFRESH_VIEWS -eq 0 || $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  bash "$ROOT_DIR/.track/scripts/track-todo.sh" --local >/dev/null
}

print_report() {
  printf 'Reconciliation complete: %d repaired, %d unresolved.\n' "${#REPAIRS[@]}" "${#UNRESOLVED[@]}"

  if [[ ${#REPAIRS[@]} -gt 0 ]]; then
    printf 'Repaired:\n'
    printf -- '- %s\n' "${REPAIRS[@]}"
  fi

  if [[ ${#UNRESOLVED[@]} -gt 0 ]]; then
    printf 'Unresolved:\n'
    printf -- '- %s\n' "${UNRESOLVED[@]}"
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --no-refresh)
        REFRESH_VIEWS=0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  cd "$ROOT_DIR"
  load_tasks
  load_open_prs
  reconcile_tasks
  refresh_views
  print_report

  if [[ ${#UNRESOLVED[@]} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
