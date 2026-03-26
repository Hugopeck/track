#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

TASK_DIR="$ROOT_DIR/.track/tasks"
PROJECT_DIR="$ROOT_DIR/.track/projects"
DEFAULT_BRANCH="${TRACK_DEFAULT_BRANCH:-main}"
EXIT_CODE=0

TASK_FILES=()
TASK_IDS=()
TASK_STATUSES=()
TASK_PROJECT_IDS=()
TASK_PATHS=()
PROJECT_IDS=()

print_error() {
  printf 'Error: %s\n' "$1" >&2
  EXIT_CODE=1
}

print_warning() {
  printf 'Warning: %s\n' "$1" >&2
}

contains_value() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" == "$needle" ]] && return 0
  done
  return 1
}

find_task_index_by_id() {
  local id="$1"
  local i
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_IDS[$i]}" == "$id" ]] && {
      printf '%s' "$i"
      return 0
    }
  done
  return 1
}

frontmatter_has_key() {
  local file="$1"
  local key="$2"
  awk -v target="$key" '
    { gsub(/\r$/, "") }
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && $0 ~ ("^" target ":[[:space:]]*") { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

collect_project_ids() {
  local file project_id
  while IFS= read -r file; do
    project_id="$(track_project_id_from_brief "$file")" || continue
    PROJECT_IDS+=("$project_id")
  done < <(find "$PROJECT_DIR" -maxdepth 1 -type f -name '[0-9]*-*.md' | sort)
}

validate_required_sections() {
  local file="$1"
  local section
  for section in 'Context' 'Acceptance Criteria' 'Notes'; do
    if ! grep -Eq "^## ${section}[[:space:]]*$" "$file"; then
      print_error "$file: missing required section '## ${section}'. Add a '## ${section}' heading with content below it"
    fi
  done
}

validate_task_file() {
  local file="$1"
  local required_fields=(id title status mode priority project_id created updated depends_on files)
  local key head_project_id dep

  if ! track_parse_task_file "$file"; then
    print_error "$file: $TRACK_parse_error"
    return
  fi

  for key in "${required_fields[@]}"; do
    if ! frontmatter_has_key "$file" "$key"; then
      print_error "$file: missing required field '$key'. Add '$key:' to the YAML frontmatter"
    fi
  done

  if ! contains_value "$TRACK_status" todo active review done cancelled; then
    print_error "$file: invalid status '$TRACK_status'. Valid values: todo, active, review, done, cancelled"
  fi

  if ! contains_value "$TRACK_mode" investigate plan implement; then
    print_error "$file: invalid mode '$TRACK_mode'. Valid values: investigate, plan, implement"
  fi

  if ! contains_value "$TRACK_priority" urgent high medium low; then
    print_error "$file: invalid priority '$TRACK_priority'. Valid values: urgent, high, medium, low"
  fi

  if ! contains_value "$TRACK_project_id" "${PROJECT_IDS[@]-}"; then
    print_error "$file: unknown project_id '$TRACK_project_id'. Available: ${PROJECT_IDS[*]-none}. Create a project brief at .track/projects/ or fix project_id"
  fi

  if track_is_dotted_id "$TRACK_id"; then
    head_project_id="${TRACK_id%%.*}"
    if [[ "$head_project_id" != "$TRACK_project_id" ]]; then
      print_error "$file: dotted id '$TRACK_id' prefix must equal project_id '$TRACK_project_id'. Change id to '${TRACK_project_id}.N' or fix project_id"
    fi
  elif track_is_legacy_id "$TRACK_id"; then
    if [[ "$TRACK_status" != 'done' && "$TRACK_status" != 'cancelled' ]]; then
      print_error "$file: legacy numeric task ids are only allowed for archived done/cancelled tasks. Use dotted id format (e.g., '1.1') for active work"
    fi
    if [[ "$TRACK_project_id" != '0' ]]; then
      print_error "$file: legacy numeric task id '$TRACK_id' must use project_id '0'. Set project_id: \"0\""
    fi
  else
    print_error "$file: task id '$TRACK_id' must be dotted format (e.g., '1.1') or legacy numeric (e.g., '100')"
  fi

  if [[ "$TRACK_status" == 'cancelled' && -z "$TRACK_cancelled_reason" ]]; then
    print_error "$file: cancelled tasks require cancelled_reason. Add 'cancelled_reason: \"reason\"' to the frontmatter"
  fi

  validate_required_sections "$file"

  TASK_FILES+=("$file")
  TASK_IDS+=("$TRACK_id")
  TASK_STATUSES+=("$TRACK_status")
  TASK_PROJECT_IDS+=("$TRACK_project_id")
  TASK_PATHS+=("$(basename "$file")")

  for dep in "${TRACK_depends_on[@]-}"; do
    [[ -z "$dep" ]] && continue
    if [[ "$dep" == "$TRACK_id" ]]; then
      print_error "$file: depends_on may not reference task itself ('$dep'). Remove '$dep' from the depends_on list"
    fi
  done
}

validate_duplicate_ids() {
  local i j
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    for ((j = i + 1; j < ${#TASK_IDS[@]}; j++)); do
      if [[ "${TASK_IDS[$i]}" == "${TASK_IDS[$j]}" ]]; then
        print_error "duplicate task id '${TASK_IDS[$i]}' in ${TASK_PATHS[$i]} and ${TASK_PATHS[$j]}. Each task must have a unique id — rename or delete the duplicate"
      fi
    done
  done
}

validate_dependencies() {
  local i dep dep_index dep_status
  for ((i = 0; i < ${#TASK_FILES[@]}; i++)); do
    if ! track_parse_task_file "${TASK_FILES[$i]}"; then
      continue
    fi

    for dep in "${TRACK_depends_on[@]-}"; do
      [[ -z "$dep" ]] && continue
      if ! dep_index="$(find_task_index_by_id "$dep")"; then
        print_error "${TASK_FILES[$i]}: depends_on references missing task '$dep'. Create a task with id '$dep' or remove it from depends_on"
        continue
      fi

      dep_status="${TASK_STATUSES[$dep_index]}"
      if [[ "${TASK_STATUSES[$i]}" == 'active' || "${TASK_STATUSES[$i]}" == 'review' ]]; then
        if [[ "$dep_status" != 'done' ]]; then
          print_error "${TASK_FILES[$i]}: active/review task depends on '$dep' which is '$dep_status' (not done). Complete '$dep' first, remove the dependency, or set this task to todo"
        fi
      fi
    done
  done
}

open_pr_metadata() {
  local base_branch="$1"
  gh pr list \
    --state open \
    --base "$base_branch" \
    --json url,isDraft,headRefName,baseRefName,state \
    --template '{{range .}}{{printf "%s\t%t\t%s\t%s\t%s\n" .url .isDraft .headRefName .baseRefName .state}}{{end}}'
}

main_task_file_for_id() {
  local task_id="$1"
  local escaped_id="${task_id//./\\.}"
  git ls-tree -r --name-only "origin/$DEFAULT_BRANCH" .track/tasks 2>/dev/null | grep -E "(^|/)${escaped_id}-[a-z0-9-]+\.md$" | head -n 1
}

main_task_status_for_path() {
  local path="$1"
  git show "origin/$DEFAULT_BRANCH:$path" 2>/dev/null | awk '
    { gsub(/\r$/, "") }
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && /^status:[[:space:]]*/ {
      sub(/^status:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  '
}

validate_open_prs() {
  local pr_lines url is_draft head_ref base_ref state task_id file_on_main main_status
  local pr_task_ids=() pr_branches=()
  local i j

  if ! command -v gh >/dev/null 2>&1; then
    print_warning 'gh not found; skipping live PR checks'
    return
  fi

  if [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    print_warning 'GH_TOKEN not set; skipping live PR checks'
    return
  fi

  if ! git rev-parse --verify "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    print_warning "origin/$DEFAULT_BRANCH not available; skipping default-branch PR checks"
    return
  fi

  if ! pr_lines="$(open_pr_metadata "$DEFAULT_BRANCH")"; then
    print_warning 'gh PR lookup failed; skipping live PR checks'
    return
  fi

  while IFS=$'\t' read -r url is_draft head_ref base_ref state; do
    [[ -z "$head_ref" ]] && continue
    if [[ "$head_ref" =~ ^task/([0-9]+\.[0-9]+)-[a-z0-9-]+$ ]]; then
      task_id="${BASH_REMATCH[1]}"
      pr_task_ids+=("$task_id")
      pr_branches+=("$head_ref")

      file_on_main="$(main_task_file_for_id "$task_id")"
      if [[ -z "$file_on_main" ]]; then
        print_error "open PR '$url' references task '$task_id' but no matching task file exists on origin/$DEFAULT_BRANCH. Create the task file or close the orphaned PR"
        continue
      fi

      main_status="$(main_task_status_for_path "$file_on_main")"
      if [[ "$main_status" == 'done' || "$main_status" == 'cancelled' ]]; then
        print_error "open PR '$url' references terminal task '$task_id' (done/cancelled) on origin/$DEFAULT_BRANCH. Close the PR or reopen the task"
      fi
    fi
  done <<< "$pr_lines"

  for ((i = 0; i < ${#pr_task_ids[@]}; i++)); do
    for ((j = i + 1; j < ${#pr_task_ids[@]}; j++)); do
      if [[ "${pr_task_ids[$i]}" == "${pr_task_ids[$j]}" ]]; then
        print_error "multiple open PRs map to task '${pr_task_ids[$i]}' (${pr_branches[$i]}, ${pr_branches[$j]}). Close the duplicate PR — each task should have exactly one open PR"
      fi
    done
  done
}

validate_pull_request_context() {
  local head_ref branch_task_id task_file pr_draft_state
  head_ref="${GITHUB_HEAD_REF:-}"
  [[ -z "$head_ref" ]] && return

  if [[ ! "$head_ref" =~ ^task/([0-9]+\.[0-9]+)-[a-z0-9-]+$ ]]; then
    return
  fi

  branch_task_id="${BASH_REMATCH[1]}"
  task_file="$(find "$TASK_DIR" -maxdepth 1 -type f -name "${branch_task_id}-*.md" | head -n 1)"

  if [[ -z "$task_file" ]]; then
    print_error "branch '$head_ref' references task '$branch_task_id' but no matching task file exists in .track/tasks/. Create ${branch_task_id}-{slug}.md or rename the branch"
    return
  fi

  if ! track_parse_task_file "$task_file"; then
    print_error "$task_file: $TRACK_parse_error"
    return
  fi

  if [[ "$TRACK_status" == 'done' || "$TRACK_status" == 'cancelled' ]]; then
    print_error "$task_file: task on implementation branch may not be '$TRACK_status' while PR is open. Set status to 'active' (draft PR) or 'review' (ready PR)"
  fi

  if command -v gh >/dev/null 2>&1 && [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    pr_draft_state="$(gh pr list --head "$head_ref" --state open --json isDraft --template '{{range .}}{{printf "%t\n" .isDraft}}{{end}}' 2>/dev/null || true)"
    if [[ -n "$pr_draft_state" ]]; then
      if [[ "$pr_draft_state" == 'true' && "$TRACK_status" != 'active' ]]; then
        print_error "$task_file: draft PR requires raw status 'active' but found '$TRACK_status'. Set status: active"
      fi
      if [[ "$pr_draft_state" == 'false' && "$TRACK_status" != 'review' ]]; then
        print_error "$task_file: ready-for-review PR requires raw status 'review' but found '$TRACK_status'. Set status: review"
      fi
    fi
  fi
}

cleanup_expired_plans() {
  local plans_dir="$ROOT_DIR/.track/plans"
  [[ -d "$plans_dir" ]] || return 0
  local today_epoch plan_file created_str created_epoch age_days
  today_epoch="$(date -u +%s)"
  while IFS= read -r plan_file; do
    [[ -z "$plan_file" ]] && continue
    created_str="$(awk '/^created:/ { sub(/^created:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }' "$plan_file")"
    if [[ -z "$created_str" ]]; then
      print_warning "$(basename "$plan_file"): plan missing 'created' field — cannot auto-expire"
      continue
    fi
    created_epoch="$(date -u -j -f "%Y-%m-%d" "$created_str" +%s 2>/dev/null || date -u -d "$created_str" +%s 2>/dev/null)" || continue
    age_days=$(( (today_epoch - created_epoch) / 86400 ))
    if [[ $age_days -ge 7 ]]; then
      printf 'Expired plan removed: %s (created %s, %d days ago)\n' "$(basename "$plan_file")" "$created_str" "$age_days"
      rm -f "$plan_file"
    fi
  done < <(find "$plans_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' 2>/dev/null)
}

validate_plans() {
  local plans_dir="$ROOT_DIR/.track/plans"
  [[ -d "$plans_dir" ]] || return 0
  local plan_file task_id
  while IFS= read -r plan_file; do
    [[ -z "$plan_file" ]] && continue
    task_id="$(awk '/^task_id:/ { sub(/^task_id:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }' "$plan_file")"
    if [[ -n "$task_id" && "$task_id" != '""' ]]; then
      if ! find_task_index_by_id "$task_id" >/dev/null 2>&1; then
        print_warning "$(basename "$plan_file"): references task_id '$task_id' which does not exist"
      fi
    fi
  done < <(find "$plans_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' 2>/dev/null)
}

main() {
  if [[ ! -d "$TASK_DIR" ]]; then
    print_error '.track/tasks directory not found. Run /track:init to scaffold Track, or create .track/tasks/ manually'
    exit "$EXIT_CODE"
  fi

  cleanup_expired_plans

  collect_project_ids

  local task_file
  while IFS= read -r task_file; do
    validate_task_file "$task_file"
  done < <(find "$TASK_DIR" -maxdepth 1 -type f -name '*.md' | sort)

  validate_duplicate_ids
  validate_dependencies
  validate_plans
  validate_open_prs

  if [[ "${GITHUB_EVENT_NAME:-}" == 'pull_request' ]]; then
    validate_pull_request_context
  fi

  if [[ $EXIT_CODE -eq 0 ]]; then
    local num_tasks=${#TASK_IDS[@]}
    local num_projects=${#PROJECT_IDS[@]}
    local num_todo=0 num_active=0 num_review=0 num_done=0
    local s
    for s in "${TASK_STATUSES[@]-}"; do
      case "$s" in
        todo) num_todo=$((num_todo + 1)) ;;
        active) num_active=$((num_active + 1)) ;;
        review) num_review=$((num_review + 1)) ;;
        done) num_done=$((num_done + 1)) ;;
      esac
    done
    echo "Track validation passed. $num_tasks tasks across $num_projects projects. $num_todo todo, $num_active active, $num_review review, $num_done done."
  fi

  exit "$EXIT_CODE"
}

main "$@"
