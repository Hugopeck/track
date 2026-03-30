---
name: update-track
description: Update Track skills to latest version. Use when asked to update Track or check for updates.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

Update Track skills to the latest version by pulling from the upstream repository.

## Steps

1. Find the Track repo by resolving the installed skill directory, then following
   its symlink back to the source clone:
   ```bash
   if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
     SKILL_DIR="$CLAUDE_SKILL_DIR"
   else
     printf 'CLAUDE_SKILL_DIR is not set. Locate the installed update-track skill directory before continuing.\n' >&2
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

2. If `REPO` is empty, stop and report that Track was not installed from a git
   clone, so there is nothing to update in place.

3. Pull latest:
   ```bash
   cd "$REPO" && git pull --ff-only
   ```

4. Report what changed:
   ```bash
   cd "$REPO" && echo "Updated to $(git rev-parse --short HEAD)" && git log --oneline -5
   ```

If the pull fails due to local changes, inform the user and suggest:
```bash
git stash && git pull --ff-only && git stash pop
```

## Closing Message

> Track updated to `{short_sha}`. Recent changes:
> {last 5 commit summaries}
