#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../skills/setup-track/assets/hooks/post-commit"
PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected: %s\n' "$expected"
    printf '    got:      %s\n' "$actual"
  fi
}

assert_contains() {
  local name="$1" pattern="$2" text="$3"
  if printf '%s' "$text" | grep -qF -- "$pattern"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing:  %s\n' "$pattern"
    printf '    in:       %s\n' "$text"
  fi
}

assert_not_contains() {
  local name="$1" pattern="$2" text="$3"
  if printf '%s' "$text" | grep -qF -- "$pattern"; then
    fail "$name"
    printf '    unexpected: %s\n' "$pattern"
  else
    pass "$name"
  fi
}

# Create a temporary git repo with a committed file; returns repo path
setup_git_repo() {
  local tmp
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "test@track.local"
  git -C "$tmp" config user.name "Track Test"
  mkdir -p "$tmp/.track/events"
  printf '%s\n' "$tmp"
}

# Make a commit with the given conventional commit message and files
make_commit() {
  local repo="$1"
  local msg="$2"
  shift 2
  local files=("$@")

  for f in "${files[@]}"; do
    local dir
    dir="$(dirname "$repo/$f")"
    mkdir -p "$dir"
    printf 'content\n' > "$repo/$f"
    git -C "$repo" add "$repo/$f"
  done
  git -C "$repo" commit -q -m "$msg"
}

printf 'Running post-commit event contract tests...\n\n'

# ── Hook is executable ──────────────────────────────────────────────────────

printf '── Hook file ──\n'

if [[ -x "$HOOK" ]]; then
  pass 'post-commit hook is executable'
else
  fail 'post-commit hook is executable'
fi

if [[ "$(head -1 "$HOOK")" == '#!/usr/bin/env bash' ]]; then
  pass 'post-commit hook has bash shebang'
else
  fail 'post-commit hook has bash shebang'
fi

# ── Fallback: fires only when .track/events/ exists ─────────────────────────

printf '\n── Directory guard ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "feat: initial commit" "src/main.sh"
# Remove .track/events/ — hook should not create the log
rm -rf "$repo/.track"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true
if [[ ! -f "$repo/.track/events/log.jsonl" ]]; then
  pass 'no log written when .track/events/ absent'
else
  fail 'no log written when .track/events/ absent'
fi
rm -rf "$repo"

# ── Fallback: valid JSON event for conventional commit ───────────────────────

printf '\n── JSON output ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "feat(auth): add JWT validation" "src/auth.sh" "tests/auth.sh"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true

LOG="$repo/.track/events/log.jsonl"

if [[ -f "$LOG" ]]; then
  pass 'log.jsonl created'
else
  fail 'log.jsonl created'
  rm -rf "$repo"
  printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi

LINE="$(tail -1 "$LOG")"

# Required envelope fields
assert_contains 'type is track.commit'           '"type":"track.commit"'         "$LINE"
assert_contains 'version is 1'                   '"version":"1"'                 "$LINE"
assert_contains 'timestamp present'              '"timestamp":"'                 "$LINE"
assert_contains 'repo present'                   '"repo":"'                      "$LINE"
assert_contains 'branch present'                 '"branch":"'                    "$LINE"
assert_contains 'commit_sha present'             '"commit_sha":"'                "$LINE"
assert_contains 'changed_files array present'    '"changed_files":['             "$LINE"
assert_contains 'conventional_commit present'    '"conventional_commit":{'       "$LINE"

# conventional_commit fields
assert_contains 'cc.type is feat'                '"type":"feat"'                 "$LINE"
assert_contains 'cc.scope is auth'               '"scope":"auth"'                "$LINE"
assert_contains 'cc.subject correct'             '"subject":"add JWT validation"' "$LINE"
assert_contains 'cc.breaking is false'           '"breaking":false'              "$LINE"

# Should NOT contain attribution fields (those are added by future consumers)
assert_not_contains 'no task_id field'           '"task_id"'                     "$LINE"
assert_not_contains 'no attribution_source'      '"attribution_source"'          "$LINE"

# Timestamp format: roughly ISO-8601
if printf '%s' "$LINE" | grep -Eq '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"'; then
  pass 'timestamp is RFC3339 UTC format'
else
  fail 'timestamp is RFC3339 UTC format'
  printf '    line: %s\n' "$LINE"
fi

# commit_sha is 40-char hex
SHA="$(printf '%s' "$LINE" | grep -oE '"commit_sha":"[a-f0-9]+"' | cut -d'"' -f4)"
if [[ ${#SHA} -eq 40 ]]; then
  pass 'commit_sha is 40-char hex'
else
  fail 'commit_sha is 40-char hex'
  printf '    got: %s (length %d)\n' "$SHA" "${#SHA}"
fi

# changed_files contains committed files
assert_contains 'changed_files includes src/auth.sh'   '"src/auth.sh"'   "$LINE"
assert_contains 'changed_files includes tests/auth.sh' '"tests/auth.sh"' "$LINE"

rm -rf "$repo"

# ── Fallback: breaking change ────────────────────────────────────────────────

printf '\n── Breaking change ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "feat(api)!: remove legacy endpoint" "src/api.sh"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true

LINE="$(tail -1 "$repo/.track/events/log.jsonl")"
assert_contains 'breaking is true'  '"breaking":true'  "$LINE"
assert_contains 'scope is api'      '"scope":"api"'    "$LINE"
rm -rf "$repo"

# ── Fallback: no scope (null) ────────────────────────────────────────────────

printf '\n── No scope (null) ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "fix: correct off-by-one error" "src/util.sh"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true

LINE="$(tail -1 "$repo/.track/events/log.jsonl")"
assert_contains 'scope is null when absent' '"scope":null' "$LINE"
assert_contains 'type is fix'               '"type":"fix"' "$LINE"
rm -rf "$repo"

# ── Fallback: non-conventional commit skipped ────────────────────────────────

printf '\n── Non-conventional commit ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "Update the readme file" "README.md"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true

LOG="$repo/.track/events/log.jsonl"
if [[ ! -f "$LOG" ]] || [[ ! -s "$LOG" ]]; then
  pass 'non-conventional commit produces no log entry'
else
  fail 'non-conventional commit produces no log entry'
  printf '    log contents: %s\n' "$(cat "$LOG")"
fi
rm -rf "$repo"

# ── Hook always exits 0 ──────────────────────────────────────────────────────

printf '\n── Hook exit code ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "feat: exit code test" "src/x.sh"
exit_code=0
(cd "$repo" && bash "$HOOK" 2>/dev/null) || exit_code=$?
assert_eq 'hook exits 0 (never blocks commit)' "0" "$exit_code"
rm -rf "$repo"

# ── JSON line is valid (no embedded newlines, single object) ─────────────────

printf '\n── JSON line format ──\n'

repo="$(setup_git_repo)"
make_commit "$repo" "docs(readme): update install instructions" "README.md"
(cd "$repo" && bash "$HOOK" 2>/dev/null) || true

LOG="$repo/.track/events/log.jsonl"
LINE_COUNT="$(wc -l < "$LOG" | tr -d ' ')"
assert_eq 'exactly one line appended per commit' "1" "$LINE_COUNT"

LINE="$(cat "$LOG")"
FIRST_CHAR="${LINE:0:1}"
LAST_CHAR="${LINE: -1}"
assert_eq 'line starts with {' '{' "$FIRST_CHAR"
assert_eq 'line ends with }'   '}' "$LAST_CHAR"
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
