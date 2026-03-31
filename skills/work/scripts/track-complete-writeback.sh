#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${BASE_REF:-main}"
PR_NUMBER="${PR_NUMBER:-}"
PR_URL="${PR_URL:-}"
GIT_USER_NAME="${GIT_USER_NAME:-github-actions[bot]}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
WRITEBACK_BRANCH="${WRITEBACK_BRANCH:-track/complete-${PR_NUMBER:-writeback}}"
WRITEBACK_TITLE="${WRITEBACK_TITLE:-fix(track): complete merged task}"

print_info() {
  printf '%s\n' "$1"
}

print_error() {
  printf 'Error: %s\n' "$1" >&2
}

if git diff --quiet; then
  print_info 'No completion writeback needed.'
  exit 0
fi

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

git add .track/tasks

if git diff --cached --quiet; then
  print_info 'No task metadata changes to write back.'
  exit 0
fi

git commit -m "$WRITEBACK_TITLE"

original_head="$(git rev-parse HEAD)"

if git fetch origin "$BASE_REF" && git rebase "origin/$BASE_REF"; then
  if git push origin "HEAD:$BASE_REF"; then
    print_info "Pushed completion writeback directly to $BASE_REF."
    exit 0
  fi
else
  git rebase --abort >/dev/null 2>&1 || true
  git reset --hard "$original_head" >/dev/null 2>&1 || true
fi

print_info "Direct push to $BASE_REF failed; opening writeback PR."

if ! command -v gh >/dev/null 2>&1; then
  print_error 'gh CLI is required when direct push is blocked.'
  exit 1
fi

git push --force-with-lease origin "HEAD:refs/heads/$WRITEBACK_BRANCH"

existing_pr="$(gh pr list --base "$BASE_REF" --head "$WRITEBACK_BRANCH" --state open --json number --jq '.[0].number')"
if [[ -n "$existing_pr" && "$existing_pr" != 'null' ]]; then
  print_info "Updated existing completion writeback PR #$existing_pr."
  exit 0
fi

writeback_body="Automated task-completion writeback for merged PR"
if [[ -n "$PR_NUMBER" ]]; then
  writeback_body+=" #$PR_NUMBER"
fi
writeback_body+="."

if [[ -n "$PR_URL" ]]; then
  writeback_body+=$'\n\n'
  writeback_body+="Source PR: $PR_URL"
fi

gh pr create \
  --base "$BASE_REF" \
  --head "$WRITEBACK_BRANCH" \
  --title "$WRITEBACK_TITLE" \
  --body "$writeback_body" >/dev/null

print_info "Opened completion writeback PR from $WRITEBACK_BRANCH."
