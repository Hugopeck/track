#!/usr/bin/env bash
set -euo pipefail

# Validates PR branch name and title against Track conventions.
# Runs in CI on pull_request events only.
#
# Checks:
#   1. task/* branches must match the pattern task/{project}.{task}-{slug}
#   2. The task ID in the branch must correspond to an existing task file
#   3. The slug in the branch must match the task file slug
#   4. The PR title must start with the task ID in parentheses or brackets

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASK_DIR="$ROOT_DIR/.track/tasks"
EXIT_CODE=0

HEAD_REF="${GITHUB_HEAD_REF:-}"
PR_TITLE="${PR_TITLE:-}"

print_error() {
  printf 'Error: %s\n' "$1" >&2
  EXIT_CODE=1
}

print_warning() {
  printf 'Warning: %s\n' "$1" >&2
}

print_info() {
  printf '%s\n' "$1"
}

# Non-task branches are allowed — just skip all checks
if [[ -z "$HEAD_REF" ]]; then
  print_info 'No HEAD_REF set; skipping PR lint (not a pull request context).'
  exit 0
fi

if [[ ! "$HEAD_REF" =~ ^task/ ]]; then
  print_info "Branch '$HEAD_REF' is not a task branch; skipping Track PR lint."
  exit 0
fi

# --- Task branch validation ---

if [[ ! "$HEAD_REF" =~ ^task/([0-9]+\.[0-9]+)-([a-z0-9-]+)$ ]]; then
  print_error "Branch '$HEAD_REF' starts with task/ but doesn't match required pattern: task/{project}.{task}-{slug}"
  print_info "  Expected: task/4.1-some-slug"
  print_info "  Got:      $HEAD_REF"
  exit "$EXIT_CODE"
fi

BRANCH_TASK_ID="${BASH_REMATCH[1]}"
BRANCH_SLUG="${BASH_REMATCH[2]}"

print_info "Branch task ID: $BRANCH_TASK_ID"
print_info "Branch slug: $BRANCH_SLUG"

# Find the matching task file
TASK_FILE="$(find "$TASK_DIR" -maxdepth 1 -type f -name "${BRANCH_TASK_ID}-*.md" | head -n 1)"

if [[ -z "$TASK_FILE" ]]; then
  print_error "No task file found for ID '$BRANCH_TASK_ID' in .track/tasks/"
  exit "$EXIT_CODE"
fi

TASK_BASENAME="$(basename "$TASK_FILE" .md)"
EXPECTED_SLUG="${TASK_BASENAME#"${BRANCH_TASK_ID}-"}"

if [[ "$BRANCH_SLUG" != "$EXPECTED_SLUG" ]]; then
  print_warning "Branch slug '$BRANCH_SLUG' doesn't match task file slug '$EXPECTED_SLUG' (task file: $TASK_BASENAME.md)"
fi

# --- PR title validation ---

if [[ -z "$PR_TITLE" ]]; then
  print_warning 'PR_TITLE not set; skipping title check.'
  exit "$EXIT_CODE"
fi

# Accept title formats:
#   [4.1] Some title
#   (4.1) Some title
#   feat(track): [4.1] Some title
#   fix(track): (4.1) Some title
# The task ID just needs to appear somewhere in brackets or parens
if [[ ! "$PR_TITLE" =~ [\[\(]${BRANCH_TASK_ID}[\]\)] ]]; then
  print_error "PR title must include task ID '${BRANCH_TASK_ID}' in brackets or parentheses"
  print_info "  Expected: '[$BRANCH_TASK_ID] ...' or '($BRANCH_TASK_ID) ...' somewhere in the title"
  print_info "  Got:      '$PR_TITLE'"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  print_info 'Track PR lint passed.'
fi

exit "$EXIT_CODE"
