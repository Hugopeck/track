#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

DEFAULT_BRANCH="${TRACK_DEFAULT_BRANCH:-main}"
MODE='shared'
OFFLINE=0
BOARD_OUTPUT_PATH="$ROOT_DIR/BOARD.md"
TODO_OUTPUT_PATH="$ROOT_DIR/TODO.md"
PROJECTS_OUTPUT_PATH="$ROOT_DIR/PROJECTS.md"
SOURCE_ROOT=''
TRACK_TODO_TEMP_DIR=''
WARNINGS=()
FOOTER_SOURCE_LABEL=''
FOOTER_UPDATED_AT=''
PR_LOOKUP_STATE='available'

TASK_FILES=()
TASK_IDS=()
TASK_TITLES=()
TASK_RAW_STATUSES=()
TASK_EFFECTIVE_STATUSES=()
TASK_OBSERVED_PR_STATUSES=()
TASK_MODES=()
TASK_PRIORITIES=()
TASK_PROJECT_IDS=()
TASK_DEPENDS=()
TASK_FILES_SERIALIZED=()
TASK_PATHS=()
TASK_PRS=()
TASK_UPDATED=()
TASK_BLOCKED_REASONS=()
TASK_STALE_REASONS=()

PROJECT_FILES=()
PROJECT_IDS=()
PROJECT_TITLES=()
PROJECT_EXCERPTS=()
PROJECT_STATUSES=()

OPEN_PR_TASK_IDS=()
OPEN_PR_URLS=()
OPEN_PR_STATUSES=()

usage() {
  cat <<'USAGE'
Usage: bash .track/scripts/track-todo.sh [--local] [--offline] [--output PATH]

Default mode reads `.track/` from `origin/main` and overlays live open PR metadata via `gh`.
`--output PATH` sets the `BOARD.md` output path; sibling `TODO.md` and `PROJECTS.md`
are written alongside it.
USAGE
}

warn() {
  WARNINGS+=("$1")
}

warn_loud() {
  WARNINGS+=("$1")
  printf 'Warning: %s\n' "$1" >&2
}

set_pr_lookup_unavailable() {
  local reason="$1"
  PR_LOOKUP_STATE='unavailable'
  warn "GitHub PR lookup unavailable ($reason); task status may be stale"
}

note_pr_lookup_partial() {
  local reason="$1"
  if [[ "$PR_LOOKUP_STATE" != 'unavailable' ]]; then
    PR_LOOKUP_STATE='partial'
  fi
  warn "GitHub PR lookup partial: $reason"
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

find_project_index_by_id() {
  local id="$1"
  local i
  for ((i = 0; i < ${#PROJECT_IDS[@]}; i++)); do
    [[ "${PROJECT_IDS[$i]}" == "$id" ]] && {
      printf '%s' "$i"
      return 0
    }
  done
  return 1
}

copy_tree_from_ref() {
  local git_ref="$1"
  local temp_dir="$2"
  local path target_dir

  mkdir -p "$temp_dir/.track/projects" "$temp_dir/.track/tasks"

  while IFS= read -r path; do
    target_dir="$(dirname "$temp_dir/$path")"
    mkdir -p "$target_dir"
    git show "$git_ref:$path" > "$temp_dir/$path"
  done < <(git ls-tree -r --name-only "$git_ref" .track/projects .track/tasks | grep -E '^\.track/(projects|tasks)/.*\.md$')
}

load_source_tree() {
  if [[ "$MODE" == 'local' ]]; then
    SOURCE_ROOT="$ROOT_DIR"
    return 0
  fi

  if ! git rev-parse --verify "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    warn "origin/$DEFAULT_BRANCH is unavailable; falling back to local working tree"
    MODE='local'
    SOURCE_ROOT="$ROOT_DIR"
    return 0
  fi

  TRACK_TODO_TEMP_DIR="$(mktemp -d)"
  trap 'if [[ -n "${TRACK_TODO_TEMP_DIR:-}" ]]; then rm -rf "$TRACK_TODO_TEMP_DIR"; fi' EXIT
  copy_tree_from_ref "origin/$DEFAULT_BRANCH" "$TRACK_TODO_TEMP_DIR"
  if ! find "$TRACK_TODO_TEMP_DIR/.track/tasks" -maxdepth 1 -type f -name '*.md' | grep -q .; then
    warn_loud "origin/$DEFAULT_BRANCH has no flat task files in .track/tasks/; falling back to local working tree"
    MODE='local'
    SOURCE_ROOT="$ROOT_DIR"
    return 0
  fi
  SOURCE_ROOT="$TRACK_TODO_TEMP_DIR"
}

load_projects() {
  local file project_id
  while IFS= read -r file; do
    project_id="$(track_project_id_from_brief "$file")" || continue
    PROJECT_FILES+=("$file")
    PROJECT_IDS+=("$project_id")
    PROJECT_TITLES+=("$(track_project_title_from_brief "$file")")
    PROJECT_EXCERPTS+=("$(track_project_goal_excerpt "$file")")
    if track_parse_project_file "$file"; then
      PROJECT_STATUSES+=("$TRACK_status")
    else
      PROJECT_STATUSES+=("")
    fi
  done < <(find "$SOURCE_ROOT/.track/projects" -maxdepth 1 -type f -name '[0-9]*-*.md' | sort)
}

task_exists_in_source_tree() {
  find "$SOURCE_ROOT/.track/tasks" -maxdepth 1 -type f -name "${1}-*.md" | grep -q .
}

fetch_pr_body() {
  gh pr view "$1" --json body --template '{{.body}}' 2>/dev/null
}

fetch_pr_labels() {
  gh pr view "$1" --json labels --template '{{range $index, $label := .labels}}{{if $index}},{{end}}{{.name}}{{end}}' 2>/dev/null
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

load_open_prs() {
  local lines number url is_draft head_ref title pr_body pr_labels resolver_code

  if [[ $OFFLINE -eq 1 ]]; then
    set_pr_lookup_unavailable 'offline mode enabled'
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    set_pr_lookup_unavailable 'gh not found'
    return 0
  fi

  if ! lines="$(gh pr list --state open --base "$DEFAULT_BRANCH" --json number,url,isDraft,headRefName,title --template '{{range .}}{{printf "%v\t%s\t%t\t%s\t%s\n" .number .url .isDraft .headRefName .title}}{{end}}' 2>/dev/null)"; then
    set_pr_lookup_unavailable 'gh PR lookup failed'
    return 0
  fi

  while IFS=$'\t' read -r number url is_draft head_ref title; do
    [[ -z "$url" ]] && continue

    pr_body=''
    pr_labels=''
    if ! pr_body="$(fetch_pr_body "$number")"; then
      note_pr_lookup_partial "open PR '$url' body unavailable; falling back to labels/title/branch only"
      pr_body=''
    fi
    if ! pr_labels="$(fetch_pr_labels "$number")"; then
      note_pr_lookup_partial "open PR '$url' labels unavailable; falling back to body/title/branch only"
      pr_labels=''
    fi

    if track_resolve_task_id "$pr_body" "$pr_labels" "$title" "$head_ref"; then
      resolver_code=0
    else
      resolver_code=$?
    fi
    if [[ $resolver_code -ne 0 ]]; then
      case "$resolver_code" in
        1) warn "open PR '$url' could not be linked to a task: $TRACK_RESOLVER_ERROR" ;;
        2|3) warn "open PR '$url' could not be linked to a task: $TRACK_RESOLVER_ERROR" ;;
        *) warn "open PR '$url' could not be linked to a task: unexpected resolver failure" ;;
      esac
      continue
    fi

    if ! task_exists_in_source_tree "$TRACK_RESOLVED_TASK_ID"; then
      warn "open PR '$url' resolved to task '$TRACK_RESOLVED_TASK_ID' from $TRACK_RESOLVED_SOURCE, but no matching task file exists in .track/tasks/"
      continue
    fi

    OPEN_PR_TASK_IDS+=("$TRACK_RESOLVED_TASK_ID")
    OPEN_PR_URLS+=("$url")
    if [[ "$is_draft" == 'true' ]]; then
      OPEN_PR_STATUSES+=('active')
    else
      OPEN_PR_STATUSES+=('review')
    fi
  done <<< "$lines"
}

load_tasks() {
  local file effective_status observed_status pr_url depends_serialized files_serialized
  while IFS= read -r file; do
    if ! track_parse_task_file "$file"; then
      warn "$file: $TRACK_parse_error"
      continue
    fi

    depends_serialized="$(track_serialize_items "${TRACK_depends_on[@]-}")"
    files_serialized="$(track_serialize_items "${TRACK_files[@]-}")"
    effective_status="$TRACK_status"
    observed_status=''
    pr_url=''

    if find_open_pr_index_by_task_id "$TRACK_id"; then
      pr_url="${OPEN_PR_URLS[$OPEN_PR_MATCH_INDEX]}"
      observed_status="${OPEN_PR_STATUSES[$OPEN_PR_MATCH_INDEX]}"
    fi

    TASK_FILES+=("$file")
    TASK_IDS+=("$TRACK_id")
    TASK_TITLES+=("$TRACK_title")
    TASK_RAW_STATUSES+=("$TRACK_status")
    TASK_EFFECTIVE_STATUSES+=("$effective_status")
    TASK_OBSERVED_PR_STATUSES+=("$observed_status")
    TASK_MODES+=("$TRACK_mode")
    TASK_PRIORITIES+=("$TRACK_priority")
    TASK_PROJECT_IDS+=("$TRACK_project_id")
    TASK_DEPENDS+=("$depends_serialized")
    TASK_FILES_SERIALIZED+=("$files_serialized")
    TASK_PATHS+=("$(basename "$file")")
    TASK_PRS+=("$pr_url")
    TASK_UPDATED+=("$TRACK_updated")
    TASK_BLOCKED_REASONS+=("$TRACK_blocked_reason")
    TASK_STALE_REASONS+=('')
  done < <(find "$SOURCE_ROOT/.track/tasks" -maxdepth 1 -type f -name '*.md' | sort)
}

observed_status_hint() {
  case "$1" in
    active) printf 'open draft PR suggests active' ;;
    review) printf 'open ready-for-review PR suggests review' ;;
    *) printf 'open PR suggests %s' "$1" ;;
  esac
}

note_task_stale_status() {
  local task_index="$1"
  local reason="$2"

  TASK_STALE_REASONS[$task_index]="$reason"
  warn "task '${TASK_IDS[$task_index]}' status may be stale: canonical '${TASK_RAW_STATUSES[$task_index]}', $reason"
}

resolve_task_stale_statuses() {
  local task_index canonical_status observed_status stale_reason=''

  for ((task_index = 0; task_index < ${#TASK_IDS[@]}; task_index++)); do
    TASK_STALE_REASONS[$task_index]=''
    canonical_status="${TASK_RAW_STATUSES[$task_index]}"
    observed_status="${TASK_OBSERVED_PR_STATUSES[$task_index]}"

    find_open_pr_index_by_task_id "${TASK_IDS[$task_index]}" || true
    if [[ ${OPEN_PR_MATCH_COUNT:-0} -gt 1 ]]; then
      TASK_STALE_REASONS[$task_index]='Multiple open PRs map to this task; resolve manually before continuing.'
      warn "multiple open PRs map to task '${TASK_IDS[$task_index]}'"
      continue
    fi

    stale_reason=''
    if [[ -n "$observed_status" ]]; then
      case "$canonical_status:$observed_status" in
        todo:active|todo:review|active:review|review:active)
          stale_reason="$(observed_status_hint "$observed_status"); run \`bash .track/scripts/track-reconcile.sh\`."
          ;;
        blocked:active|blocked:review|done:active|done:review|cancelled:active|cancelled:review)
          stale_reason="$(observed_status_hint "$observed_status"), which conflicts with canonical status '$canonical_status'; inspect manually."
          ;;
      esac
    elif [[ "$PR_LOOKUP_STATE" == 'available' && ( "$canonical_status" == 'active' || "$canonical_status" == 'review' ) ]]; then
      stale_reason="no linked open PR found for canonical status '$canonical_status'; inspect manually."
    fi

    if [[ -n "$stale_reason" ]]; then
      note_task_stale_status "$task_index" "$stale_reason"
    fi
  done
}

task_blocked_by_dependencies() {
  local task_index="$1"
  local serialized_depends="${TASK_DEPENDS[$task_index]}"
  local IFS="$TRACK_ITEM_SEP"
  local deps=() dep dep_index

  read -r -a deps <<< "$serialized_depends"
  for dep in "${deps[@]-}"; do
    [[ -z "$dep" ]] && continue
    if ! dep_index="$(find_task_index_by_id "$dep")"; then
      return 0
    fi
    if [[ "${TASK_EFFECTIVE_STATUSES[$dep_index]}" != 'done' ]]; then
      return 0
    fi
  done

  return 1
}

resolve_dep_blocked_statuses() {
  local task_index
  for ((task_index = 0; task_index < ${#TASK_IDS[@]}; task_index++)); do
    [[ "${TASK_EFFECTIVE_STATUSES[$task_index]}" != 'todo' ]] && continue
    if task_blocked_by_dependencies "$task_index" || [[ -n "${TASK_STALE_REASONS[$task_index]}" ]]; then
      TASK_EFFECTIVE_STATUSES[$task_index]='blocked'
    fi
  done
}

task_unmet_dependencies_csv() {
  local task_index="$1"
  local serialized_depends="${TASK_DEPENDS[$task_index]}"
  local IFS="$TRACK_ITEM_SEP"
  local deps=() dep dep_index output=''

  read -r -a deps <<< "$serialized_depends"
  for dep in "${deps[@]-}"; do
    [[ -z "$dep" ]] && continue
    if ! dep_index="$(find_task_index_by_id "$dep")"; then
      if [[ -n "$output" ]]; then
        output+=', '
      fi
      output+="$dep"
      continue
    fi
    if [[ "${TASK_EFFECTIVE_STATUSES[$dep_index]}" != 'done' ]]; then
      if [[ -n "$output" ]]; then
        output+=', '
      fi
      output+="$dep"
    fi
  done

  printf '%s' "$output"
}

task_overlap_blockers_csv() {
  local task_index="$1"
  local other_index output=''

  for ((other_index = 0; other_index < ${#TASK_IDS[@]}; other_index++)); do
    [[ $other_index -eq $task_index ]] && continue
    if [[ "${TASK_EFFECTIVE_STATUSES[$other_index]}" != 'active' && "${TASK_EFFECTIVE_STATUSES[$other_index]}" != 'review' ]]; then
      continue
    fi
    if track_globs_overlap_serialized "${TASK_FILES_SERIALIZED[$task_index]}" "${TASK_FILES_SERIALIZED[$other_index]}"; then
      if [[ -n "$output" ]]; then
        output+=', '
      fi
      output+="${TASK_IDS[$other_index]}"
    fi
  done

  printf '%s' "$output"
}

task_blocked_by_overlap() {
  [[ -n "$(task_overlap_blockers_csv "$1")" ]]
}

task_is_immediate_start() {
  local task_index="$1"
  [[ "${TASK_EFFECTIVE_STATUSES[$task_index]}" == 'todo' ]] || return 1
  task_blocked_by_dependencies "$task_index" && return 1
  task_blocked_by_overlap "$task_index" && return 1
  return 0
}

task_sort_key() {
  local task_index="$1"
  printf '%02d\t%02d\t%s\n' \
    "$(track_status_rank "${TASK_EFFECTIVE_STATUSES[$task_index]}")" \
    "$(track_priority_rank "${TASK_PRIORITIES[$task_index]}")" \
    "${TASK_IDS[$task_index]}"
}

project_sort_key() {
  local project_id="$1"
  local i best_rank=99 has_open=0 rank paused_bucket=0 project_index project_status=''

  if project_index="$(find_project_index_by_id "$project_id")"; then
    project_status="${PROJECT_STATUSES[$project_index]}"
  fi

  if [[ "$project_status" == 'paused' ]]; then
    paused_bucket=1
  fi

  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
    if ! track_is_terminal_status "${TASK_EFFECTIVE_STATUSES[$i]}"; then
      has_open=1
      rank="$(track_priority_rank "${TASK_PRIORITIES[$i]}")"
      if [[ $rank -lt $best_rank ]]; then
        best_rank=$rank
      fi
    fi
  done

  [[ $has_open -eq 0 ]] && best_rank=99
  printf '%01d\t%02d\t%06d\t%s\n' "$paused_bucket" "$best_rank" "$project_id" "$project_id"
}

completed_task_sort_key() {
  local task_index="$1"
  printf '%s\t%s\n' "${TASK_UPDATED[$task_index]}" "${TASK_IDS[$task_index]}"
}

markdown_link_text() {
  local text="$1"
  text=${text//[/\\[}
  text=${text//]/\\]}
  printf '%s' "$text"
}

task_depends_display() {
  local index="$1"
  if [[ -n "${TASK_DEPENDS[$index]}" ]]; then
    printf '%s' "${TASK_DEPENDS[$index]}" | tr "$TRACK_ITEM_SEP" ',' | sed 's/,/, /g'
  else
    printf '—'
  fi
}

task_status_display() {
  local index="$1"
  local status_display="${TASK_RAW_STATUSES[$index]}"
  if [[ -n "${TASK_PRS[$index]}" ]]; then
    status_display+=" · [PR](${TASK_PRS[$index]})"
  fi
  printf '%s' "$status_display"
}

project_done_count() {
  local project_id="$1"
  local i count=0
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
    [[ "${TASK_EFFECTIVE_STATUSES[$i]}" == 'done' ]] && count=$((count + 1))
  done
  printf '%s' "$count"
}

project_completed_count() {
  local project_id="$1"
  local i count=0
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
    case "${TASK_EFFECTIVE_STATUSES[$i]}" in
      done|cancelled) count=$((count + 1)) ;;
    esac
  done
  printf '%s' "$count"
}

project_total_count() {
  local project_id="$1"
  local i count=0
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
    count=$((count + 1))
  done
  printf '%s' "$count"
}

project_completion_bar() {
  local done_count="$1"
  local total_count="$2"
  local percent=0 filled empty i bar=''

  if [[ "$total_count" -gt 0 ]]; then
    percent=$((done_count * 100 / total_count))
  fi

  filled=$((percent / 10))
  if [[ $filled -gt 10 ]]; then
    filled=10
  fi
  empty=$((10 - filled))

  for ((i = 0; i < filled; i++)); do
    bar+='█'
  done
  for ((i = 0; i < empty; i++)); do
    bar+='░'
  done

  printf '`[%s] %s%%` (%s/%s)' "$bar" "$percent" "$done_count" "$total_count"
}

project_status_label() {
  local project_id="$1"
  local i total_count=0 done_count=0 cancelled_count=0 has_active=0 has_review=0
  local project_index project_status=""

  if project_index="$(find_project_index_by_id "$project_id")"; then
    project_status="${PROJECT_STATUSES[$project_index]}"
  fi

  if [[ "$project_status" == 'paused' ]]; then
    printf 'Paused'
    return 0
  fi

  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
    total_count=$((total_count + 1))
    case "${TASK_EFFECTIVE_STATUSES[$i]}" in
      done) done_count=$((done_count + 1)) ;;
      cancelled) cancelled_count=$((cancelled_count + 1)) ;;
      active|blocked) has_active=1 ;;
      review) has_review=1 ;;
    esac
  done

  if [[ $total_count -eq 0 ]]; then
    printf 'Planning'
    return 0
  fi

  if [[ $has_active -eq 1 || $has_review -eq 1 ]]; then
    printf 'Active'
    return 0
  fi

  if [[ $done_count -eq 0 && $cancelled_count -lt $total_count ]]; then
    printf 'Planning'
    return 0
  fi

  if [[ $done_count -gt 0 && $done_count -eq $total_count ]]; then
    printf 'Done'
    return 0
  fi

  if [[ $done_count -eq 0 && $cancelled_count -eq $total_count ]]; then
    printf 'Cancelled'
    return 0
  fi

  if [[ $done_count -gt 0 && $((done_count + cancelled_count)) -eq $total_count ]]; then
    printf 'Done'
    return 0
  fi

  printf 'Active'
}

render_footer() {
  printf 'Generated from `%s` `.track/` state plus live open PR metadata. Updated %s.\n' \
    "$FOOTER_SOURCE_LABEL" \
    "$FOOTER_UPDATED_AT"
  printf '%s projects derived from `.track/` state.\n' "${#PROJECT_IDS[@]}"
}

render_board_task_row() {
  local index="$1"
  local task_link
  task_link="[$(markdown_link_text "${TASK_TITLES[$index]}")](.track/tasks/${TASK_PATHS[$index]})"

  printf '| [%s](.track/tasks/%s) | %s | %s | %s | %s |\n' \
    "${TASK_IDS[$index]}" \
    "${TASK_PATHS[$index]}" \
    "$task_link" \
    "${TASK_PRIORITIES[$index]}" \
    "$(task_depends_display "$index")" \
    "$(task_status_display "$index")"
}

render_cross_project_dependencies() {
  local seen='' i dep dep_index source_project target_project edge
  local IFS="$TRACK_ITEM_SEP"
  local deps=()
  local found=0

  printf '## Cross-Project Dependencies\n\n```\n'
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    read -r -a deps <<< "${TASK_DEPENDS[$i]}"
    source_project="${TASK_PROJECT_IDS[$i]}"
    for dep in "${deps[@]-}"; do
      [[ -z "$dep" ]] && continue
      dep_index="$(find_task_index_by_id "$dep" || true)"
      [[ -z "$dep_index" ]] && continue
      target_project="${TASK_PROJECT_IDS[$dep_index]}"
      [[ "$target_project" == "$source_project" ]] && continue
      edge="${target_project} -> ${source_project}"
      if [[ "$seen" != *"|$edge|"* ]]; then
        printf '%s\n' "$edge"
        seen+="|$edge|"
        found=1
      fi
    done
  done
  if [[ $found -eq 0 ]]; then
    printf 'No cross-project dependencies.\n'
  fi
  printf '```\n\n'
}

render_warnings() {
  local warning
  if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    return
  fi

  printf '## Warnings\n\n'
  for warning in "${WARNINGS[@]}"; do
    printf -- '- %s\n' "$warning"
  done
  printf '\n'
}

render_board() {
  local project_sort_lines='' project_sort_line project_id project_index
  local task_sort_lines task_sort_line task_index project_excerpt i
  local done_count total_count

  mkdir -p "$(dirname "$BOARD_OUTPUT_PATH")"
  {
    printf '# Board\n\n'

    for project_id in "${PROJECT_IDS[@]-}"; do
      [[ -z "$project_id" ]] && continue
      project_sort_lines+="$(project_sort_key "$project_id")"$'\n'
    done

    while IFS= read -r project_sort_line; do
      [[ -z "$project_sort_line" ]] && continue
      project_id="${project_sort_line##*$'\t'}"
      project_index="$(find_project_index_by_id "$project_id")"
      done_count="$(project_done_count "$project_id")"
      total_count="$(project_total_count "$project_id")"

      printf -- '---\n\n'
      printf '## [Project %s: %s](.track/projects/%s) `[%s/%s Tasks]`\n\n' \
        "$project_id" \
        "${PROJECT_TITLES[$project_index]}" \
        "$(basename "${PROJECT_FILES[$project_index]}")" \
        "$done_count" \
        "$total_count"

      project_excerpt="${PROJECT_EXCERPTS[$project_index]}"
      if [[ -n "$project_excerpt" ]]; then
        printf '> %s\n\n' "$project_excerpt"
      fi

      printf '| ID | Task | Priority | Depends | Status |\n'
      printf '| --- | --- | --- | --- | --- |\n'

      task_sort_lines=''
      for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
        [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
        task_sort_lines+="$(task_sort_key "$i")"$'\t'"$i"$'\n'
      done

      while IFS= read -r task_sort_line; do
        [[ -z "$task_sort_line" ]] && continue
        task_index="${task_sort_line##*$'\t'}"
        render_board_task_row "$task_index"
      done < <(printf '%s' "$task_sort_lines" | sort)

      printf '\n'
    done < <(printf '%s' "$project_sort_lines" | sort)

    render_cross_project_dependencies
    render_warnings
    render_footer
  } > "$BOARD_OUTPUT_PATH"
}

render_todo_section_items() {
  local section="$1"
  local found=0 task_sort_lines='' task_sort_line task_index
  local unmet overlap reasons
  local completed_sort_lines=''

  case "$section" in
    immediate|up_next|blocked)
      for ((task_index = 0; task_index < ${#TASK_IDS[@]}; task_index++)); do
        local _es="${TASK_EFFECTIVE_STATUSES[$task_index]}"
        if [[ "$_es" == 'todo' || "$_es" == 'blocked' ]]; then
          : # include
        else
          continue
        fi
        task_sort_lines+="$(task_sort_key "$task_index")"$'\t'"$task_index"$'\n'
      done

      while IFS= read -r task_sort_line; do
        [[ -z "$task_sort_line" ]] && continue
        task_index="${task_sort_line##*$'\t'}"
        unmet="$(task_unmet_dependencies_csv "$task_index")"
        overlap="$(task_overlap_blockers_csv "$task_index")"

        case "$section" in
          immediate)
            if [[ -z "$unmet" && -z "$overlap" ]] && [[ "${TASK_PRIORITIES[$task_index]}" == 'urgent' || "${TASK_PRIORITIES[$task_index]}" == 'high' ]]; then
              printf -- '- [ ] [%s] [%s](.track/tasks/%s)\n' \
                "${TASK_IDS[$task_index]}" \
                "$(markdown_link_text "${TASK_TITLES[$task_index]}")" \
                "${TASK_PATHS[$task_index]}"
              found=1
            fi
            ;;
          up_next)
            if [[ -z "$unmet" && -z "$overlap" ]] && [[ "${TASK_PRIORITIES[$task_index]}" == 'medium' || "${TASK_PRIORITIES[$task_index]}" == 'low' ]]; then
              printf -- '- [ ] [%s] [%s](.track/tasks/%s)\n' \
                "${TASK_IDS[$task_index]}" \
                "$(markdown_link_text "${TASK_TITLES[$task_index]}")" \
                "${TASK_PATHS[$task_index]}"
              found=1
            fi
            ;;
          blocked)
            reasons=''
            if [[ -n "$unmet" ]]; then
              reasons="Depends on $unmet"
            fi
            if [[ -n "$overlap" ]]; then
              [[ -n "$reasons" ]] && reasons+="; "
              reasons+="Blocked by active work in $overlap"
            fi
            if [[ -n "${TASK_BLOCKED_REASONS[$task_index]}" ]]; then
              [[ -n "$reasons" ]] && reasons+="; "
              reasons+="${TASK_BLOCKED_REASONS[$task_index]}"
            fi
            if [[ -n "${TASK_STALE_REASONS[$task_index]}" ]]; then
              [[ -n "$reasons" ]] && reasons+="; "
              reasons+="${TASK_STALE_REASONS[$task_index]}"
            fi
            if [[ -n "$reasons" ]]; then
              printf -- '- [ ] [%s] [%s](.track/tasks/%s) *(%s)*\n' \
                "${TASK_IDS[$task_index]}" \
                "$(markdown_link_text "${TASK_TITLES[$task_index]}")" \
                "${TASK_PATHS[$task_index]}" \
                "$reasons"
              found=1
            fi
            ;;
        esac
      done < <(printf '%s' "$task_sort_lines" | sort)
      ;;
    completed)
      for ((task_index = 0; task_index < ${#TASK_IDS[@]}; task_index++)); do
        [[ "${TASK_EFFECTIVE_STATUSES[$task_index]}" == 'done' ]] || continue
        completed_sort_lines+="$(completed_task_sort_key "$task_index")"$'\t'"$task_index"$'\n'
      done

      while IFS= read -r task_sort_line; do
        [[ -z "$task_sort_line" ]] && continue
        task_index="${task_sort_line##*$'\t'}"
        printf -- '- [x] [%s] [%s](.track/tasks/%s)\n' \
          "${TASK_IDS[$task_index]}" \
          "$(markdown_link_text "${TASK_TITLES[$task_index]}")" \
          "${TASK_PATHS[$task_index]}"
        found=1
      done < <(printf '%s' "$completed_sort_lines" | sort -r)
      ;;
  esac

  if [[ $found -eq 0 ]]; then
    printf -- '- None.\n'
  fi
  printf '\n'
}

render_todo() {
  mkdir -p "$(dirname "$TODO_OUTPUT_PATH")"
  {
    printf '# TODO\n\n'
    printf '## Immediate Starts (Unblocked & High/Urgent Priority)\n\n'
    render_todo_section_items immediate
    printf '## Up Next (Unblocked & Medium/Low Priority)\n\n'
    render_todo_section_items up_next
    printf '## Blocked\n\n'
    render_todo_section_items blocked
    printf '## Recently Completed\n\n'
    render_todo_section_items completed
    render_warnings
    render_footer
  } > "$TODO_OUTPUT_PATH"
}

render_projects() {
  local project_sort_lines='' project_sort_line project_id project_index
  local done_count total_count

  mkdir -p "$(dirname "$PROJECTS_OUTPUT_PATH")"
  {
    printf '# Projects Overview\n\n'
    printf '| ID | Project | Description | Completion | Status |\n'
    printf '| :--- | :--- | :--- | :--- | :--- |\n'

    for project_id in "${PROJECT_IDS[@]-}"; do
      [[ -z "$project_id" ]] && continue
      project_sort_lines+="$(project_sort_key "$project_id")"$'\n'
    done

    while IFS= read -r project_sort_line; do
      [[ -z "$project_sort_line" ]] && continue
      project_id="${project_sort_line##*$'\t'}"
      project_index="$(find_project_index_by_id "$project_id")"
      completed_count="$(project_completed_count "$project_id")"
      total_count="$(project_total_count "$project_id")"

      printf '| [%s](.track/projects/%s) | %s | %s | %s | %s |\n' \
        "$project_id" \
        "$(basename "${PROJECT_FILES[$project_index]}")" \
        "$(markdown_link_text "${PROJECT_TITLES[$project_index]}")" \
        "$(markdown_link_text "${PROJECT_EXCERPTS[$project_index]}")" \
        "$(project_completion_bar "$completed_count" "$total_count")" \
        "$(project_status_label "$project_id")"
    done < <(printf '%s' "$project_sort_lines" | sort)

    printf '\n'
    render_warnings
    render_footer
  } > "$PROJECTS_OUTPUT_PATH"
}

generate_views() {
  render_board
  render_todo
  render_projects
}

main() {
  local output_dir
  cd "$ROOT_DIR"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local)
        MODE='local'
        ;;
      --offline)
        OFFLINE=1
        ;;
      --output)
        shift
        BOARD_OUTPUT_PATH="$1"
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

  output_dir="$(dirname "$BOARD_OUTPUT_PATH")"
  TODO_OUTPUT_PATH="$output_dir/TODO.md"
  PROJECTS_OUTPUT_PATH="$output_dir/PROJECTS.md"

  load_source_tree

  if [[ ! -d "$SOURCE_ROOT/.track/tasks" || ! -d "$SOURCE_ROOT/.track/projects" ]]; then
    printf 'track: .track/ not found — run /track:setup-track to set up this repo\n' >&2
    exit 1
  fi

  FOOTER_SOURCE_LABEL="$([[ "$MODE" == 'local' ]] && printf 'local working tree' || printf 'origin/%s' "$DEFAULT_BRANCH")"
  FOOTER_UPDATED_AT="$(date -u +'%Y-%m-%d %H:%M UTC')"

  load_projects
  load_open_prs
  load_tasks
  resolve_task_stale_statuses
  resolve_dep_blocked_statuses
  generate_views
  printf 'Wrote %s\n' "$BOARD_OUTPUT_PATH"
  printf 'Wrote %s\n' "$TODO_OUTPUT_PATH"
  printf 'Wrote %s\n' "$PROJECTS_OUTPUT_PATH"
}

main "$@"
