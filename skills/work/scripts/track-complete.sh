#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

TASK_BRANCH="${1:-}"
PR_URL="${2:-}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"
PR_LABELS="${PR_LABELS:-}"
COMPLETED_AT="${TRACK_COMPLETED_AT:-}"
TODAY="$(date -u +'%Y-%m-%d')"

if [[ -n "$COMPLETED_AT" ]]; then
  COMPLETED_DATE="${COMPLETED_AT%%T*}"
  COMPLETED_DATE="${COMPLETED_DATE%% *}"
  if [[ "$COMPLETED_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    TODAY="$COMPLETED_DATE"
  fi
fi

find_task_file_by_id() {
  find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name "$1-*.md" | head -n 1
}

write_task_done() {
  local task_file="$1"
  local tmp_file

  tmp_file="$(mktemp)"
  TRACK_PR_URL="$PR_URL" TRACK_TODAY="$TODAY" awk '
  BEGIN { pr_url = ENVIRON["TRACK_PR_URL"]; today = ENVIRON["TRACK_TODAY"] }
  { gsub(/\r$/, "") }
  NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
  in_frontmatter && $0 == "---" {
    in_frontmatter = 0
    if (!saw_pr) print "pr: \"" pr_url "\""
    print
    next
  }
  in_frontmatter && /^status:[[:space:]]*/ { print "status: done"; next }
  in_frontmatter && /^updated:[[:space:]]*/ { print "updated: " today; next }
  in_frontmatter && /^pr:[[:space:]]*/ { print "pr: \"" pr_url "\""; saw_pr = 1; next }
  { print }
' "$task_file" > "$tmp_file"

  if cmp -s "$task_file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$task_file"
  return 0
}

write_task_unblocked() {
  local task_file="$1"
  local tmp_file

  tmp_file="$(mktemp)"
  TRACK_TODAY="$TODAY" awk '
  BEGIN { today = ENVIRON["TRACK_TODAY"] }
  { gsub(/\r$/, "") }
  NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
  in_frontmatter && $0 == "---" {
    in_frontmatter = 0
    print
    next
  }
  in_frontmatter && /^status:[[:space:]]*/ { print "status: todo"; next }
  in_frontmatter && /^updated:[[:space:]]*/ { print "updated: " today; next }
  in_frontmatter && /^blocked_reason:[[:space:]]*/ { next }
  { print }
' "$task_file" > "$tmp_file"

  if cmp -s "$task_file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$task_file"
  return 0
}

task_depends_on_completed_ids() {
  local serialized_depends="$1"
  local IFS="$TRACK_ITEM_SEP"
  local deps=()
  local dep completed_id

  read -r -a deps <<< "$serialized_depends"
  for dep in "${deps[@]-}"; do
    [[ -z "$dep" ]] && continue
    for completed_id in "${TASK_IDS_TO_COMPLETE[@]}"; do
      if [[ "$dep" == "$completed_id" ]]; then
        return 0
      fi
    done
  done

  return 1
}

task_dependencies_all_done() {
  local serialized_depends="$1"
  local IFS="$TRACK_ITEM_SEP"
  local deps=()
  local dep dep_file

  read -r -a deps <<< "$serialized_depends"
  for dep in "${deps[@]-}"; do
    [[ -z "$dep" ]] && continue
    dep_file="$(find_task_file_by_id "$dep")"
    if [[ -z "$dep_file" ]]; then
      return 1
    fi
    if ! track_parse_task_file "$dep_file"; then
      echo "$dep_file: $TRACK_parse_error" >&2
      exit 1
    fi
    if [[ "$TRACK_status" != 'done' ]]; then
      return 1
    fi
  done

  return 0
}

cascade_unblocked_tasks() {
  local task_file depends_serialized task_id task_status
  local unblocked_count=0

  while IFS= read -r task_file; do
    if ! track_parse_task_file "$task_file"; then
      echo "$task_file: $TRACK_parse_error" >&2
      exit 1
    fi

    task_id="$TRACK_id"
    task_status="$TRACK_status"
    case "$task_status" in
      blocked|todo) ;;
      *) continue ;;
    esac

    depends_serialized="$(track_serialize_items "${TRACK_depends_on[@]-}")"
    [[ -n "$depends_serialized" ]] || continue

    if ! task_depends_on_completed_ids "$depends_serialized"; then
      continue
    fi

    if ! task_dependencies_all_done "$depends_serialized"; then
      continue
    fi

    if [[ "$task_status" == 'blocked' ]]; then
      if write_task_unblocked "$task_file"; then
        echo "Unblocked $task_file"
        unblocked_count=$((unblocked_count + 1))
      fi
    fi
  done < <(find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name '*.md' | sort)

  UNBLOCKED_TASK_COUNT="$unblocked_count"
}

if track_resolve_task_id "$PR_BODY" "$PR_LABELS" "$PR_TITLE" "$TASK_BRANCH"; then
  RESOLVE_EXIT=0
else
  RESOLVE_EXIT=$?
fi
if [[ $RESOLVE_EXIT -ne 0 ]]; then
  case "$RESOLVE_EXIT" in
    1) echo "Not a Track PR; nothing to complete." ; exit 0 ;;
    2|3) echo "$TRACK_RESOLVER_ERROR" >&2 ; exit 1 ;;
    *) echo 'Unexpected task resolver failure.' >&2 ; exit 1 ;;
  esac
fi

TASK_IDS_TO_COMPLETE=("$TRACK_RESOLVED_TASK_ID")

if track_also_completed_ids_from_body "$PR_BODY"; then
  for also_id in "${TRACK_ALSO_COMPLETED_IDS[@]}"; do
    if [[ "$also_id" != "$TRACK_RESOLVED_TASK_ID" ]]; then
      TASK_IDS_TO_COMPLETE+=("$also_id")
    fi
  done
fi

TASK_FILES_TO_COMPLETE=()
for task_id in "${TASK_IDS_TO_COMPLETE[@]}"; do
  task_file="$(find_task_file_by_id "$task_id")"
  if [[ -z "$task_file" ]]; then
    echo "No task file found for $task_id; completion cannot continue." >&2
    exit 1
  fi
  TASK_FILES_TO_COMPLETE+=("$task_file")
done

updated_count=0
skipped_count=0
UNBLOCKED_TASK_COUNT=0

for i in "${!TASK_IDS_TO_COMPLETE[@]}"; do
  task_id="${TASK_IDS_TO_COMPLETE[$i]}"
  task_file="${TASK_FILES_TO_COMPLETE[$i]}"

  if ! track_parse_task_file "$task_file"; then
    echo "$task_file: $TRACK_parse_error" >&2
    exit 1
  fi

  if [[ "$TRACK_status" == 'done' || "$TRACK_status" == 'cancelled' ]]; then
    echo "Skipping terminal task $task_id ($TRACK_status)."
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if write_task_done "$task_file"; then
    echo "Updated $task_file (resolved from $TRACK_RESOLVED_SOURCE)"
    updated_count=$((updated_count + 1))
  else
    echo "Task $task_id is already up to date."
    skipped_count=$((skipped_count + 1))
  fi
done

cascade_unblocked_tasks

echo "Completion processed ${#TASK_IDS_TO_COMPLETE[@]} task(s): $updated_count updated, $skipped_count skipped, $UNBLOCKED_TASK_COUNT unblocked."
