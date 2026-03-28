# Track

**Project management tools are dead. A folder is all you need.**

[![Version](https://img.shields.io/github/v/release/Hugopeck/track)](https://github.com/Hugopeck/track/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-blueviolet)](#install--30-seconds)
[![Cursor](https://img.shields.io/badge/Cursor-plugin-blue)](#install--30-seconds)
[![OpenCode](https://img.shields.io/badge/OpenCode-supported-black)](#opencode)
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
| Agent support | Linear Agent only | Claude Code, Cursor, Codex CLI, OpenCode |
| Data ownership | Their servers | Your repo |
| Non-code projects | No | Yes — any folder, any project |

## Install — 30 seconds

Requirements: Git and bash 3.2+. Claude Code, Cursor, Codex CLI, and OpenCode are optional integrations.

**Step 1: Install on your machine**

Open a workspace in [Conductor](https://conductor.lol) and paste this prompt if you want the Claude Code path. Claude does the rest.

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

This creates `.track/`, adds bash scripts, installs GitHub Actions workflows, updates your `CLAUDE.md`, and installs a Track-managed block in `AGENTS.md` for Codex CLI. If it finds existing markdown TODOs or roadmaps, you can import them as Track tasks. If you initialized before v2.0.0, re-run `/track:init` to migrate legacy root `scripts/` into `.track/scripts/` and add `.track/plans/`.

That's it — you're tracking.

## Works without any AI agent

Track is a protocol, not a plugin. If you do not use Claude Code, Cursor, Codex CLI, or OpenCode, you can still run Track with plain git + bash.

**1. Copy the repo files you need**

Create this structure at the root of your repo:

```
.track/
  projects/
  tasks/
  plans/
  scripts/
```

Copy these scripts from this repo into `.track/scripts/`:

```
track-common.sh
track-validate.sh
track-todo.sh
track-pr-lint.sh
track-complete.sh
```

If you want the same CI automation, also copy the Track GitHub Actions workflows from `.github/workflows/`.

**2. Create projects and tasks manually**

A project file is plain markdown in `.track/projects/`:

```markdown
# API Migration

## Goal
Move the API layer to v2 without breaking existing clients.

## Why Now
The current version blocks the new billing flow.
```

A task file lives in `.track/tasks/` and uses YAML frontmatter plus markdown sections:

```yaml
---
id: "1.1"
title: "Add v2 auth middleware"
status: todo
mode: implement
priority: high
project_id: "1"
created: 2026-03-28
updated: 2026-03-28
depends_on: []
files:
  - "src/auth.ts"
  - "src/middleware.ts"
pr: ""
---

## Context
Add the v2 authentication path used by billing endpoints.

## Acceptance Criteria
- [ ] Requests can authenticate through the new middleware
- [ ] Existing v1 routes keep working during the migration
```

**3. Use the scripts directly**

```bash
# Validate task and project files
bash .track/scripts/track-validate.sh

# Generate TODO.md from your local tree only
bash .track/scripts/track-todo.sh --local --offline

# Generate TODO.md with remote/main and live PR data
bash .track/scripts/track-todo.sh
```

Use `--local` or `--offline` when you are not using GitHub PR state. `gh` is only needed for the full PR-aware mode.

**4. Run the workflow manually**

- Create and edit files in `.track/projects/` and `.track/tasks/` yourself
- Run `bash .track/scripts/track-validate.sh` before committing
- Regenerate `TODO.md` with `bash .track/scripts/track-todo.sh --local --offline`
- Open pull requests only if you want PR-linked status automation

The agent integrations are convenience layers on top of these files and scripts — not a requirement to use Track.

## OpenCode

Track's OpenCode setup is intentionally minimal: keep the shared workflow in a repo-root `AGENTS.md`, then use `opencode.json` only for any extra repo-specific instruction files.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["CLAUDE.md"]
}
```

1. Initialize Track in the repo using the standard setup path so `.track/` and the scripts exist.
2. Commit `AGENTS.md` at the repo root with the shared Track workflow.
3. Commit `opencode.json` at the repo root to load any extra repo-specific guidance.
4. Open the repo in OpenCode.

OpenCode will read `AGENTS.md` automatically, merge the extra files listed in `opencode.json`, and then work against the same `.track/` files and bash scripts used by Claude Code. This support is launch-scoped on purpose: it adds repo instructions and config, not a second OpenCode-only command system.

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
> /track:todo
```

Regenerates `BOARD.md`, `TODO.md`, and `PROJECTS.md` with live status from GitHub. Shows who's working on what, what's blocked, what's done, and how projects are progressing.

## How it works

Track has two layers: **skills** (markdown protocols that teach AI agents the workflow) and **scripts** (bash enforcement that validates state and automates lifecycle events). Together they form a self-enforcing coordination system — agents follow the protocol, scripts verify they did it right.

### The `.track/` folder

Everything lives in a `.track/` folder at the root of your repo:

```
.track/
  projects/       # one file per project (groups related tasks)
  tasks/           # one file per task (the actual units of work)
  plans/           # plan files produced during investigation tasks
  scripts/         # bash enforcement scripts (validation, TODO generation, PR lint)
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
- **`status`** — `todo`, `active`, `review`, `done`, or `cancelled`. Agents don't set `done` manually — the post-merge workflow handles it.
- **`mode`** — `investigate` (research/decide), `plan` (design/architect), or `implement` (write code). Tells the agent what kind of work to do.
- **`priority`** — `urgent`, `high`, `medium`, or `low`. Agents pick higher-priority tasks first.
- **`depends_on`** — list of task IDs that must be `done` before this task can start. Agents skip blocked tasks automatically.
- **`files`** — glob patterns for file ownership. This is what prevents multi-agent conflicts — no two active tasks should claim the same files.
- **`pr`** — populated automatically when the task's PR is merged.

### Project files

Projects group related tasks and provide shared context:

```yaml
---
id: "1"
name: API v2 Migration
slug: api-v2-migration
status: active
---

## Goal
What this project aims to achieve.

## In Scope / Out Of Scope
Clear boundaries so agents don't over-build.

## Candidate Task Seeds
Ideas for tasks that haven't been created yet.
```

### Plan files

When an agent runs an `investigate` or `plan` mode task, it saves findings to `.track/plans/`. Plans have a 7-day auto-expiry — they capture decisions and context for the current work, not permanent documentation.

### Status lifecycle

Status is driven by Git and GitHub, not manual updates:

```
todo ──→ active (draft PR opened) ──→ review (PR marked ready) ──→ done (PR merged)
```

Track distinguishes between **raw status** (the `status:` field in the task file) and **effective status** (derived from raw status + GitHub PR state). An agent sets `status: active` and opens a draft PR. When it marks the PR ready for review, the effective status becomes `review`. When the PR merges, a GitHub Action automatically sets `status: done` and records the PR URL.

This means status is always accurate — it reflects what actually happened in Git, not what someone remembered to update.

### File scope enforcement

The `files:` field is Track's coordination mechanism. When an agent picks a task, it checks that none of its file scopes overlap with any other `active` or `review` task. If there's a conflict, the agent picks a different task.

This is what makes parallel agents safe. Two agents can work on the same repo simultaneously as long as their tasks claim different files. Track's `/track:decompose` command is designed to create tasks with non-overlapping scopes by default.

### Generated views

Track generates three root-level views:

- `TODO.md` — flat execution list of ready, blocked, and recently completed work
- `BOARD.md` — grouped-by-project operational board with dependencies, status, and warnings
- `PROJECTS.md` — high-level project summary with progress bars and status

These files are gitignored and regenerated on demand. Never edit them by hand; edit the task files in `.track/tasks/` instead.

## Best with Conductor

Track is designed to work with [Conductor](https://conductor.lol) — a Mac app that lets you run many Claude Code agents in parallel, each in its own git worktree.

Track assigns non-overlapping files to each task. Conductor gives each agent an isolated copy of the repo. Together: parallel agents, zero conflicts.

Track works without Conductor too — you can run agents one at a time and still get persistent task state and generated view tracking.

### Recommended Conductor Git preferences

If you use Conductor, Track works best when you also fill in the repo-local Git
preferences under Settings → Git for that repo.

These settings are optional, but strongly recommended. They reinforce Track's
PR linkage contract earlier in the workflow so the agent includes task metadata
from the start instead of relying on CI or post-hoc correction.

These prompts live in the Conductor UI — not in `conductor.json`. Track keeps
`conductor.json` limited to repo-tracked script configuration and treats these
preferences as app-local setup.

Canonical copy lives at `skills/init/scaffold/conductor-git-preferences.md`.
Use the exact text below for copy/paste.

#### Create PR preferences

```text
Read `TODO.md`, `BOARD.md`, `.track/tasks/`, and `CLAUDE.md` first.

- Identify the primary Track task in this PR before writing anything.
- Identify any additional fully completed tasks that belong in this PR.
- Use one primary task per PR.
- Use the required conventional-commit title format from `CLAUDE.md`: `type(scope): description`.
- Include the primary task ID in the title as `[id]` or `(id)`, for example: `feat(scripts): [7.4] support explicit multi-task PR batching`.
- Always put `Track-Task: {id}` on the first line of the PR body. This is the primary linkage mechanism.
- For any other fully completed task, add `Also-Completed: {id}` lines, max 2.
- Never use multiple primary `Track-Task:` lines.
- After linkage lines, keep the body to `## Summary` and `## Test plan`.
- If task linkage is unclear, stop and ask instead of guessing.
```

## Commands in depth

### `/track:init` — Set up Track in your repo

Scaffolds the entire Track system into your repo: creates `.track/` with all subdirectories, copies enforcement scripts, installs three GitHub Actions workflows (validation, PR lint, post-merge completion), updates your `CLAUDE.md` with the agent protocol, installs the Track protocol into `AGENTS.md` for Codex CLI, and adds `BOARD.md`, `TODO.md`, and `PROJECTS.md` to `.gitignore`.

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

### `/track:validate` — Check for errors

Runs the validation script against all task and project files. Checks required fields, valid statuses, project references, dependency chains, and required markdown sections. For each error, it reads the offending file and explains exactly what's wrong and how to fix it.

This is a diagnostic-only command — it reads and reports but doesn't modify files.

### `/track:todo` — Regenerate Track views

Regenerates the Track coordination views: `BOARD.md`, `TODO.md`, and `PROJECTS.md`. Detects your environment (GitHub CLI availability, auth tokens, remote access) and picks the best mode:

- **Full mode** — pulls task state from `origin/main` and live PR data from GitHub for accurate effective status
- **Offline mode** — uses remote task files but skips GitHub API calls
- **Local mode** — uses only the local working tree (for offline work or worktrees)

```
> /track:todo           # auto-detects best mode
> /track:todo --local   # force local-only
```

### `/track:test` — Run the test suite

Internal test orchestration for Track development. Runs script-level tests, headless skill smoke tests (in isolated git worktrees), or both. Classifies failures into semantic buckets (`environment`, `fixture-drift`, `protocol-regression`, `script-regression`, etc.) with concrete next-fix suggestions.

## GitHub Actions

Track installs three workflows that automate the lifecycle:

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `track-validate.yml` | Every push | Runs validation against all `.track/` files |
| `track-pr-lint.yml` | Pull request | Validates task linkage (PR body, labels, title) and task file existence |
| `track-complete.yml` | PR merged | Sets `status: done`, records the PR URL, updates the date |

These workflows close the loop — status stays accurate without anyone remembering to update it.

## Works everywhere

Track is just markdown + bash + git. You can run it with no AI agent at all, or layer an agent on top.

| Platform | Status |
|---|---|
| No agent | Full support via `.track/` files + bash scripts |
| Claude Code | Full plugin support |
| Cursor | Plugin available |
| Codex CLI | Works via `AGENTS.md` |
| OpenCode | Works via `AGENTS.md` + `opencode.json` |

## The bigger vision

If a folder can manage a codebase, why not anything?

Track's protocol is simple enough for any project: book writing, research, home renovation, event planning. A GitHub account and a folder is your project manager. AI agents are the bookkeepers you never had.

## Requirements

| Dependency | Required? | What it's for |
|-----------|-----------|---------------|
| **bash** 3.2+ | Yes | Runs the Track scripts. Already on macOS and Linux. |
| **git** | Yes | Stores Track state in your repo. |
| **gh** (GitHub CLI) | Optional | Enables PR-aware `TODO.md` generation and merge automation. |
| **Claude Code** | Optional | Runs Track through the Claude plugin and slash commands. |
| **Cursor** | Optional | Uses the Cursor plugin path. |
| **Codex CLI** | Optional | Uses repo-root `AGENTS.md` instructions. |
| **OpenCode** | Optional | Uses repo-root `AGENTS.md` plus `opencode.json`. |

## Troubleshooting

**Validation fails?** Run `/track:validate` — it tells you exactly what's wrong and how to fix it.

**Track views are stale?** Run `/track:todo` to regenerate. If you're offline: `bash .track/scripts/track-todo.sh --local --offline`

**"gh not found" or PR status missing?** Install `gh` and run `gh auth login`, then retry.

**Codex CLI is not following Track?** Re-run `/track:init` to refresh the Track-managed block in `AGENTS.md`.

**Commands not showing up?** Reinstall the plugin or try `claude --plugin-dir ./path/to/track` to test locally.

## Roadmap

**Free forever:** Single-repo coordination, all agent platforms, bash scripts, the full protocol.

**Coming (Track Pro):** Cross-repo dashboards, team analytics, Slack notifications, audit trails.

**Coming (Track for Teams):** Approval workflows, permissions, compliance reporting.

## License

MIT

---

*A folder is all you need. Happy tracking.*
