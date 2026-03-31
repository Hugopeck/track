#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_FILE="$SCRIPT_DIR/../skills/validate/scripts/track-conventional-commit-lint.sh"
WORKFLOW_FILE="$SCRIPT_DIR/../skills/init/assets/workflows/conventional-commit-lint.yml"
MANIFEST_FILE="$SCRIPT_DIR/../skills/init/assets/install-manifest.json"
PASS=0
FAIL=0

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

run_capture() {
  STDOUT_FILE="$(mktemp)"
  STDERR_FILE="$(mktemp)"
  RUN_EXIT=0
  "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || RUN_EXIT=$?
}

cleanup_capture() {
  rm -f "$STDOUT_FILE" "$STDERR_FILE"
}

assert_code() {
  local name="$1"
  local expected="$2"
  if [[ $RUN_EXIT -eq $expected ]]; then
    pass "$name"
  else
    fail "$name"
    printf '    expected=%s got=%s\n' "$expected" "$RUN_EXIT"
  fi
}

assert_stdout_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDOUT_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stdout pattern: %s\n' "$pattern"
  fi
}

assert_stderr_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$STDERR_FILE"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing stderr pattern: %s\n' "$pattern"
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCRIPT_FILE" "$tmp/.track/scripts/"
  (
    cd "$tmp"
    git init -q >/dev/null 2>&1
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    printf 'base\n' > file.txt
    git add file.txt
    git commit -q -m 'chore: base fixture'
  )
  printf '%s' "$tmp"
}

printf 'Running conventional commit lint tests...\n\n'

if [[ -f "$SCRIPT_FILE" ]]; then
  pass 'conventional commit lint script exists'
else
  fail 'conventional commit lint script exists'
fi

if grep -Fq -- '.track/scripts/track-conventional-commit-lint.sh' "$WORKFLOW_FILE"; then
  pass 'workflow runs conventional commit lint script'
else
  fail 'workflow runs conventional commit lint script'
fi

if grep -Fq -- 'skills/validate/scripts/track-conventional-commit-lint.sh' "$MANIFEST_FILE"; then
  pass 'manifest installs conventional commit lint script'
else
  fail 'manifest installs conventional commit lint script'
fi

if grep -Fq -- 'skills/init/assets/workflows/conventional-commit-lint.yml' "$MANIFEST_FILE"; then
  pass 'manifest installs conventional commit lint workflow'
else
  fail 'manifest installs conventional commit lint workflow'
fi

repo="$(setup_repo)"
orig_dir="$(pwd)"
cd "$repo"
base_sha="$(git rev-parse HEAD)"
printf 'valid\n' >> file.txt
git add file.txt
git commit -q -m 'feat(api): add endpoint'
printf 'valid again\n' >> file.txt
git add file.txt
git commit -q -m 'fix: tighten parsing'
head_sha="$(git rev-parse HEAD)"
run_capture env BASE_SHA="$base_sha" HEAD_SHA="$head_sha" bash "$repo/.track/scripts/track-conventional-commit-lint.sh"
assert_code 'valid commit range passes' 0
assert_stdout_contains 'valid range success message shown' 'Conventional commit lint passed.'
cleanup_capture
cd "$orig_dir"
rm -rf "$repo"

repo="$(setup_repo)"
orig_dir="$(pwd)"
cd "$repo"
base_sha="$(git rev-parse HEAD)"
printf 'invalid\n' >> file.txt
git add file.txt
git commit -q -m 'Update file'
head_sha="$(git rev-parse HEAD)"
run_capture env BASE_SHA="$base_sha" HEAD_SHA="$head_sha" bash "$repo/.track/scripts/track-conventional-commit-lint.sh"
assert_code 'invalid commit range fails' 1
assert_stderr_contains 'invalid subject is surfaced' 'Update file'
assert_stderr_contains 'failure format guidance is surfaced' 'commit messages must follow conventional commits'
cleanup_capture
cd "$orig_dir"
rm -rf "$repo"

repo="$(setup_repo)"
orig_dir="$(pwd)"
cd "$repo"
base_sha="$(git rev-parse HEAD)"
printf 'fixup\n' >> file.txt
git add file.txt
git commit -q -m 'fixup! feat(api): add endpoint'
head_sha="$(git rev-parse HEAD)"
run_capture env BASE_SHA="$base_sha" HEAD_SHA="$head_sha" bash "$repo/.track/scripts/track-conventional-commit-lint.sh"
assert_code 'fixup commits are allowed' 0
cleanup_capture
cd "$orig_dir"
rm -rf "$repo"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
