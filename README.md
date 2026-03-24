# Track

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/Hugopeck/track/releases) <!-- x-release-please-version -->

Git-native task coordination for Claude Code.

## The Problem

AI agents are powerful but forgetful. Each session starts cold — no memory of what was planned, what's in progress, or what depends on what. Tasks get duplicated, PRs collide on the same files, and context evaporates between sessions.

Track fixes this with a repo convention, not a product. Markdown files in `.track/` hold state. GitHub PRs drive the lifecycle. Your `CLAUDE.md` teaches every agent the protocol. Nothing to install at runtime, nothing to host, nothing to maintain.

## What It Looks Like

```
> /track:init
```

Track scaffolds your repo: `.track/` directories, bash scripts, CI workflows, and a protocol section in your `CLAUDE.md`. Your repo is now self-coordinating.

```
> /track:decompose Migrate the API layer to v2
```

Track explores your codebase, finds natural module boundaries, and proposes a breakdown — each task with non-overlapping file scopes and dependency ordering. You confirm, it creates the files.

```
> /track:work
```

An agent reads `TODO.md`, picks a task with no blockers, opens a draft PR, and gets to work. Track knows it's active from the PR state. Another agent starts a different task on a different branch — no conflicts, because file scopes don't overlap.

```
> /track:todo
```

One command regenerates the shared view. It pulls live PR state from GitHub. `TODO.md` is always current — who's working on what, what's blocked, what's done.

## Install

```bash
claude plugin install hugopeck/track
```

Or test locally:

```bash
claude --plugin-dir ./path/to/track
```

## Skills

| Skill | Purpose |
|-------|---------|
| `/track:init` | Set up Track from scratch — scaffold everything, create a first project |
| `/track:work` | The operating protocol — auto-loaded when `.track/` exists |
| `/track:create` | Create tasks and projects from natural language |
| `/track:decompose` | Break a goal into parallelizable tasks with dependencies |
| `/track:validate` | Run validation and get actionable fix suggestions |
| `/track:todo` | Regenerate the shared coordination view |

## How It Works

```
.track/
  projects/       # scope contracts — one per initiative
  tasks/           # flat task files — one per unit of work
```

Every task is a markdown file with YAML frontmatter (`id`, `title`, `status`, `mode`, `priority`, `project_id`, `depends_on`, `files`) and body sections (`## Context`, `## Acceptance Criteria`, `## Notes`).

Status flows through the PR lifecycle:

```
todo  ──→  active (draft PR)  ──→  review (ready PR)  ──→  done (merged)
```

The **raw status** is what's in the file. The **effective status** layers GitHub PR state on top. `TODO.md` shows effective status — no manual updates needed.

## Design Philosophy

- **Git is the database** — `.track/` files are the source of truth, versioned with your code
- **PRs are the workflow** — draft/ready/merged drives status automatically
- **Convention over configuration** — file naming, branch patterns, and YAML frontmatter are the API
- **Zero dependencies** — bash 3.2+ and git; `gh` is optional for PR-aware features
- **Self-contained repos** — the plugin teaches the protocol; adopting repos run independently

## Troubleshooting

**Validation fails after creating tasks?** Run `/track:validate` — error messages include the exact fix needed.

**TODO.md is stale or missing?** Regenerate with `bash scripts/track-todo.sh --local --offline` if you don't have `gh` or network access.

**"gh not found" warnings?** The GitHub CLI is optional. Track works without it — you lose PR-aware effective status and CI PR checks, but everything else works. Use `--offline` flags.

**Skills not showing up?** Reinstall the plugin or run `claude --plugin-dir ./path/to/track` to test locally.

## Requirements

- **bash** 3.2+ (ships with macOS and Linux)
- **git**
- **gh** (GitHub CLI) — optional, enables PR-aware status and CI validation

## License

MIT
