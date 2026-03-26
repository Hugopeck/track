# Track

**Project management tools are dead. A folder is all you need.**

[![Version](https://img.shields.io/github/v/release/Hugopeck/track)](https://github.com/Hugopeck/track/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-blueviolet)](#install)
[![Cursor](https://img.shields.io/badge/Cursor-plugin-blue)](#install)
[![Bash](https://img.shields.io/badge/shell-bash_3.2%2B-orange)](https://www.gnu.org/software/bash/)

Track is a git-native coordination protocol for AI agents. A `.track/` folder in your repo replaces your PM tool — markdown task files, bash enforcement scripts, PR-driven status. No server, no accounts, no vendor lock-in.

<!-- TODO: Add demo GIF here -->

## Why Track exists

[Linear just announced](https://linear.app/next) that issue tracking was built for handoffs, not execution. They're right. But their answer is "use our AI inside our tool." That's still a $16/seat/month SaaS prison.

Track's answer: **the tool was never needed.**

When AI agents work on your codebase, they don't need a Kanban board. They need to know what's taken, what files to avoid, and where to report progress. Git already does all of this. Track just makes it explicit.

| | Linear | Track |
|---|---|---|
| Cost | $8-16/seat/month | Free forever |
| Infrastructure | Cloud SaaS, vendor lock-in | Git. That's it. |
| Agent support | Linear Agent only | Claude Code, Cursor, Codex, Gemini CLI |
| Data ownership | Their servers | Your repo |
| Non-code projects | No | Yes — any folder, any project |

## Install — 30 seconds

Requirements: [Claude Code](https://claude.ai/code), Git, bash 3.2+

**Step 1: Install on your machine**

Open a workspace in [Conductor](https://conductor.lol) and paste this prompt. Claude does the rest.

> Install Track: run `git clone https://github.com/Hugopeck/track.git ~/.claude/skills/track && ~/.claude/skills/track/setup`, then run `/track:init` to set up Track in this repo.

This is a **prompt**, not a bash command — paste it into a Conductor workspace, not your terminal.

**Alternatives:**
- Claude Code plugin registry: `claude plugin install hugopeck/track`
- Manual: clone the repo to `~/.claude/skills/track` and run `./setup`

**Step 2: Set up Track in your repo**

If the install prompt above didn't already run init:

```
> /track:init
```

This creates `.track/`, adds bash scripts, and updates your `CLAUDE.md` so every agent knows the protocol. If it finds existing markdown TODOs or roadmaps, you can import them as Track tasks.

That's it — you're tracking.

## Quick start

**Break a big goal into tasks:**
```
> /track:decompose Migrate the API layer to v2
```

Track reads your codebase, finds natural boundaries, and proposes tasks with non-overlapping file scopes so agents won't conflict.

**Start working:**
```
> /track:work
```

The agent reads `TODO.md`, picks a task that isn't blocked, opens a draft PR, and starts coding. Another agent can do the same on a different task — no conflicts.

**See what's happening:**
```
> /track:todo
```

Regenerates `TODO.md` with live status from GitHub. Shows who's working on what, what's blocked, and what's done.

## How agents coordinate

Track stores everything in a `.track/` folder at the root of your repo:

```
.track/
  projects/       # one file per project (groups related tasks)
  tasks/           # one file per task (the actual units of work)
  plans/           # plan files produced during investigation tasks
```

Each task file is markdown with YAML metadata:

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

The `files` field is what makes multi-agent work possible — it tells every agent which files are claimed, preventing conflicts.

**Status lifecycle — driven by Git, not manual updates:**

```
todo  ──→  active (draft PR)  ──→  review (ready PR)  ──→  done (merged)
```

`active` and `review` are derived from GitHub PR state, not local branches.

## Best with Conductor

Track is designed to work with [Conductor](https://conductor.lol) — a Mac app that lets you run many Claude Code agents in parallel, each in its own git worktree.

Track assigns non-overlapping files to each task. Conductor gives each agent an isolated copy of the repo. Together: parallel agents, zero conflicts.

Track works without Conductor too — you can run agents one at a time and still get persistent task state and TODO tracking.

## Works everywhere

Track is just markdown + bash + git. Any AI agent that can read files can use it.

| Platform | Status |
|---|---|
| Claude Code | Full plugin support |
| Cursor | Plugin available |
| Codex CLI | Works via AGENTS.md |
| Gemini CLI | Works via markdown skills |

## The bigger vision

If a folder can manage a codebase, why not anything?

Track's protocol is simple enough for any project: book writing, research, home renovation, event planning. A GitHub account and a folder is your project manager. AI agents are the bookkeepers you never had.

## All commands

| Command | What it does |
|---------|-------------|
| `/track:init` | Set up or re-run Track in your repo — refreshes installed files, imports existing TODOs, and onboards you |
| `/track:work` | Pick a task and start working (auto-loaded when `.track/` exists) |
| `/track:create` | Create tasks and projects from a plain-English description |
| `/track:decompose` | Break a big goal into smaller tasks with dependencies |
| `/track:validate` | Check your `.track/` files for errors and get fix suggestions |
| `/track:todo` | Regenerate the shared `TODO.md` view |

## Requirements

| Dependency | Required? | What it's for |
|-----------|-----------|---------------|
| **bash** 3.2+ | Yes | Runs the Track scripts. Already on macOS and Linux. |
| **git** | Yes | Track stores everything in your git repo. |
| **Claude Code** | For plugin features | Track is a Claude Code plugin. The bash scripts work standalone. |
| **gh** (GitHub CLI) | Required | PR-based status detection. Install and run `gh auth login`. |

## Troubleshooting

**Validation fails?** Run `/track:validate` — it tells you exactly what's wrong and how to fix it.

**TODO.md is stale?** Run `/track:todo` to regenerate. If you're offline: `bash .track/scripts/track-todo.sh --local --offline`

**"gh not found" or PR status missing?** Install `gh` and run `gh auth login`, then retry.

**Commands not showing up?** Reinstall the plugin or try `claude --plugin-dir ./path/to/track` to test locally.

## Roadmap

**Free forever:** Single-repo coordination, all agent platforms, bash scripts, the full protocol.

**Coming (Track Pro):** Cross-repo dashboards, team analytics, Slack notifications, audit trails.

**Coming (Track for Teams):** Approval workflows, permissions, compliance reporting.

## License

MIT

---

*A folder is all you need. Happy tracking.*
