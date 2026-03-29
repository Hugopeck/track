#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
ROOT_FILE='opencode.json'
ASSET_FILE='skills/init/assets/opencode.json'
README_FILE='README.md'
INIT_SKILL_FILE='skills/init/SKILL.md'

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

contains_literal() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -Fq -- "$pattern" "$file"
  else
    grep -Fq -- "$pattern" "$file"
  fi
}

printf 'Running OpenCode config regression tests...\n\n'

if diff -u "$ROOT_FILE" "$ASSET_FILE" >/tmp/track-opencode-diff 2>&1; then
  pass 'root opencode.json matches asset copy'
else
  fail 'root opencode.json diverges from asset copy'
fi

if contains_literal 'skills/init/assets/opencode.json' "$README_FILE"; then
  pass 'README references canonical OpenCode asset'
else
  fail 'README does not reference canonical OpenCode asset'
fi

if contains_literal 'opencode.json' "$INIT_SKILL_FILE" && \
   contains_literal 'repo_assets' "$INIT_SKILL_FILE"; then
  pass 'init skill documents opencode.json as installable repo asset'
else
  fail 'init skill does not document opencode.json installation'
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
