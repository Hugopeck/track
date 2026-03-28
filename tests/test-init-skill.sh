#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE="skills/init/SKILL.md"
TRACK_PLANS_README=".track/plans/README.md"
SCAFFOLD_PLANS_README="skills/init/scaffold/track/plans/README.md"

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

printf 'Running init skill regression tests...\n\n'

if contains_literal 'Continue immediately to Phase 2, then automatically continue through the' "$SKILL_FILE"; then
  pass 'upgrade flow repairs structure before reinstalling files'
else
  fail 'upgrade flow still skips Phase 2'
fi

if contains_literal '### Phase 2.5: Clean up legacy root scripts during upgrade' "$SKILL_FILE" && \
   contains_literal 'scripts/track-common.sh' "$SKILL_FILE"; then
  pass 'legacy root script cleanup is documented'
else
  fail 'legacy root script cleanup is missing'
fi

if contains_literal '.track/.track-version' "$SKILL_FILE"; then
  pass 'version marker write is documented'
else
  fail 'version marker write is missing'
fi

if diff -u "$SCAFFOLD_PLANS_README" "$TRACK_PLANS_README" >/tmp/track-plans-readme-diff 2>&1; then
  pass 'repo plans README matches scaffold copy'
else
  fail 'repo plans README diverges from scaffold copy'
  cat /tmp/track-plans-readme-diff
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
