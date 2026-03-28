#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=./track-common.sh
source "$ROOT_DIR/.track/scripts/track-common.sh"

DEFAULT_BRANCH="${TRACK_DEFAULT_BRANCH:-main}"
MODE='shared'
OFFLINE=0
OUTPUT_PATH="$ROOT_DIR/TODO.md"
SOURCE_ROOT=''
TRACK_TODO_TEMP_DIR=''
WARNINGS=()

TASK_FILES=()
TASK_IDS=()
TASK_TITLES=()
TASK_RAW_STATUSES=()
TASK_EFFECTIVE_STATUSES=()
TASK_MODES=()
TASK_PRIORITIES=()
TASK_PROJECT_IDS=()
TASK_DEPENDS=()
TASK_FILES_SERIALIZED=()
TASK_PATHS=()
TASK_PRS=()

PROJECT_FILES=()
PROJECT_IDS=()
PROJECT_TITLES=()
PROJECT_EXCERPTS=()

OPEN_PR_TASK_IDS=()
OPEN_PR_URLS=()
OPEN_PR_STATUSES=()

usage() {
  cat <<'USAGE'
Usage: bash .track/scripts/track-todo.sh [--local] [--offline] [--output PATH]

Default mode reads `.track/` from `origin/main` and overlays live open PR metadata via `gh`.
USAGE
}

warn() {
  WARNINGS+=("$1")
}

warn_loud() {
  WARNINGS+=("$1")
  printf 'Warning: %s\n' "$1" >&2
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
  for ((i = 0; i < ${#OPEN_PR_TASK_IDS[@]}; i++)); do
    if [[ "${OPEN_PR_TASK_IDS[$i]}" == "$id" ]]; then
      match_count=$((match_count + 1))
      OPEN_PR_MATCH_INDEX="$i"
    fi
  done

  if [[ $match_count -gt 1 ]]; then
    warn "multiple open PRs map to task '$id'"
    return 1
  fi

  [[ $match_count -eq 1 ]]
}

load_open_prs() {
  local lines number url is_draft head_ref title pr_body pr_labels resolver_code

  if [[ $OFFLINE -eq 1 ]]; then
    warn 'offline mode enabled; skipping GitHub PR lookup'
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    warn 'gh not found; falling back to offline mode'
    return 0
  fi

  if ! lines="$(gh pr list --state open --base "$DEFAULT_BRANCH" --json number,url,isDraft,headRefName,title --template '{{range .}}{{printf "%v\t%s\t%t\t%s\t%s\n" .number .url .isDraft .headRefName .title}}{{end}}' 2>/dev/null)"; then
    warn 'gh PR lookup failed; falling back to offline mode'
    return 0
  fi

  while IFS=$'\t' read -r number url is_draft head_ref title; do
    [[ -z "$url" ]] && continue

    pr_body=''
    pr_labels=''
    if ! pr_body="$(fetch_pr_body "$number")"; then
      warn "open PR '$url': could not fetch PR body; falling back to labels/title/branch only"
      pr_body=''
    fi
    if ! pr_labels="$(fetch_pr_labels "$number")"; then
      warn "open PR '$url': could not fetch PR labels; falling back to body/title/branch only"
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
      OPEN_PR_STATUSES+=("active")
    else
      OPEN_PR_STATUSES+=("review")
    fi
  done <<< "$lines"
}

load_tasks() {
  local file effective_status pr_url depends_serialized files_serialized
  while IFS= read -r file; do
    if ! track_parse_task_file "$file"; then
      warn "$file: $TRACK_parse_error"
      continue
    fi

    depends_serialized="$(track_serialize_items "${TRACK_depends_on[@]-}")"
    files_serialized="$(track_serialize_items "${TRACK_files[@]-}")"
    effective_status="$TRACK_status"
    pr_url=''

    if ! track_is_terminal_status "$TRACK_status"; then
      if find_open_pr_index_by_task_id "$TRACK_id"; then
        pr_url="${OPEN_PR_URLS[$OPEN_PR_MATCH_INDEX]}"
        effective_status="${OPEN_PR_STATUSES[$OPEN_PR_MATCH_INDEX]}"
      else
        effective_status='todo'
      fi
    fi

    TASK_FILES+=("$file")
    TASK_IDS+=("$TRACK_id")
    TASK_TITLES+=("$TRACK_title")
    TASK_RAW_STATUSES+=("$TRACK_status")
    TASK_EFFECTIVE_STATUSES+=("$effective_status")
    TASK_MODES+=("$TRACK_mode")
    TASK_PRIORITIES+=("$TRACK_priority")
    TASK_PROJECT_IDS+=("$TRACK_project_id")
    TASK_DEPENDS+=("$depends_serialized")
    TASK_FILES_SERIALIZED+=("$files_serialized")
    TASK_PATHS+=("$(basename "$file")")
    TASK_PRS+=("$pr_url")
  done < <(find "$SOURCE_ROOT/.track/tasks" -maxdepth 1 -type f -name '*.md' | sort)
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

task_blocked_by_overlap() {
  local task_index="$1"
  local other_index

  for ((other_index = 0; other_index < ${#TASK_IDS[@]}; other_index++)); do
    [[ $other_index -eq $task_index ]] && continue
    if [[ "${TASK_EFFECTIVE_STATUSES[$other_index]}" != 'active' && "${TASK_EFFECTIVE_STATUSES[$other_index]}" != 'review' ]]; then
      continue
    fi
    if track_globs_overlap_serialized "${TASK_FILES_SERIALIZED[$task_index]}" "${TASK_FILES_SERIALIZED[$other_index]}"; then
      return 0
    fi
  done

  return 1
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
  local i best_rank=99 has_open=0 rank
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
  printf '%02d\t%06d\t%s\n' "$best_rank" "$project_id" "$project_id"
}


markdown_link_text() {
  local text="$1"
  text=${text//[/\[}
  text=${text//]/\]}
  printf '%s' "$text"
}
render_task_row() {
  local index="$1"
  local depends='—'
  local status_display task_link

  if [[ -n "${TASK_DEPENDS[$index]}" ]]; then
    depends="$(printf '%s' "${TASK_DEPENDS[$index]}" | tr "$TRACK_ITEM_SEP" ',' | sed 's/,/, /g')"
  fi

  task_link="[$(markdown_link_text "${TASK_TITLES[$index]}")](.track/tasks/${TASK_PATHS[$index]})"
  status_display="${TASK_EFFECTIVE_STATUSES[$index]}"
  if [[ -n "${TASK_PRS[$index]}" ]]; then
    status_display+=" · [PR](${TASK_PRS[$index]})"
  fi

  printf '| [%s](.track/tasks/%s) | %s | %s | %s | %s | %s |\n' \
    "${TASK_IDS[$index]}" \
    "${TASK_PATHS[$index]}" \
    "$task_link" \
    "${TASK_MODES[$index]}" \
    "${TASK_PRIORITIES[$index]}" \
    "$depends" \
    "$status_display"
}

render_cross_project_dependencies() {
  local seen='' i dep dep_index source_project target_project edge
  local IFS="$TRACK_ITEM_SEP"
  local deps=()

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
      fi
    done
  done
  printf '```\n\n'
}

render_immediate_starts() {
  local i found=0
  printf '## Immediate Starts\n\n'
  for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
    if task_is_immediate_start "$i"; then
      printf -- '- [ ] [%s](.track/tasks/%s) — `%s` · `%s`\n' \
        "$(markdown_link_text "${TASK_TITLES[$i]}")" \
        "${TASK_PATHS[$i]}" \
        "${TASK_PROJECT_IDS[$i]}" \
        "${TASK_PRIORITIES[$i]}"
      found=1
    fi
  done
  if [[ $found -eq 0 ]]; then
    printf -- '- No ready tasks.\n'
  fi
  printf '\n'
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

generate_todo() {
  local output_file project_sort_lines project_sort_line project_id project_index
  local task_sort_lines task_sort_line task_index project_excerpt i

  output_file="$OUTPUT_PATH"
  mkdir -p "$(dirname "$output_file")"

  {
    printf '# Work Items\n\n'
    printf 'Generated from `%s` `.track/` state plus live open PR metadata. Updated %s.\n\n' \
      "$([[ "$MODE" == 'local' ]] && printf 'local working tree' || printf "origin/$DEFAULT_BRANCH")" \
      "$(date -u +'%Y-%m-%d %H:%M UTC')"
    printf '%s projects derived from `.track/` state.\n\n' "${#PROJECT_IDS[@]}"

    project_sort_lines=''
    for project_id in "${PROJECT_IDS[@]-}"; do
      [[ -z "$project_id" ]] && continue
      project_sort_lines+="$(project_sort_key "$project_id")"$'\n'
    done

    while IFS= read -r project_sort_line; do
      [[ -z "$project_sort_line" ]] && continue
      project_id="${project_sort_line##*$'\t'}"
      project_index="$(find_project_index_by_id "$project_id")"

      printf -- '---\n\n'
      printf '## Project %s: %s\n\n' "$project_id" "${PROJECT_TITLES[$project_index]}"

      project_excerpt="${PROJECT_EXCERPTS[$project_index]}"
      if [[ -n "$project_excerpt" ]]; then
        printf '%s\n\n' "$project_excerpt"
      fi

      printf '**Brief:** [`.track/projects/%s`](.track/projects/%s)\n\n' \
        "$(basename "${PROJECT_FILES[$project_index]}")" \
        "$(basename "${PROJECT_FILES[$project_index]}")"

      printf '| ID | Task | Mode | Priority | Depends | Status |\n'
      printf '| --- | --- | --- | --- | --- | --- |\n'

      task_sort_lines=''
      for ((i = 0; i < ${#TASK_IDS[@]}; i++)); do
        [[ "${TASK_PROJECT_IDS[$i]}" != "$project_id" ]] && continue
        task_sort_lines+="$(task_sort_key "$i")"$'\t'"$i"$'\n'
      done

      while IFS= read -r task_sort_line; do
        [[ -z "$task_sort_line" ]] && continue
        task_index="${task_sort_line##*$'\t'}"
        render_task_row "$task_index"
      done < <(printf '%s' "$task_sort_lines" | sort)

      printf '\n'
    done < <(printf '%s' "$project_sort_lines" | sort)

    render_cross_project_dependencies
    render_immediate_starts
    render_warnings
  } > "$output_file"
}

main() {
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
        OUTPUT_PATH="$1"
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

  load_source_tree

  if [[ ! -d "$SOURCE_ROOT/.track/tasks" || ! -d "$SOURCE_ROOT/.track/projects" ]]; then
    printf 'track: .track/ not found — run /track:init to set up this repo\n' >&2
    exit 1
  fi

  load_projects
  load_open_prs
  load_tasks
  generate_todo
  printf 'Wrote %s\n' "$OUTPUT_PATH"
}

main "$@"
