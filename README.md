# Track

Git-native task coordination for AI agents.

[![Version](https://img.shields.io/github/v/release/Hugopeck/track)](https://github.com/Hugopeck/track/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen)](#)
[![Bash](https://img.shields.io/badge/bash-3.2%2B-orange)](https://www.gnu.org/software/bash/)

A `.track/` folder in your repo replaces your PM tool. Markdown task files, bash enforcement scripts, git hooks, and GitHub Actions handle the full lifecycle — from task creation to PR merge. No server, no accounts, no vendor lock-in. Free and open source.

<!-- TODO: Add terminal recording (VHS/asciinema) showing /track:init → /track:decompose → /track:work → PR merged → auto-completion -->

## Features

- **Zero infrastructure** — Markdown + bash + git. No binary, no server, no database. Drop a folder into any repo and start tracking.

- **Parallel-safe** — Every task declares which files it owns via `files:` glob patterns. No two active tasks can claim the same files. Multiple agents work the same repo without conflicts.

- **Git-native status** — Status is driven by your PR lifecycle, not manual updates. Draft PR = active. Ready for review = review. Merged = done. Always accurate.

- **Slash commands** — Six commands cover the full workflow: decompose goals, create tasks, pick work, open PRs, and regenerate views. Or skip the agent and use the bash scripts directly.

- **Self-enforcing** — Conventional commit hooks, PR lint, task validation, and post-merge automation. The system catches mistakes before they reach CI.

- **Dependency cascading** — When a blocking task's PR merges, downstream tasks auto-unblock. No one has to remember to update the board.

- **Works without agents** — The `.track/` folder, bash scripts, and GitHub Actions work standalone. Layer AI agents on top for automation, or manage tasks by hand.

- **GitHub Actions included** — Four workflows for validation, PR lint, commit lint, and post-merge completion. Installed automatically by `/track:init`.

## Quick Start

### Install

Paste this into your coding agent:

> Install Track on this machine: clone `https://github.com/Hugopeck/track.git` to `~/.local/share/agent-skills/track`, run `~/.local/share/agent-skills/track/install.sh`, then run `/track:init` in this repo.

Or install manually:

```bash
git clone https://github.com/Hugopeck/track.git ~/.local/share/agent-skills/track
~/.local/share/agent-skills/track/install.sh
```

### Initialize a repo

```
/track:init
```

Creates `.track/`, installs scripts, hooks, and GitHub Actions. If it finds existing markdown TODOs or roadmaps, it offers to import them as tasks.

### Start using it

Break a goal into tasks:
```
/track:decompose Migrate the API layer to v2
```

Pick a task and start working:
```
/track:work
```

See what's happening:
```
/track:refresh-track
```

## How It Works

Everything lives in a `.track/` folder at the root of your repo:

```
.track/
  projects/        # one file per project
  tasks/           # one file per task (the units of work)
  plans/           # short-lived investigation notes
  specs/           # durable design docs
  events/          # local activity log (JSONL)
  scripts/         # bash enforcement scripts
```

Each task is a markdown file with YAML frontmatter — id, status, priority, dependencies, and file ownership. Tasks belong to projects. Dependencies are explicit.

```
todo → active (draft PR) → review (PR ready) → done (PR merged)
```

The `files:` field is the coordination mechanism. No two active tasks can claim the same files, so parallel agents never collide. `/track:decompose` creates tasks with non-overlapping scopes by default.

See [TRACK.md](TRACK.md) for the full protocol, task format, and field reference.

## Commands

| Command | What it does |
|---|---|
| `/track:init` | Set up Track in a repo — `.track/`, scripts, hooks, workflows |
| `/track:work` | Pick a task, open a draft PR, start working |
| `/track:create` | Create tasks and projects from plain English |
| `/track:decompose` | Break a goal into tasks with non-overlapping file scopes |
| `/track:refresh-track` | Regenerate `BOARD.md`, `TODO.md`, `PROJECTS.md` |
| `/track:update-skills` | Update installed Track skills to latest version |

Every command also works as a bash script in `.track/scripts/` for non-agent workflows.

## Requirements

| Dependency | Required | Purpose |
|---|---|---|
| **bash** 3.2+ | Yes | Runs Track scripts. Ships with macOS and Linux. |
| **git** | Yes | Track state lives in your repo. |
| **gh** (GitHub CLI) | No | Enables PR-aware views and merge automation. |

## Track Cloud

Track is free and open source under MIT. Everything in this repo — skills, scripts, hooks, workflows — stays free forever.

A future **Track Cloud** product will add cross-repo dashboards, team analytics, notifications, and multi-repo coordination. The open-source protocol is the foundation; Cloud builds on top of it without replacing anything here.

## Community

Track is early and moving fast. Bug reports, feature ideas, and pull requests are welcome.

- [GitHub Issues](https://github.com/Hugopeck/track/issues) — report bugs and request features
- [GitHub Discussions](https://github.com/Hugopeck/track/discussions) — questions and ideas

## Documentation

- [TRACK.md](TRACK.md) — full protocol reference
- [AGENTS.md](AGENTS.md) — repository instructions for AI agents
- [CHANGELOG.md](CHANGELOG.md) — release history

## License

[MIT](LICENSE)
