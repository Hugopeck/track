#!/usr/bin/env bash
set -euo pipefail

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

printf 'Running conductor config tests...\n\n'

if diff -u conductor.json skills/init/scaffold/conductor.json >/tmp/track-conductor-diff 2>&1; then
  pass 'root conductor.json matches scaffold copy'
else
  fail 'root conductor.json diverges from scaffold copy'
  cat /tmp/track-conductor-diff
fi

expected_cmd='bash .track/scripts/track-todo.sh || bash .track/scripts/track-todo.sh --offline'

if grep -Fq "\"setup\": \"$expected_cmd\"" conductor.json; then
  pass 'setup uses .track/scripts path'
else
  fail 'setup does not use .track/scripts path'
fi

if grep -Fq "\"run\": \"$expected_cmd\"" conductor.json; then
  pass 'run uses .track/scripts path'
else
  fail 'run does not use .track/scripts path'
fi

if ! grep -Eq 'custom_prompt_|create_pr|rename_branch|fix_errors|resolve_merge_conflicts' conductor.json && \
   ! grep -Eq 'custom_prompt_|create_pr|rename_branch|fix_errors|resolve_merge_conflicts' skills/init/scaffold/conductor.json; then
  pass 'conductor.json stays free of app-local prompt keys'
else
  fail 'conductor.json incorrectly includes app-local prompt keys'
fi

if ! grep -Fq 'Track-Task:' conductor.json && \
   ! grep -Fq 'Track-Task:' skills/init/scaffold/conductor.json; then
  pass 'conductor.json does not embed Track PR prompt copy'
else
  fail 'conductor.json incorrectly embeds Track PR prompt copy'
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
