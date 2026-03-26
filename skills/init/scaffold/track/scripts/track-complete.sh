#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASK_BRANCH="${1:-}"
PR_URL="${2:-}"
TODAY="$(date -u +'%Y-%m-%d')"

if [[ ! "$TASK_BRANCH" =~ ^task/([0-9]+\.[0-9]+)-[a-z0-9-]+$ ]]; then
  echo "Branch '$TASK_BRANCH' is not a Track task branch; nothing to do."
  exit 0
fi

task_id="${BASH_REMATCH[1]}"
task_file="$(find "$ROOT_DIR/.track/tasks" -maxdepth 1 -type f -name "${task_id}-*.md" | head -n 1)"

if [[ -z "$task_file" ]]; then
  echo "No task file found for $task_id; nothing to do."
  exit 0
fi

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
  echo "Task $task_id is already up to date."
  exit 0
fi

mv "$tmp_file" "$task_file"
echo "Updated $task_file"
