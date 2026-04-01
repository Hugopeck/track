#!/usr/bin/env bash

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

track_mark_task_done() {
  track_write_task_status "$1" 'done' "$2" "$3"
}

track_mark_task_todo() {
  track_write_task_status "$1" 'todo' "$2" '' "${3:-0}"
}
