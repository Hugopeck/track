# Track

**Project management tools are dead. A folder is all you need.**

[![Version](https://img.shields.io/github/v/release/Hugopeck/track)](https://github.com/Hugopeck/track/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/agent_skills-open_standard-blueviolet)](#works-everywhere)
[![AGENTS.md](https://img.shields.io/badge/repo_instructions-AGENTS.md-black)](#shared-repo-instructions)
[![Bash](https://img.shields.io/badge/shell-bash_3.2%2B-orange)](https://www.gnu.org/software/bash/)

Track is a git-native coordination protocol for AI agents. A `.track/` folder in your repo replaces your PM tool with markdown task files, bash enforcement scripts, git hooks, and GitHub workflow automation. No server, no accounts, no vendor lock-in.

<!-- TODO: Add demo GIF here -->

## Why Track exists

[Linear just announced](https://linear.app/next) that issue tracking was built for handoffs, not execution. They're right. But their answer is "use our AI inside our tool." That's still a $16/seat/month SaaS prison.

Track's answer: **the tool was never needed.**

When AI agents work on your codebase, they don't need a Kanban board. They need to know what's taken, what files to avoid, and where to report progress. Git already does all of this. Track just makes it explicit.

| | Linear | Track |
|---|---|---|
| Cost | $8-16/seat/month | Free forever |
| Infrastructure | Cloud SaaS, vendor lock-in | Git. That's it. |
| Agent support | Linear Agent only | Installed skills, repo-root `AGENTS.md`, or no agent at all |
| Data ownership | Their servers | Your repo |
| Non-code projects | No | Yes — any folder, any project |

## Install — 30 seconds

Requirements: Git and bash 3.2+. Installed skills and repo-root `AGENTS.md` are optional integration surfaces.

**Step 1: Install on your machine**

Paste this prompt into your coding agent if you want it to do the install for you.

> Install Track on this machine: clone `https://github.com/Hugopeck/track.git` to `~/.local/share/agent-skills/track`, run `~/.local/share/agent-skills/track/install.sh`, then run `/track:init` in this repo.

This is a **prompt**, not a bash command — paste it into your agent chat, not your terminal.

**Manual terminal install:**

```bash
git clone https://github.com/Hugopeck/track.git ~/.local/share/agent-skills/track
~/.local/share/agent-skills/track/install.sh
```

This installs the Track clone at `~/.local/share/agent-skills/track` and symlinks each skill into `~/.agents/skills/`.

**Step 2: Set up Track in your repo**

If the install prompt above didn't already run init:

```
> /track:init
```

This creates `.track/`, adds bash scripts, installs commit hooks, installs GitHub Actions workflows, optionally applies the Track Protection ruleset, updates your `CLAUDE.md` to point at `AGENTS.md`, and installs a Track-managed block in `AGENTS.md` as the shared repo instruction surface. If it finds existing markdown TODOs or roadmaps, you can import them as Track tasks. If you initialized before v2.0.0, re-run `/track:init` to migrate legacy root `scripts/` into `.track/scripts/` and add `.track/plans/`.

That's it — you're tracking.

## Shared repo instructions

Track stays vendor-neutral. If an agent reads the repo-root `AGENTS.md`, that
is enough — no vendor-specific repo config is required or installed by
`/track:init`.

1. Initialize Track in the repo using the standard setup path so `.track/` and
   the scripts exist.
2. Commit `AGENTS.md` at the repo root with the shared Track workflow.
3. Use an agent that supports installed skills, or any agent that reads
   `AGENTS.md`.

`CLAUDE.md` stays as a thin pointer to `AGENTS.md`, so every entry point lands
on the same instructions without duplicating repo guidance.

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

The agent reads `TODO.md`, picks a task that isn't blocked, opens a draft PR, and starts coding. If it needs deeper project context, it reads `BOARD.md`. Another agent can do the same on a different task — no conflicts.

**See what's happening:**
```
> /track:refresh-track
```

Regenerates `BOARD.md`, `TODO.md`, and `PROJECTS.md` with live status from GitHub. Shows who's working on what, what's blocked, what's done, and how projects are progressing.

## How it works

Track has two core layers: **skills** (markdown protocols that teach AI agents the workflow) and **scripts** (bash enforcement that validates state and automates lifecycle events). Git hooks and GitHub workflows are the automation surfaces those scripts power in adopting repos. Together they form a self-enforcing coordination system — agents follow the protocol, scripts verify it, and hooks/workflows keep Git state in sync.

### The `.track/` folder

Everything lives in a `.track/` folder at the root of your repo:

```
.track/
  projects/        # one file per project (groups related tasks)
  tasks/           # one file per task (the actual units of work)
  plans/           # short-lived investigation and planning notes
  specs/           # durable design and interface docs
  events/          # local JSONL activity log written by hooks
  scripts/         # bash enforcement scripts (validation, views, PR lifecycle)
```

### Task files

Each task is a markdown file with YAML frontmatter. This is the core data model:

```yaml
---
id: "1.3"
title: Add user authentication
status: todo
mode: implement
priority: high
project_id: "1"
created: 2026-03-15
updated: 2026-03-15
depends_on: ["1.1", "1.2"]
files: [src/auth.ts, src/middleware.ts]
pr:
---

## Context
Why this task exists and what the agent needs to know before starting.

## Acceptance Criteria
- Users can log in with email/password
- Sessions expire after 24 hours

## Notes
Any additional context, decisions, or references.
```

**Key fields:**
- **`id`** — dotted format (`"1.3"` = project 1, task 3). Links task to its project.
- **`status`** — `todo`, `active`, `review`, `blocked`, `done`, or `cancelled`. Agents don't set `done` manually — the post-merge workflow handles it.
- **`mode`** — `investigate` (research/decide), `plan` (design/architect), or `implement` (write code). Tells the agent what kind of work to do.
- **`priority`** — `urgent`, `high`, `medium`, or `low`. Agents pick higher-priority tasks first.
- **`depends_on`** — list of task IDs that must be `done` before this task can start. Agents skip blocked tasks automatically.
- **`files`** — glob patterns for file ownership. This is what prevents multi-agent conflicts — no two active tasks should claim the same files.
- **`pr`** — populated automatically when the task's PR is merged.
- **`blocked_reason` / `cancelled_reason`** — required when `status` is `blocked` or `cancelled`.

### Project files

Projects group related tasks and provide shared context:

```yaml
---
id: "1"
title: "API v2 Migration"
priority: high
status: active
created: 2026-03-15
updated: 2026-03-15
---

## Goal
What this project aims to achieve.

## In Scope
Clear boundaries so agents don't over-build.

## Out Of Scope
Work that belongs elsewhere.

## Candidate Task Seeds
Ideas for tasks that haven't been created yet.
```

### Plan files

When an agent runs an `investigate` or `plan` mode task, it saves findings to `.track/plans/`. Plans have a 7-day auto-expiry — they capture decisions and context for the current work, not permanent documentation.

### Specs, hooks, and event logs

Track keeps durable protocol and design docs in `.track/specs/`. The canonical activity wire format lives in `.track/specs/event-contract.md`.

Track also keeps an append-only local activity log at `.track/events/log.jsonl`. The `commit-msg` hook enforces conventional commits, and the `post-commit` hook writes `track.commit` events. Untracked activity is still recorded — attribution can be added later by linking a branch back to a task.

### Status lifecycle

Status is driven by Git and GitHub, not manual updates:

```
todo ──→ active (draft PR opened) ──→ review (PR marked ready) ──→ done (PR merged)
```

Track distinguishes between **raw status** (the `status:` field in the task file) and **effective status** (derived from raw status + GitHub PR state). An agent sets `status: active` and opens a draft PR. When it marks the PR ready for review, the effective status becomes `review`. When the PR merges, a GitHub Action automatically sets `status: done`, records the PR URL, unblocks dependency-cleared tasks, and refreshes the generated views.

This means status is always accurate — it reflects what actually happened in Git, not what someone remembered to update. Explicit `blocked` tasks remain blocked until the blocking condition is cleared. Untracked activity still lands in the event log even before it is attributed to a task.

### File scope enforcement

The `files:` field is Track's coordination mechanism. When an agent picks a task, it checks that none of its file scopes overlap with any other `active` or `review` task. If there's a conflict, the agent picks a different task.

This is what makes parallel agents safe. Two agents can work on the same repo simultaneously as long as their tasks claim different files. Track's `/track:decompose` command is designed to create tasks with non-overlapping scopes by default.

### Generated views

Track generates three root-level views:

- `TODO.md` — flat execution list of ready, blocked, and recently completed work
- `BOARD.md` — grouped-by-project operational board with dependencies, status, and warnings
- `PROJECTS.md` — high-level project summary with progress bars and status

These files are gitignored and regenerated on demand. Never edit them by hand; edit the task files in `.track/tasks/` instead.

## Best with isolated worktrees

Track works best when each active task gets its own branch. If you run multiple
agents in parallel, give each one its own git worktree rooted at the same repo.

Track assigns non-overlapping files to each task. Separate worktrees give each
agent isolated filesystem state. Together: parallel agents, fewer conflicts,
and clearer PR ownership.

Track still works fine in a single working tree. The branch/worktree pattern is
recommended because it keeps one task, one branch, and one draft PR aligned.

### Recommended workflow

1. Pick one task from `TODO.md`.
2. Create a branch for it. If another agent is already working elsewhere,
   create a dedicated git worktree too.
3. Open a draft PR immediately and put `Track-Task: {id}` on the first line of
   the PR body.
4. Keep one primary task per PR. If you finish a small drive-by task too, add
   `Also-Completed: {id}`.
5. When the PR merges, remove the worktree and pick the next task.

Example parallel-work setup:

```bash
git worktree add ../repo-7.4 -b task/7.4-pr-lint main
cd ../repo-7.4
```

If you only run one agent at a time, you can stay in your current branch and
skip the extra worktree.

## Commands in depth

### `/track:init` — Set up Track in your repo

Scaffolds the entire Track system into your repo: creates `.track/` with all subdirectories, copies enforcement scripts, installs commit hooks, installs four GitHub Actions workflows (validation, PR lint, conventional-commit lint, post-merge completion), updates your `CLAUDE.md` and `AGENTS.md` with the Track-managed protocol block, and adds `BOARD.md`, `TODO.md`, and `PROJECTS.md` to `.gitignore`.

If it finds existing markdown files with TODO lists, roadmaps, or task-like content, it offers to import them as Track tasks — extracting structure, inferring priority and mode, and letting you pick which items to keep. If there's nothing to import, it creates a starter onboarding project to help you migrate from your current tool (Linear, Jira, Notion, or plain notes).

Re-running `/track:init` on an already-initialized repo upgrades in place — refreshing scripts and workflows without overwriting your tasks or projects.

### `/track:work` — Pick a task and start working

The core workflow protocol. Auto-loaded in any repo that has a `.track/` folder.

Reads the current state, picks the highest-priority unblocked task (or resumes one you've already started), creates a branch, opens a draft PR, and begins implementation. The draft PR is what marks the task as `active` — no PR means the task hasn't started.

The agent checks file scopes before starting to ensure no overlap with other in-progress tasks. It reads the task's `## Context` and `## Acceptance Criteria` sections to understand what to build. When the work is ready, it marks the PR ready for review and sets `status: review`.

If a task has `mode: investigate`, the agent researches and saves findings to `.track/plans/` instead of writing code. If `mode: plan`, it produces an implementation plan. Only `mode: implement` tasks result in code changes.

### `/track:create` — Create tasks and projects

Create tasks and projects from plain English. Describe what you want and Track extracts the structure — inferring mode (`investigate`/`plan`/`implement`), priority, dependencies, and file scopes from your description.

Works in three modes: create a project only, create tasks under an existing project, or create both at once. Shows you the extracted structure for confirmation before writing any files. Runs validation after creation to catch errors immediately.

```
> /track:create Add a rate limiter to the API — high priority, needs the auth middleware done first
```

### `/track:decompose` — Break a goal into tasks

Takes a high-level goal and explores your codebase to find natural seams for splitting the work. Identifies module boundaries, relevant files, and dependencies, then proposes a set of tasks with:

- Non-overlapping file scopes (so agents won't conflict)
- Explicit dependencies (foundation before integration)
- Appropriate modes (investigate/plan before implement when the path is uncertain)

Presents the full breakdown as a table and waits for your confirmation before creating any files. Caps at 10 tasks by default — prefers fewer focused tasks over comprehensive coverage.

```
> /track:decompose Add real-time collaboration to the editor
```

### `/track:refresh-track` — Regenerate Track views

Regenerates the Track coordination views: `BOARD.md`, `TODO.md`, and `PROJECTS.md`. Detects your environment (GitHub CLI availability, auth tokens, remote access) and picks the best mode:

- **Full mode** — pulls task state from `origin/main` and live PR data from GitHub for accurate effective status
- **Offline mode** — uses remote task files but skips GitHub API calls
- **Local mode** — uses only the local working tree (for offline work or worktrees)

```
> /track:refresh-track           # auto-detects best mode
> /track:refresh-track --local   # force local-only
```

### `/update-skills` — Update installed Track skills

Refreshes the installed Track skill clone on your machine. This skill also auto-runs at session start in Track repos so users silently pick up new releases when possible.

## GitHub Actions

Track installs four workflows that automate the lifecycle:

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `track-validate.yml` | Every push | Runs validation against all `.track/` files |
| `track-pr-lint.yml` | Pull request | Validates task linkage (PR body, labels, title) and task file existence |
| `conventional-commit-lint.yml` | Pull request | Validates all commits in the PR range against conventional commit format |
| `track-complete.yml` | PR merged | Sets `status: done`, records the PR URL, cascades dependency unblocks, and regenerates Track views |

These workflows close the loop — status stays accurate without anyone remembering to update it. `/track:init` can also apply a GitHub Ruleset that requires `track-validate`, `track-pr-lint`, and `conventional-commit-lint` before merges to `main` or `master`.

## Works everywhere

Track is just markdown + bash + git. You can run it with no AI agent at all, or layer an agent on top.

| Platform | Status |
|---|---|
| No agent | Full support via `.track/` files + bash scripts |
| Installed skills | Full support via installed skills |
| `AGENTS.md`-aware agents | Works via repo-root `AGENTS.md` |

## The bigger vision

If a folder can manage a codebase, why not anything?

Track's protocol is simple enough for any project: book writing, research, home renovation, event planning. A GitHub account and a folder is your project manager. AI agents are the bookkeepers you never had.

## Requirements

| Dependency | Required? | What it's for |
|-----------|-----------|---------------|
| **bash** 3.2+ | Yes | Runs the Track scripts. Already on macOS and Linux. |
| **git** | Yes | Stores Track state in your repo. |
| **gh** (GitHub CLI) | Optional | Enables PR-aware `TODO.md` generation and merge automation. |
| Installed-skill-compatible agent | Optional | Runs Track through installed skills and slash commands. |
| `AGENTS.md`-aware agent | Optional | Uses repo-root `AGENTS.md` instructions. |

## Troubleshooting

**Validation fails?** Run `bash .track/scripts/track-validate.sh` — it tells you exactly what's wrong and where to look.

**Track views are stale?** Run `/track:refresh-track` to regenerate. If you're offline: `bash .track/scripts/track-todo.sh --local --offline`

**"gh not found" or PR status missing?** Install `gh` and run `gh auth login`, then retry.

**An agent is not following Track?** Re-run `/track:init` to refresh the Track-managed block in `AGENTS.md`, then start a fresh agent session.

**Commands not showing up?** Re-run `~/.local/share/agent-skills/track/install.sh` to refresh the skill symlinks, then restart the agent session.

## Roadmap

**Free forever:** Single-repo coordination, all agent platforms, bash scripts, the full protocol.

**Future (Cloud):** Cross-repo dashboards, team analytics, notifications, and multi-repo coordination live in a separate future Cloud product. The OSS repo stays focused on the local protocol: markdown, bash, hooks, and workflows.

## License

MIT

---

*A folder is all you need. Happy tracking.*
