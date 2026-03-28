# AGENTS.md

Shared repository instructions for OpenCode, Codex CLI, and other agentic coding tools.

OpenCode reads this file automatically at the repo root. This repo also ships an `opencode.json` that adds `CLAUDE.md` as supplemental detail so we can reuse the deeper repo notes without duplicating them here.

## Project Context

This is the Track repo. Track is a git-native task coordination system distributed as markdown skills and bash scripts. There is no build step or runtime app in this repo.

## Commands

```bash
# Run all tests
bash tests/run-all.sh

# Run a single test
bash tests/test-validate.sh

# Validate .track/ state
bash .track/scripts/track-validate.sh

# Regenerate TODO.md
bash .track/scripts/track-todo.sh              # default: origin/main + live PR data
bash .track/scripts/track-todo.sh --local      # local working tree
bash .track/scripts/track-todo.sh --offline    # skip GitHub PR lookup

# Test the Claude Code plugin locally
claude --plugin-dir .
```

## Architecture

Track has two layers:

1. **Skills** (`skills/`) — markdown protocols that teach agents the Track workflow.
2. **Scripts** (`.track/scripts/`) — bash enforcement scripts that validate task files, generate `TODO.md`, lint PRs, and handle post-merge completion.

### Dual-Copy Scripts

Scripts exist in two identical locations:

- `.track/scripts/` — used by this repo's own `.track/`
- `skills/init/scaffold/track/scripts/` — copied into adopting repos by `/track:init`

When a script changes, mirror the same change in both locations.

### Key Files

- `.claude-plugin/plugin.json` — plugin manifest and released version
- `skills/init/scaffold/` — scaffold copied into adopting repos by `/track:init`
- `skills/init/scaffold/CLAUDE_TRACK_SECTION.md` — the Track section appended to adopting repos' `CLAUDE.md`
- `skills/work/SKILL.md` — the core workflow protocol
- `.track/scripts/track-common.sh` — shared YAML parser and script helpers

## Working Rules

- Keep changes tightly scoped to the requested task.
- Preserve the required protocol sections inside existing `SKILL.md` files.
- Do not change the released version in `.claude-plugin/plugin.json` manually.
- Prefer updating shared repo guidance once and reusing it across agent platforms.

## Conventional Commits

PR titles must follow conventional commits:

```text
type(scope): description
```

Common scopes: `skills`, `scripts`, `init`, `work`, `create`, `decompose`, `validate`, `todo`

Use `feat` for user-facing capability, `fix` for bug fixes, `docs` for documentation, `refactor` for internal code changes, `test` for test updates, `ci` for workflow changes, and `chore` for maintenance.

## Versioning

- Version lives in `.claude-plugin/plugin.json`
- `release-please` handles version bumps, changelog updates, and GitHub releases on merge to `main`
- `feat` triggers a minor bump, `fix` and `docs` trigger a patch bump, and `!` triggers a major bump
