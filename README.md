# Track

[![Version](https://img.shields.io/github/v/release/Hugopeck/track)](https://github.com/Hugopeck/track/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Markdown](https://img.shields.io/badge/built_with-markdown-blue)](https://daringfireball.net/projects/markdown/)
[![Bash](https://img.shields.io/badge/shell-bash_3.2%2B-orange)](https://www.gnu.org/software/bash/)

Task coordination for AI coding agents. Track uses markdown files in your git repo so multiple agents can work on the same project without stepping on each other.

## What does Track actually do?

When you use AI coding agents (like Claude Code), each session starts fresh — the agent has no idea what was planned, what's already in progress, or what depends on what. If you run multiple agents at once, they'll edit the same files, duplicate work, and create merge conflicts.

Track solves this by storing task state directly in your repo:

- A `.track/` folder holds task files (just markdown with some metadata)
- Each task lists which files it touches, so agents don't collide
- GitHub PRs drive the lifecycle automatically — draft PR means "in progress", merged means "done"
- A shared `TODO.md` shows what's happening across all agents

No server, no database, no accounts. It's just files in your repo.

## Quick demo

**1. Set up Track in your repo:**
```
> /track:init
```
This creates the `.track/` folder, adds bash scripts, and updates your `CLAUDE.md` so every agent knows the protocol. Init also scans your existing markdown files for TODOs and roadmaps — if it finds anything, you can cherry-pick which items to import as Track tasks. If you're starting fresh, it creates an onboarding project that walks you through your first task.

**2. Break a big goal into tasks:**
```
> /track:decompose Migrate the API layer to v2
```
Track reads your codebase, finds natural boundaries, and proposes tasks — each with its own set of files so agents won't conflict. You review, then it creates the task files.

**3. Start working:**
```
> /track:work
```
The agent reads `TODO.md`, picks a task that isn't blocked, opens a draft PR, and starts coding. Another agent can do the same on a different task — no conflicts.

**4. See what's happening:**
```
> /track:todo
```
Regenerates `TODO.md` with live status from GitHub. Shows who's working on what, what's blocked, and what's done.

## Best with Conductor

Track is designed to work with [Conductor](https://conductor.lol) — a Mac app that lets you run many Claude Code agents in parallel, each in its own git worktree.

**Why this matters:** Track assigns non-overlapping files to each task. Conductor gives each agent an isolated copy of the repo (via git worktrees) so they can work simultaneously without merge conflicts. Track provides the coordination layer; Conductor provides the execution environment.

Track works without Conductor too — you can run agents one at a time in regular Claude Code and still get the benefits of persistent task state and TODO tracking.

## Install

You need [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed first.

### Option 1: Copy-paste into Claude Code (recommended)

Paste this into your terminal:

```bash
git clone https://github.com/Hugopeck/track.git ~/.claude/skills/track && ~/.claude/skills/track/setup
```

### Option 2: Plugin install

```bash
claude plugin install hugopeck/track
```

Then open Claude Code in any repo and type `/track:init` to get started.

## Requirements

These must be installed on your machine before using Track:

| Dependency | Required? | What it's for |
|-----------|-----------|---------------|
| **bash** 3.2+ | Yes | Runs the Track scripts. Already installed on macOS and Linux. |
| **git** | Yes | Track stores everything in your git repo. |
| **Claude Code** | Yes | Track is a Claude Code plugin — it teaches Claude the coordination protocol. |
| **gh** (GitHub CLI) | Optional | Pulls live PR status into TODO.md. Without it, use `--offline` flags. |

## Commands

| Command | What it does |
|---------|-------------|
| `/track:init` | Set up Track in your repo — scaffolds `.track/`, imports existing TODOs, and onboards you |
| `/track:work` | Pick a task and start working (auto-loaded when `.track/` exists) |
| `/track:create` | Create tasks and projects from a plain-English description |
| `/track:decompose` | Break a big goal into smaller tasks with dependencies |
| `/track:validate` | Check your `.track/` files for errors and get fix suggestions |
| `/track:todo` | Regenerate the shared `TODO.md` view |

## How it works under the hood

Track stores everything in a `.track/` folder at the root of your repo:

```
.track/
  projects/       # one file per project (groups related tasks)
  tasks/           # one file per task (the actual units of work)
  plans/           # plan files produced during investigation tasks
```

Each task file is markdown with YAML metadata at the top:

```yaml
---
id: PROJ-003
title: Add user authentication
status: todo
priority: high
project_id: PROJ
depends_on: [PROJ-001, PROJ-002]
files: [src/auth.ts, src/middleware.ts]
---

## Context
Why this task exists...

## Acceptance Criteria
- Users can log in with email/password
- Sessions expire after 24 hours
```

The `files` field is key — it tells Track (and other agents) which files this task will touch, preventing conflicts.

**Status lifecycle:**

```
todo  ──→  active (draft PR)  ──→  review (ready PR)  ──→  done (merged)
```

You don't update status manually. Track reads it from the PR state on GitHub.

## Troubleshooting

**Validation fails?** Run `/track:validate` — it tells you exactly what's wrong and how to fix it.

**TODO.md is stale?** Run `/track:todo` to regenerate. If you're offline: `bash scripts/track-todo.sh --local --offline`

**"gh not found" warnings?** That's fine — `gh` is optional. You lose live PR status in TODO.md but everything else works.

**Commands not showing up?** Reinstall the plugin or try `claude --plugin-dir ./path/to/track` to test locally.

## License

MIT
