---
name: update-skills
description: |
  Update Track skills to the latest version. Auto-runs silently at session
  start in any repo with `.track/` — checks for updates, pulls if available,
  and reports a one-line result. Also use when asked to update Track manually.
auto-load: true
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

`/update-skills` owns refreshing the installed Track skill clone by pulling from
its upstream git repository. When this skill is auto-loaded, it runs first at
session start, prints exactly one status line, then stops.

## What This Skill Owns

1. Detect whether this is session-start auto-run or a direct user invocation
2. Resolve the installed Track clone from the current skill directory
3. Pull updates fast-forward only when a git clone is available
4. Report one concise result line

This skill does NOT own task lifecycle work, view regeneration, or repo-local
Track validation.

## Operating Modes

Commit to one mode at the start. Do not drift.

- `session-start` — silently check for updates, pull if available, print one line, then stop
- `manual` — user explicitly asked to update Track skills now

## Definition of Done

- The installed Track clone is resolved or a concrete blocker is reported
- `git pull --ff-only` ran when the install came from a git clone
- The final response is exactly one line that states either updated, up to date, or blocked

## Steps

1. Select a mode.
   - If the skill was auto-loaded at session start, lock `session-start`
   - If the user explicitly asked to update Track, lock `manual`
2. At session start: silently check for updates, pull if available, print one line (`Track skills updated to vX.Y.Z.`, `Track skills up to date.`, or `Track skills update blocked: {reason}.`), then stop. Do not wait for user prompt.
3. Find the Track repo by resolving the installed skill directory, then following
   its symlink back to the source clone:
   ```bash
   if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
     SKILL_DIR="$CLAUDE_SKILL_DIR"
   else
     printf 'CLAUDE_SKILL_DIR is not set. Locate the installed update-skills skill directory before continuing.\n' >&2
     exit 1
   fi

   while [ -L "$SKILL_DIR" ]; do
     LINK_TARGET="$(readlink "$SKILL_DIR")"
     case "$LINK_TARGET" in
       /*) SKILL_DIR="$LINK_TARGET" ;;
       *)
         SKILL_DIR="$(cd "$(dirname "$SKILL_DIR")" && cd "$(dirname "$LINK_TARGET")" && pwd)/$(basename "$LINK_TARGET")"
         ;;
     esac
   done

   REPO="$(cd "$SKILL_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null)"
   ```
4. If `REPO` is empty, STOP and report that Track was not installed from a git
   clone, so there is nothing to update in place.
5. Pull latest:
   ```bash
   cd "$REPO" && git pull --ff-only
   ```
5.5. Refresh symlinks so any newly added skills become discoverable:
   ```bash
   for skill in "$REPO/skills"/*/; do
     [ -f "$skill/SKILL.md" ] || continue
     name="$(basename "$skill")"
     ln -sfn "$skill" "${HOME}/.agents/skills/$name"
     ln -sfn "$skill" "${HOME}/.claude/skills/$name"
   done
   ```
6. Report the result with one line:
   ```bash
   cd "$REPO" && git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
   ```

If the pull fails due to local changes, report the blocker and suggest:
```bash
git stash && git pull --ff-only && git stash pop
```

## Closing Message Matrix

- Updated → `Track skills updated to {version}.`
- No-op → `Track skills up to date.`
- Blocked → `Track skills update blocked: {reason}.`

## Do Not

- Do not modify task files or repo content outside the installed Track clone
- Do not run a non-fast-forward pull
- Do not prompt the user before the session-start check unless a conflict blocks the update
