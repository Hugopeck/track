#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE="skills/init/SKILL.md"
INSTALL_MANIFEST_FILE="skills/init/assets/install-manifest.json"
TRACK_MD="TRACK.md"

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
  printf '  PASS: %s
' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s
' "$1"
  FAIL=$((FAIL + 1))
}

printf 'Running init skill regression tests...

'

if contains_literal 'Continue immediately to Phase 2, then automatically continue through the' "$SKILL_FILE"; then
  pass 'upgrade flow repairs structure before reinstalling files'
else
  fail 'upgrade flow still skips Phase 2'
fi

if contains_literal '### Phase 2.5: Clean up legacy root scripts during upgrade' "$SKILL_FILE" &&    contains_literal 'scripts/track-common.sh' "$SKILL_FILE"; then
  pass 'legacy root script cleanup is documented'
else
  fail 'legacy root script cleanup is missing'
fi

if contains_literal '.track/.track-version' "$SKILL_FILE"; then
  pass 'version marker write is documented'
else
  fail 'version marker write is missing'
fi

if [[ -f "$INSTALL_MANIFEST_FILE" ]] &&    contains_literal 'install-manifest.json' "$SKILL_FILE"; then
  pass 'init skill documents manifest-driven installation'
else
  fail 'init skill is missing manifest-driven installation'
fi

if ! contains_literal 'opencode.json' "$SKILL_FILE" &&    ! contains_literal 'opencode.json' "$INSTALL_MANIFEST_FILE"; then
  pass 'init stays free of OpenCode-specific repo config'
else
  fail 'init still references OpenCode-specific repo config'
fi

if contains_literal '### Phase 5: Explain the recommended branch/worktree workflow' "$SKILL_FILE" &&    contains_literal 'one git worktree and one branch per active task' "$SKILL_FILE"; then
  pass 'init skill documents branch and worktree guidance'
else
  fail 'init skill is missing branch and worktree guidance'
fi

if contains_literal 'Track marks tasks `active` and `review`' "$SKILL_FILE" &&    contains_literal 'Track-Task: {id}' "$SKILL_FILE"; then
  pass 'init skill ties PR lifecycle to task linkage'
else
  fail 'init skill is missing PR lifecycle linkage guidance'
fi

if contains_literal 'fresh worktree or branch' "$SKILL_FILE"; then
  pass 'init closing messages offer a clean branch or worktree'
else
  fail 'init closing messages still assume a vendor workspace'
fi

if contains_literal '### Phase 7: Update `CLAUDE.md` and `AGENTS.md`' "$SKILL_FILE" &&    contains_literal '${CLAUDE_SKILL_DIR}/../../TRACK.md' "$SKILL_FILE" &&    contains_literal '<!-- TRACK:START -->' "$SKILL_FILE"; then
  pass 'init skill documents unified CLAUDE.md/AGENTS.md Track section support'
else
  fail 'init skill is missing unified Track section support'
fi

if [[ ! -f skills/init/assets/conductor.json && ! -f skills/init/assets/conductor-prefs.md ]]; then
  pass 'init no longer ships Conductor-specific assets'
else
  fail 'Conductor-specific init assets still exist'
fi

if [[ -f "$TRACK_MD" ]] && contains_literal '## Track — Task Coordination' "$TRACK_MD"; then
  pass 'TRACK.md exists at root with canonical Track documentation'
else
  fail 'TRACK.md is missing or does not contain Track documentation'
fi

printf '
Summary: %d passed, %d failed
' "$PASS" "$FAIL"

if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
