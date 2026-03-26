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
