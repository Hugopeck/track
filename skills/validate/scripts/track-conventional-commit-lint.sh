#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-}"
PATTERN='^(feat|fix|docs|refactor|test|ci|chore)(\([^) \t][^)]*\))?!?: .+'
EXIT_CODE=0
INVALID_COUNT=0

print_info() {
  printf '%s\n' "$1"
}

print_error() {
  printf 'Error: %s\n' "$1" >&2
  EXIT_CODE=1
}

if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
  print_info 'No commit range set; skipping conventional commit lint.'
  exit 0
fi

if ! git rev-parse --verify "$BASE_SHA^{commit}" >/dev/null 2>&1; then
  print_error "base commit '$BASE_SHA' is not available locally"
  exit "$EXIT_CODE"
fi

if ! git rev-parse --verify "$HEAD_SHA^{commit}" >/dev/null 2>&1; then
  print_error "head commit '$HEAD_SHA' is not available locally"
  exit "$EXIT_CODE"
fi

while IFS=$'\037' read -r commit_sha subject || [[ -n "$commit_sha$subject" ]]; do
  [[ -z "$commit_sha" ]] && continue

  case "$subject" in
    Merge\ *|Revert\ *|fixup\!\ *|squash\!\ *)
      continue
      ;;
  esac

  if [[ ! "$subject" =~ $PATTERN ]]; then
    print_error "$commit_sha $subject"
    INVALID_COUNT=$((INVALID_COUNT + 1))
  fi
done < <(git log --format='%H%x1f%s' "$BASE_SHA..$HEAD_SHA")

if [[ $INVALID_COUNT -gt 0 ]]; then
  print_error 'commit messages must follow conventional commits: type(scope): description'
  exit "$EXIT_CODE"
fi

print_info 'Conventional commit lint passed.'
