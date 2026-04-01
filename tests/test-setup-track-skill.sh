#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKILL_FILE="skills/setup-track/SKILL.md"
INSTALL_MANIFEST_FILE="skills/setup-track/assets/install-manifest.json"
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

printf 'Running setup-track skill regression tests...

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
  pass 'setup-track skill documents manifest-driven installation'
else
  fail 'setup-track skill is missing manifest-driven installation'
fi

if ! contains_literal 'opencode.json' "$SKILL_FILE" &&    ! contains_literal 'opencode.json' "$INSTALL_MANIFEST_FILE"; then
  pass 'setup-track stays free of OpenCode-specific repo config'
else
  fail 'setup-track still references OpenCode-specific repo config'
fi

if contains_literal '### Phase 5: Explain the recommended branch/worktree workflow' "$SKILL_FILE" &&    contains_literal 'one git worktree and one branch per active task' "$SKILL_FILE"; then
  pass 'setup-track skill documents branch and worktree guidance'
else
  fail 'setup-track skill is missing branch and worktree guidance'
fi

if contains_literal '### Phase 4.5: Install git hooks' "$SKILL_FILE" &&    contains_literal 'If the destination file already exists, read both the existing file and' "$SKILL_FILE" &&    contains_literal 'the asset version and compare the full contents' "$SKILL_FILE"; then
  pass 'setup-track skill documents safe hook installation'
else
  fail 'setup-track skill is missing safe hook installation guidance'
fi

if contains_literal 'ask before overwriting in both `fresh-init` and' "$SKILL_FILE" &&    contains_literal 'If one hook installs and another is skipped' "$SKILL_FILE"; then
  pass 'setup-track skill handles differing hooks safely in all modes'
else
  fail 'setup-track skill does not handle differing hooks safely in all modes'
fi

if contains_literal '### Phase 4.75: Apply GitHub Ruleset' "$SKILL_FILE" &&    contains_literal 'Apply the Track Protection ruleset now?' "$SKILL_FILE"; then
  pass 'setup-track skill asks before applying ruleset'
else
  fail 'setup-track skill does not ask before applying ruleset'
fi

if contains_literal 'block deletion and force-pushes' "$SKILL_FILE" &&    contains_literal 'require linear history' "$SKILL_FILE"; then
  pass 'setup-track skill explains ruleset impact before consent'
else
  fail 'setup-track skill does not explain ruleset impact before consent'
fi

if contains_literal 'Hooks: {installed to .git/hooks/ | installed to .husky/ | partial — details | skipped — reason}' "$SKILL_FILE" &&    contains_literal 'Ruleset: {applied | skipped — gh missing | skipped — gh not authenticated | skipped — not a GitHub repo | skipped — no admin access | skipped — already exists | skipped — user declined | skipped — API error}' "$SKILL_FILE"; then
  pass 'setup-track checkpoint summary includes hook and ruleset outcomes'
else
  fail 'setup-track checkpoint summary is missing hook and ruleset outcomes'
fi

if contains_literal 'Track marks tasks `active` and `review`' "$SKILL_FILE" &&    contains_literal 'Track-Task: {id}' "$SKILL_FILE"; then
  pass 'setup-track skill ties PR lifecycle to task linkage'
else
  fail 'setup-track skill is missing PR lifecycle linkage guidance'
fi

if contains_literal 'fresh worktree or branch' "$SKILL_FILE"; then
  pass 'setup-track closing messages offer a clean branch or worktree'
else
  fail 'setup-track closing messages still assume a vendor workspace'
fi

if contains_literal '### Phase 7: Update `CLAUDE.md` and `AGENTS.md`' "$SKILL_FILE" &&    contains_literal '${CLAUDE_SKILL_DIR}/../../TRACK.md' "$SKILL_FILE" &&    contains_literal '<!-- TRACK:START -->' "$SKILL_FILE"; then
  pass 'setup-track skill documents unified CLAUDE.md/AGENTS.md Track section support'
else
  fail 'setup-track skill is missing unified Track section support'
fi

if [[ ! -f skills/setup-track/assets/conductor.json && ! -f skills/setup-track/assets/conductor-prefs.md ]]; then
  pass 'setup-track no longer ships Conductor-specific assets'
else
  fail 'Conductor-specific setup-track assets still exist'
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
