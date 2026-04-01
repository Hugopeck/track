#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../skills/setup-track/assets/hooks/commit-msg"
PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Run hook against a message string; returns hook exit code
run_hook() {
  local msg="$1"
  local tmp
  tmp="$(mktemp)"
  printf '%s' "$msg" > "$tmp"
  local exit_code=0
  bash "$HOOK" "$tmp" >/dev/null 2>&1 || exit_code=$?
  rm -f "$tmp"
  return "$exit_code"
}

assert_accept() {
  local name="$1"
  local msg="$2"
  if run_hook "$msg"; then
    pass "accept: $name"
  else
    fail "accept: $name"
  fi
}

assert_reject() {
  local name="$1"
  local msg="$2"
  if run_hook "$msg"; then
    fail "reject: $name"
  else
    pass "reject: $name"
  fi
}

printf 'Running commit-msg linter tests...\n\n'

printf '── Accept cases ──\n'

assert_accept 'feat with description'          'feat: add new feature'
assert_accept 'fix with description'           'fix: resolve null pointer'
assert_accept 'docs with description'          'docs: update readme'
assert_accept 'refactor with description'      'refactor: extract helper function'
assert_accept 'test with description'          'test: add coverage for auth flow'
assert_accept 'ci with description'            'ci: add lint workflow'
assert_accept 'chore with description'         'chore: update dependencies'

assert_accept 'feat with scope'                'feat(auth): add JWT validation'
assert_accept 'fix with scope'                 'fix(api): handle timeout'
assert_accept 'docs with scope'                'docs(api): update endpoint docs'
assert_accept 'refactor with scope'            'refactor(parser): simplify token handling'
assert_accept 'test with scope'                'test(auth): add integration test'
assert_accept 'ci with scope'                  'ci(github): add release workflow'
assert_accept 'chore with scope'               'chore(deps): bump lodash to 4.17.21'

assert_accept 'perf with description'          'perf: reduce startup time'
assert_accept 'build with description'         'build: update webpack config'
assert_accept 'style with description'         'style: fix indentation'
assert_accept 'revert with description'        'revert: undo broken deploy'

assert_accept 'feat breaking no scope'         'feat!: remove legacy API'
assert_accept 'feat breaking with scope'       'feat(api)!: breaking change to response'
assert_accept 'fix breaking with scope'        'fix(auth)!: change token format'

assert_accept 'multi-word scope'               'feat(some-module): add feature'
assert_accept 'numeric scope'                  'fix(v2): handle edge case'
assert_accept 'multi-word description'         'feat: add support for multiple file uploads'
assert_accept 'description with colon'         'docs: clarify rate limit: 100 req/s'
assert_accept 'description with parens'        'fix: handle (empty) array case'

assert_accept 'merge commit passthrough'       'Merge pull request #42 from foo/bar'
assert_accept 'revert commit passthrough'      'Revert "feat: add something"'
assert_accept 'fixup commit passthrough'       'fixup! feat: previous commit'
assert_accept 'squash commit passthrough'      'squash! fix: squash this'

assert_accept 'multiline message valid first'  $'feat(auth): add token refresh\n\nThis adds automatic token refresh.'

printf '\n── Reject cases ──\n'

assert_reject 'no type prefix'                 'add new feature'
assert_reject 'invalid type feature'           'feature: add new feature'
assert_reject 'invalid type update'            'update: change something'
assert_reject 'invalid type wip'               'wip: work in progress'
assert_reject 'invalid type security'          'security: patch vulnerability'

assert_reject 'missing colon'                  'feat add new feature'
assert_reject 'missing space after colon'      'feat:add new feature'
assert_reject 'missing description'            'feat: '
assert_reject 'only type and colon'            'feat:'

assert_reject 'empty scope'                    'feat(): add feature'
assert_reject 'space-only scope'               'feat( ): add feature'

assert_reject 'uppercase type'                 'Feat: add feature'
assert_reject 'all caps type'                  'FEAT: add feature'
assert_reject 'mixed case type'                'fEaT: add feature'

assert_reject 'empty message'                  ''
assert_reject 'whitespace only'                '   '

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
