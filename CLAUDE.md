# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

This is the Track plugin repo. Track is a git-native task coordination system distributed as a Claude Code plugin. No build step, no runtime — the plugin is markdown skills and bash scripts.

## Commands

```bash
# Run all tests
bash tests/test-validate.sh && bash tests/test-todo.sh && bash tests/test-pr-lint.sh && bash tests/test-complete.sh

# Run a single test
bash tests/test-validate.sh

# Validate .track/ state
bash scripts/track-validate.sh

# Regenerate TODO.md
bash scripts/track-todo.sh              # default: origin/main + live PR data
bash scripts/track-todo.sh --local      # local working tree
bash scripts/track-todo.sh --offline    # skip GitHub PR lookup

# Test plugin locally
claude --plugin-dir .
```

After editing skills, run `/reload-plugins` to pick up changes.

## Architecture

The plugin has two layers:

1. **Skills** (`skills/`) — markdown protocols that teach Claude the Track workflow. Each skill has a `SKILL.md` with YAML frontmatter (name, description, allowed-tools) and instructional content.
2. **Scripts** (`scripts/`) — bash enforcement scripts that validate task files, generate TODO.md, lint PRs, and handle post-merge completion.

### Dual-Copy Scripts

Scripts exist in two identical locations:
- `scripts/` — used by this repo's own `.track/` (Track dogfoods itself)
- `skills/init/scaffold/scripts/` — copied into adopting repos by `/track:init`

Changes to scripts must be mirrored in both locations. The scaffold copies are the canonical source that gets distributed.

### Key Files

- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `skills/init/scaffold/` — everything copied into adopting repos by `/track:init`
- `skills/init/scaffold/CLAUDE_TRACK_SECTION.md` — the CLAUDE.md section appended to adopting repos
- `skills/work/SKILL.md` — the core workflow protocol (auto-loaded when `.track/` exists)
- `scripts/track-common.sh` — shared YAML frontmatter parser and utility functions used by all scripts

### Skill Inventory

| Skill | Purpose |
|-------|---------|
| `init` | Scaffold `.track/`, scripts, workflows, and CLAUDE.md section into a new repo |
| `work` | Core workflow protocol — reading state, picking work, PR lifecycle |
| `create` | Create tasks and projects |
| `decompose` | Break a goal into tasks with dependencies |
| `validate` | Run validation and interpret errors |
| `todo` | Regenerate TODO.md |

## Conventions

- Use conventional commits: `feat(skills):`, `fix(scripts):`, `docs:`, `ci:`, `chore:`
- Release-please parses these to generate changelogs and bump the version in `.claude-plugin/plugin.json` — incorrect prefixes produce bad releases
- Adopting repos are self-contained — they never depend on this plugin at runtime
- The plugin teaches Claude the Track protocol; the scripts enforce it
- bash 3.2+ compatibility required (macOS default)

## Track — Task Coordination

This repo uses Track to manage its own work. Projects and tasks live in `.track/`. See `/track:work` for the full protocol.
