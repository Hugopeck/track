#!/usr/bin/env bash

TRACK_ITEM_SEP=$'\034'

track_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

track_trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

track_strip_quotes() {
  local value
  value="$(track_trim "${1-}")"

  if [[ ${#value} -ge 2 ]]; then
    if [[ ${value:0:1} == '"' && ${value: -1} == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ ${value:0:1} == "'" && ${value: -1} == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi

  printf '%s' "$value"
}

track_reset_task_parse() {
  TRACK_parse_error=""
  TRACK_frontmatter_closed=0
  TRACK_present_keys='|'
  TRACK_id=''
  TRACK_title=''
  TRACK_status=''
  TRACK_mode=''
  TRACK_priority=''
  TRACK_project_id=''
  TRACK_created=''
  TRACK_updated=''
  TRACK_pr=''
  TRACK_cancelled_reason=''
  TRACK_depends_on=()
  TRACK_files=()
}

track_mark_present() {
  TRACK_present_keys+="$1|"
}

track_field_present() {
  [[ "$TRACK_present_keys" == *"|$1|"* ]]
}

track_assign_scalar() {
  local key="$1"
  local value="$2"

  case "$key" in
    id) TRACK_id="$value" ;;
    title) TRACK_title="$value" ;;
    status) TRACK_status="$value" ;;
    mode) TRACK_mode="$value" ;;
    priority) TRACK_priority="$value" ;;
    project_id|project) TRACK_project_id="$value" ;;
    created) TRACK_created="$value" ;;
    updated) TRACK_updated="$value" ;;
    pr) TRACK_pr="$value" ;;
    cancelled_reason) TRACK_cancelled_reason="$value" ;;
  esac
}

track_append_array_item() {
  local list_name="$1"
  local value="$2"

  case "$list_name" in
    depends_on) TRACK_depends_on+=("$value") ;;
    files) TRACK_files+=("$value") ;;
  esac
}

track_parse_inline_array() {
  local key="$1"
  local raw="$2"
  local inner item

  inner="$(track_trim "$raw")"
  inner="${inner#[}"
  inner="${inner%]}"

  if [[ -z "$inner" ]]; then
    return 0
  fi

  while IFS= read -r item; do
    item="$(track_strip_quotes "$item")"
    [[ -z "$item" ]] && continue
    track_append_array_item "$key" "$item"
  done < <(printf '%s\n' "$inner" | tr ',' '\n')
}

track_parse_task_file() {
  local file="$1"
  local line line_no=0 in_frontmatter=0 current_list='' key value

  track_reset_task_parse

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line_no=$((line_no + 1))

    if [[ $line_no -eq 1 ]]; then
      if [[ "$line" != '---' ]]; then
        TRACK_parse_error="file must start with '---' on line 1 (YAML frontmatter opening). Ensure the first line is exactly '---'"
        return 1
      fi
      in_frontmatter=1
      continue
    fi

    if [[ $in_frontmatter -eq 1 ]]; then
      if [[ "$line" == '---' ]]; then
        TRACK_frontmatter_closed=1
        return 0
      fi

      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        track_mark_present "$key"
        current_list=''

        case "$key" in
          depends_on|files)
            value="$(track_trim "$value")"
            if [[ -z "$value" ]]; then
              current_list="$key"
            elif [[ "$value" != '[]' ]]; then
              track_parse_inline_array "$key" "$value"
            fi
            ;;
          *)
            track_assign_scalar "$key" "$(track_strip_quotes "$value")"
            ;;
        esac

        continue
      fi

      if [[ -n "$current_list" && "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
        track_append_array_item "$current_list" "$(track_strip_quotes "${BASH_REMATCH[1]}")"
      fi
    fi
  done < "$file"

  TRACK_parse_error="frontmatter never closed. Add a '---' line after the last frontmatter field"
  return 1
}

track_serialize_items() {
  local output='' item
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    if [[ -n "$output" ]]; then
      output+="$TRACK_ITEM_SEP"
    fi
    output+="$item"
  done
  printf '%s' "$output"
}

track_priority_rank() {
  case "$1" in
    urgent) printf '0' ;;
    high) printf '1' ;;
    medium) printf '2' ;;
    low) printf '3' ;;
    *) printf '99' ;;
  esac
}

track_status_rank() {
  case "$1" in
    active) printf '0' ;;
    review) printf '1' ;;
    todo) printf '2' ;;
    done) printf '3' ;;
    cancelled) printf '4' ;;
    *) printf '99' ;;
  esac
}

track_is_terminal_status() {
  [[ "$1" == 'done' || "$1" == 'cancelled' ]]
}

track_is_dotted_id() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}

track_is_legacy_id() {
  [[ "$1" =~ ^[0-9]{3,}$ ]]
}

track_reset_task_resolution() {
  TRACK_RESOLVED_TASK_IDS=''
  TRACK_RESOLVED_TASK_COUNT=0
  TRACK_RESOLUTION_MODE=''
  TRACK_RESOLVED_TASK_ID=''
  TRACK_RESOLVED_SOURCE=''
  TRACK_RESOLVER_ERROR=''
  TRACK_PARSED_TASK_IDS=''
  TRACK_PARSED_TASK_ID=''
  TRACK_PARSE_TASK_ERROR=''
}

track_first_id_from_set() {
  local id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    printf '%s' "$id"
    return 0
  done <<< "${1-}"
  return 1
}

track_set_contains() {
  local set_data="${1-}"
  local target="$2"
  local id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    [[ "$id" == "$target" ]] && return 0
  done <<< "$set_data"
  return 1
}

track_append_unique_id() {
  local var_name="$1"
  local id="$2"
  local current="${!var_name-}"

  [[ -z "$id" ]] && return 1
  if track_set_contains "$current" "$id"; then
    return 1
  fi

  if [[ -n "$current" ]]; then
    printf -v "$var_name" '%s\n%s' "$current" "$id"
  else
    printf -v "$var_name" '%s' "$id"
  fi

  return 0
}

track_set_count() {
  local set_data="${1-}"
  local count=0 id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    count=$((count + 1))
  done <<< "$set_data"
  printf '%s' "$count"
}

track_join_ids_csv() {
  local set_data="${1-}"
  local joined='' id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    if [[ -n "$joined" ]]; then
      joined+=', '
    fi
    joined+="$id"
  done <<< "$set_data"
  printf '%s' "$joined"
}

track_set_is_subset() {
  local subset="${1-}"
  local superset="${2-}"
  local id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    if ! track_set_contains "$superset" "$id"; then
      return 1
    fi
  done <<< "$subset"
  return 0
}

track_sets_equal() {
  track_set_is_subset "$1" "$2" && track_set_is_subset "$2" "$1"
}

track_set_first_outside() {
  local subset="${1-}"
  local superset="${2-}"
  local id
  while IFS= read -r id || [[ -n "$id" ]]; do
    [[ -z "$id" ]] && continue
    if ! track_set_contains "$superset" "$id"; then
      printf '%s' "$id"
      return 0
    fi
  done <<< "$subset"
  return 1
}

track_finalize_parsed_task_ids() {
  TRACK_PARSED_TASK_ID=''
  if [[ -n "$TRACK_PARSED_TASK_IDS" ]]; then
    TRACK_PARSED_TASK_ID="$(track_first_id_from_set "$TRACK_PARSED_TASK_IDS")"
  fi
}

track_task_ids_from_pr_body() {
  local body="${1-}"
  local line raw_id found=''
  local had_nocasematch=0

  TRACK_PARSED_TASK_IDS=''
  TRACK_PARSED_TASK_ID=''
  TRACK_PARSE_TASK_ERROR=''

  shopt -q nocasematch && had_nocasematch=1
  shopt -s nocasematch

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*track-task:[[:space:]]*(.+)[[:space:]]*$ ]]; then
      raw_id="$(track_strip_quotes "${BASH_REMATCH[1]}")"
      raw_id="$(track_trim "$raw_id")"

      if ! track_is_dotted_id "$raw_id"; then
        TRACK_PARSE_TASK_ERROR="malformed Track-Task value '$raw_id' in PR body"
        [[ $had_nocasematch -eq 1 ]] || shopt -u nocasematch
        return 3
      fi

      track_append_unique_id found "$raw_id" >/dev/null || true
    fi
  done <<< "$body"

  [[ $had_nocasematch -eq 1 ]] || shopt -u nocasematch

  if [[ -z "$found" ]]; then
    return 1
  fi

  TRACK_PARSED_TASK_IDS="$found"
  track_finalize_parsed_task_ids
  return 0
}

track_task_ids_from_pr_labels() {
  local labels="${1-}"
  local label raw_id found=''
  local had_nocasematch=0

  TRACK_PARSED_TASK_IDS=''
  TRACK_PARSED_TASK_ID=''
  TRACK_PARSE_TASK_ERROR=''

  shopt -q nocasematch && had_nocasematch=1
  shopt -s nocasematch

  while IFS= read -r label || [[ -n "$label" ]]; do
    label="$(track_strip_quotes "$label")"
    label="$(track_trim "$label")"
    [[ -z "$label" ]] && continue

    if [[ "$label" =~ ^track:(.+)$ ]]; then
      raw_id="$(track_trim "${BASH_REMATCH[1]}")"

      if ! track_is_dotted_id "$raw_id"; then
        TRACK_PARSE_TASK_ERROR="malformed track label '$label'"
        [[ $had_nocasematch -eq 1 ]] || shopt -u nocasematch
        return 3
      fi

      track_append_unique_id found "$raw_id" >/dev/null || true
    fi
  done < <(printf '%s\n' "$labels" | tr ',|' '\n')

  [[ $had_nocasematch -eq 1 ]] || shopt -u nocasematch

  if [[ -z "$found" ]]; then
    return 1
  fi

  TRACK_PARSED_TASK_IDS="$found"
  track_finalize_parsed_task_ids
  return 0
}

track_task_ids_from_pr_title() {
  local title="${1-}"
  local remaining token inner found=''

  TRACK_PARSED_TASK_IDS=''
  TRACK_PARSED_TASK_ID=''
  TRACK_PARSE_TASK_ERROR=''
  [[ -z "$title" ]] && return 1

  remaining="$title"
  while [[ "$remaining" =~ (\[[^][]+\]|\([^()]+\)) ]]; do
    token="${BASH_REMATCH[1]}"
    remaining="${remaining#*"$token"}"
    inner="${token:1:${#token}-2}"
    inner="$(track_trim "$inner")"

    if track_is_dotted_id "$inner"; then
      track_append_unique_id found "$inner" >/dev/null || true
      continue
    fi

    if [[ "$inner" =~ ^[0-9][0-9.]*$ && "$inner" != *','* ]]; then
      TRACK_PARSE_TASK_ERROR="malformed task ID marker '$token' in PR title"
      return 3
    fi
  done

  if [[ -z "$found" ]]; then
    return 1
  fi

  TRACK_PARSED_TASK_IDS="$found"
  track_finalize_parsed_task_ids
  return 0
}

track_task_ids_from_branch() {
  local branch_name="${1-}"

  TRACK_PARSED_TASK_IDS=''
  TRACK_PARSED_TASK_ID=''
  TRACK_PARSE_TASK_ERROR=''
  [[ -z "$branch_name" ]] && return 1

  if [[ "$branch_name" =~ ^task/([0-9]+\.[0-9]+)-[a-z0-9-]+$ ]]; then
    TRACK_PARSED_TASK_IDS="${BASH_REMATCH[1]}"
    track_finalize_parsed_task_ids
    return 0
  fi

  if [[ "$branch_name" =~ ^task/ ]]; then
    TRACK_PARSE_TASK_ERROR="malformed task branch '$branch_name' (expected task/{id}-{slug})"
    return 3
  fi

  return 1
}

track_resolve_task_ids() {
  local pr_body="${1-}"
  local pr_labels="${2-}"
  local pr_title="${3-}"
  local branch_name="${4-}"
  local code
  local body_ids='' label_ids='' title_ids='' branch_ids=''
  local body_count=0 label_count=0 title_count=0 branch_count=0
  local resolved_ids='' resolved_source='' resolved_mode=''
  local outside_id

  track_reset_task_resolution

  track_task_ids_from_pr_body "$pr_body"
  code=$?
  case "$code" in
    0)
      body_ids="$TRACK_PARSED_TASK_IDS"
      body_count="$(track_set_count "$body_ids")"
      ;;
    1) ;;
    3) TRACK_RESOLVER_ERROR="$TRACK_PARSE_TASK_ERROR"; return 3 ;;
  esac

  track_task_ids_from_pr_labels "$pr_labels"
  code=$?
  case "$code" in
    0)
      label_ids="$TRACK_PARSED_TASK_IDS"
      label_count="$(track_set_count "$label_ids")"
      ;;
    1) ;;
    3) TRACK_RESOLVER_ERROR="$TRACK_PARSE_TASK_ERROR"; return 3 ;;
  esac

  track_task_ids_from_pr_title "$pr_title"
  code=$?
  case "$code" in
    0)
      title_ids="$TRACK_PARSED_TASK_IDS"
      title_count="$(track_set_count "$title_ids")"
      ;;
    1) ;;
    3) TRACK_RESOLVER_ERROR="$TRACK_PARSE_TASK_ERROR"; return 3 ;;
  esac

  track_task_ids_from_branch "$branch_name"
  code=$?
  case "$code" in
    0)
      branch_ids="$TRACK_PARSED_TASK_IDS"
      branch_count="$(track_set_count "$branch_ids")"
      ;;
    1) ;;
    3) TRACK_RESOLVER_ERROR="$TRACK_PARSE_TASK_ERROR"; return 3 ;;
  esac

  if [[ $body_count -ge 2 ]]; then
    resolved_ids="$body_ids"
    resolved_source='body'
    resolved_mode='batch'
  elif [[ $label_count -ge 2 ]]; then
    resolved_ids="$label_ids"
    resolved_source='labels'
    resolved_mode='batch'
  elif [[ $body_count -eq 1 ]]; then
    resolved_ids="$body_ids"
    resolved_source='body'
    resolved_mode='single'
  elif [[ $label_count -eq 1 ]]; then
    resolved_ids="$label_ids"
    resolved_source='labels'
    resolved_mode='single'
  elif [[ $title_count -eq 1 ]]; then
    resolved_ids="$title_ids"
    resolved_source='title'
    resolved_mode='single'
  elif [[ $title_count -gt 1 ]]; then
    TRACK_RESOLVER_ERROR='multiple task IDs in PR title require explicit batch declaration via repeated Track-Task lines or track labels'
    return 2
  elif [[ $branch_count -eq 1 ]]; then
    resolved_ids="$branch_ids"
    resolved_source='branch'
    resolved_mode='single'
  else
    TRACK_RESOLVER_ERROR='no task ID found in PR body, labels, title, or branch name'
    return 1
  fi

  if [[ -n "$body_ids" ]] && ! track_set_is_subset "$body_ids" "$resolved_ids"; then
    outside_id="$(track_set_first_outside "$body_ids" "$resolved_ids")"
    TRACK_RESOLVER_ERROR="PR body references task '$outside_id' outside canonical set '$(track_join_ids_csv "$resolved_ids")'"
    return 2
  fi
  if [[ -n "$label_ids" ]] && ! track_set_is_subset "$label_ids" "$resolved_ids"; then
    outside_id="$(track_set_first_outside "$label_ids" "$resolved_ids")"
    TRACK_RESOLVER_ERROR="PR labels reference task '$outside_id' outside canonical set '$(track_join_ids_csv "$resolved_ids")'"
    return 2
  fi
  if [[ -n "$title_ids" ]] && ! track_set_is_subset "$title_ids" "$resolved_ids"; then
    outside_id="$(track_set_first_outside "$title_ids" "$resolved_ids")"
    TRACK_RESOLVER_ERROR="PR title references task '$outside_id' outside canonical set '$(track_join_ids_csv "$resolved_ids")'"
    return 2
  fi
  if [[ -n "$branch_ids" ]] && ! track_set_is_subset "$branch_ids" "$resolved_ids"; then
    outside_id="$(track_set_first_outside "$branch_ids" "$resolved_ids")"
    TRACK_RESOLVER_ERROR="PR branch references task '$outside_id' outside canonical set '$(track_join_ids_csv "$resolved_ids")'"
    return 2
  fi

  TRACK_RESOLVED_TASK_IDS="$resolved_ids"
  TRACK_RESOLVED_TASK_COUNT="$(track_set_count "$resolved_ids")"
  TRACK_RESOLUTION_MODE="$resolved_mode"
  TRACK_RESOLVED_TASK_ID="$(track_first_id_from_set "$resolved_ids")"
  TRACK_RESOLVED_SOURCE="$resolved_source"
  return 0
}

track_task_id_from_pr_body() { track_task_ids_from_pr_body "$@"; }
track_task_id_from_pr_labels() { track_task_ids_from_pr_labels "$@"; }
track_task_id_from_pr_title() { track_task_ids_from_pr_title "$@"; }
track_task_id_from_branch() { track_task_ids_from_branch "$@"; }
track_resolve_task_id() { track_resolve_task_ids "$@"; }

track_project_id_from_brief() {
  local file basename
  file="$1"
  basename="$(basename "$file")"
  [[ "$basename" =~ ^([0-9]+)-[a-z0-9-]+\.md$ ]] || return 1
  printf '%s' "${BASH_REMATCH[1]}"
}

track_project_title_from_brief() {
  awk '/^# / { sub(/^# /, ""); print; exit }' "$1"
}

track_project_goal_excerpt() {
  awk '
    /^## Goal$/ { in_goal = 1; next }
    /^## / { if (in_goal) exit }
    in_goal {
      if ($0 ~ /^[[:space:]]*$/) {
        if (excerpt != "") exit
        next
      }
      excerpt = excerpt (excerpt ? " " : "") $0
    }
    END { print excerpt }
  ' "$1"
}

track_glob_base() {
  local glob="$1"
  glob="${glob%%\**}"
  glob="${glob%/}"
  printf '%s' "$glob"
}

track_globs_overlap_serialized() {
  local serialized_a="$1"
  local serialized_b="$2"
  local IFS="$TRACK_ITEM_SEP"
  local a_items=() b_items=() a b base_a base_b

  read -r -a a_items <<< "$serialized_a"
  read -r -a b_items <<< "$serialized_b"

  if [[ ${#a_items[@]} -eq 0 || ${#b_items[@]} -eq 0 ]]; then
    return 1
  fi

  for a in "${a_items[@]}"; do
    for b in "${b_items[@]}"; do
      base_a="$(track_glob_base "$a")"
      base_b="$(track_glob_base "$b")"

      if [[ -z "$base_a" || -z "$base_b" ]]; then
        return 0
      fi

      case "$base_a" in
        "$base_b"|"$base_b"/*) return 0 ;;
      esac
      case "$base_b" in
        "$base_a"|"$base_a"/*) return 0 ;;
      esac
    done
  done

  return 1
}
