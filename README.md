# Track

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/Hugopeck/track/releases) <!-- x-release-please-version -->

Git-native task coordination for Claude Code.

Track is a zero-dependency repo convention that turns `.track/` markdown files, bash scripts, and GitHub PR state into a complete task management system. No database, no web UI, no runtime — just git.

## Install

```bash
claude plugin install hugopeck/track
```

Or test locally:

```bash
claude --plugin-dir ./path/to/track
```

## Quick Start

```
/track:init
```

This scaffolds your repo with:
- `.track/projects/` and `.track/tasks/` — where state lives
- `scripts/track-*.sh` — validation, TODO generation, PR lint, post-merge completion
- `.github/workflows/track-*.yml` — CI validation, PR lint, post-merge automation
- A Track section in your `CLAUDE.md` — the always-loaded protocol

Then start working:

```
/track:create Add user authentication
/track:decompose Migrate the API layer to v2
/track:validate
/track:todo
```

## Skills

| Skill | Purpose |
|-------|---------|
| `/track:init` | Scaffold Track in a new repo |
| `/track:work` | Core workflow protocol (auto-loaded when `.track/` exists) |
| `/track:create` | Create tasks and projects |
| `/track:decompose` | Break a goal into tasks with dependencies |
| `/track:validate` | Run validation and interpret errors |
| `/track:todo` | Regenerate TODO.md |

## How It Works

```
.track/
  projects/       # scope contracts — one per initiative
  tasks/           # flat task files — one per unit of work
```

Every task has YAML frontmatter (`id`, `title`, `status`, `mode`, `priority`, `project_id`, `depends_on`, `files`) and markdown body sections (`## Context`, `## Acceptance Criteria`, `## Notes`).

Status flows through a PR lifecycle:

```
Create task file    Open draft PR           Mark ready for review     PR merges
status: todo   →    effective: active   →    effective: review    →   status: done
```

The **raw status** is what's in the file. The **effective status** layers GitHub PR state on top. `TODO.md` shows effective status.

## Design Philosophy

Track is deliberately minimal:

- **No scanner, no cloud, no service** — git is the database, PRs are the workflow
- **No hooks or lifecycle automation** — native CLAUDE.md loading and CI-time enforcement are sufficient
- **No Python, no Node, no dependencies** — bash 3.2+ and git only; `gh` is optional
- **No web UI or dashboard** — `TODO.md` is the view
- **Convention over configuration** — file naming patterns, branch patterns, and YAML frontmatter are the API

Adopting repos are self-contained. The plugin teaches Claude the convention; the scripts and workflows run independently.

## Requirements

- **bash** 3.2+ (ships with macOS and Linux)
- **git**
- **gh** (GitHub CLI) — optional, enables PR-aware status and CI validation

## License

MIT
