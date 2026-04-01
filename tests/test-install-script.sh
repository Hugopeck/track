#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
INSTALL_FILE='install.sh'
MANIFEST_FILE='skills/setup-track/assets/install-manifest.json'

contains_literal() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -Fq -- "$pattern" "$file"
  else
    grep -Fq -- "$pattern" "$file"
  fi
}

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

printf 'Running install/runtime ownership regression tests...\n\n'

if [[ -f "$MANIFEST_FILE" ]]; then
  pass 'install manifest exists'
else
  fail 'install manifest is missing'
fi

if contains_literal '[ -f "$skill/SKILL.md" ] || continue' "$INSTALL_FILE"; then
  pass 'install.sh only symlinks directories with SKILL.md'
else
  fail 'install.sh still symlinks every directory under skills/'
fi

if [[ -f scripts/lib/track-common.sh ]]; then
  pass 'shared runtime helper moved to scripts/lib'
else
  fail 'shared runtime helper missing from scripts/lib'
fi

if [[ -f scripts/validate/track-validate.sh ]]; then
  pass 'validate support script moved to scripts/validate'
else
  fail 'validate support script missing from scripts/validate'
fi

if [[ -f skills/todo/scripts/track-todo.sh ]]; then
  pass 'todo owns track-todo.sh'
else
  fail 'todo does not own track-todo.sh'
fi

if [[ -f skills/work/scripts/track-pr-lint.sh ]] && [[ -f skills/work/scripts/track-complete.sh ]] && [[ -f skills/work/scripts/track-sync-pr-status.sh ]] && [[ -f skills/work/scripts/track-start.sh ]] && [[ -f skills/work/scripts/track-ready.sh ]]; then
  pass 'work owns PR lifecycle scripts'
else
  fail 'work is missing PR lifecycle scripts'
fi

if [[ ! -d skills/setup-track/assets/scripts ]]; then
  pass 'setup-track no longer owns a monolithic assets/scripts directory'
else
  fail 'setup-track still owns assets/scripts'
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
