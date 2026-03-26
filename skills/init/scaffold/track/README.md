# Track

Track is a git-native task coordination system. It has zero dependencies beyond bash, git, and optionally the GitHub CLI (`gh`). All state lives in plain markdown files inside this directory.

## How It Works

```
.track/
  projects/       # project briefs — one per initiative
    0-archive.md
    4-track-skill-pack-launch.md
    ...
  tasks/           # flat task files — one per unit of work
    4.1-rewrite-existing-skills-for-pure-skill-pack.md
    4.2-create-coordination-skills.md
    ...
  plans/           # short-lived plan documents (auto-expire after 7 days)
    1.1-migration-plan.md
    ...
  scripts/         # bash enforcement scripts (managed by Track)
    track-common.sh
    track-validate.sh
    track-todo.sh
    track-pr-lint.sh
    track-complete.sh
```

Every task belongs to a project. The connection is a `project_id` field in the task's YAML frontmatter that matches the number prefix of a project brief filename.

There is no database. The `.track/` directory *is* the database. Git history *is* the audit log.

## Task Files

Each task is a markdown file with YAML frontmatter at the top:

```yaml
---
id: "4.1"
title: "Rewrite existing skills for pure skill pack"
status: todo
mode: implement
priority: high
project_id: "4"
created: 2026-03-20
updated: 2026-03-24
depends_on: []
files:
  - ".claude/skills/**"
pr: ""
---

## Context
What needs to happen and why.

## Acceptance Criteria
- [ ] Primary outcome

## Notes
Append-only log of decisions and updates.
```

### Fields

| Field | Values | Purpose |
|-------|--------|---------|
| `id` | `{project}.{task}` (e.g. `4.1`) | Unique identifier. The number before the dot must match `project_id`. |
| `title` | Free text | One-line objective. |
| `status` | `todo`, `active`, `review`, `done`, `cancelled` | Where the task is in its lifecycle. |
| `mode` | `investigate`, `plan`, `implement` | What kind of work this is. |
| `priority` | `urgent`, `high`, `medium`, `low` | Relative importance. |
| `project_id` | Number string (e.g. `"4"`) | Which project this belongs to. Must match a brief in `projects/`. |
| `created` | `YYYY-MM-DD` | When the task was created. |
| `updated` | `YYYY-MM-DD` | Last modification date. |
| `depends_on` | List of task IDs | Tasks that must be `done` before this one can start. |
| `files` | List of glob patterns | Files this task expects to touch. Used for overlap detection. |
| `pr` | URL string | Populated when the task is completed via a merged PR. |
| `cancelled_reason` | Free text | Required when `status: cancelled`. |

### Raw Status vs Effective Status

The `status` field in the file is the **raw status**. What shows up in `TODO.md` is the **effective status**, which layers GitHub PR state on top:

1. If raw status is `done` or `cancelled` → effective status matches it (terminal, nothing overrides)
2. If there's an open **draft** PR on branch `task/{id}-{slug}` → effective status is `active`
3. If there's an open **ready-for-review** PR on that branch → effective status is `review`
4. Otherwise → effective status is `todo`

This means you don't manually set `status: active` to show progress — opening a draft PR does it automatically.

## Project Briefs

Project briefs live in `projects/` and define scope for a group of tasks. See [`projects/README.md`](projects/README.md) for the full contract. Key points:

- Filename: `{project_id}-{slug}.md` (e.g. `4-track-skill-pack-launch.md`)
- No YAML frontmatter — just markdown with required sections
- `0-archive.md` is reserved for legacy/archived work

## Plans

Plans are short-lived reference documents that capture decisions, approaches, and context from investigation or planning work. See [`plans/README.md`](plans/README.md) for the full contract. Key points:

- Filename: `{slug}.md` or `{task_id}-{slug}.md` when linked to a task
- Minimal YAML frontmatter (`title`, `created`, optional `task_id`/`project_id`) + freeform body
- Auto-expire **7 days** after `created` date — validation deletes expired plans
- The body is intentionally unstructured — paste whatever plan content you have

## Branching Convention

Every task gets its own branch:

```
task/{id}-{slug}
```

Examples: `task/4.1-rewrite-skills`, `task/2.2-measure-determinism`

This naming convention is what connects a PR to a task. The scripts parse the branch name to extract the task ID.

## Scripts

Bash scripts in `scripts/` enforce Track conventions. See [`scripts/README.md`](scripts/README.md) for a quick reference. These are managed by Track — do not edit them directly.

### `track-common.sh` — Shared Library

Not meant to be run directly. Contains helper functions used by the other three scripts:

- YAML frontmatter parser for task files
- Priority and status ranking functions
- Glob overlap detection (checks if two tasks touch the same files)
- Project brief metadata extraction

### `track-todo.sh` — Generate TODO.md

Reads all projects and tasks, queries GitHub for open PRs, and writes a sorted markdown summary to `TODO.md`.

```bash
bash .track/scripts/track-todo.sh            # default: reads from origin/main + live PR data
bash .track/scripts/track-todo.sh --local    # reads from your local working tree instead
bash .track/scripts/track-todo.sh --offline  # skips GitHub PR lookup
bash .track/scripts/track-todo.sh --output path/to/file.md
```

`TODO.md` is gitignored — it's a convenience view, not canonical state.

### `track-validate.sh` — Validate Track State

Checks every task file for structural correctness:

- All required frontmatter fields present
- Valid values for `status`, `mode`, `priority`
- `project_id` matches an existing project brief
- Dotted IDs match their `project_id` (e.g. `4.1` must have `project_id: "4"`)
- No duplicate task IDs
- No self-referencing `depends_on`
- Active/review tasks don't depend on incomplete tasks
- Open PRs point to real, non-terminal tasks
- In CI pull request context: validates branch name matches task, draft state matches raw status

```bash
bash .track/scripts/track-validate.sh
```

Runs in CI on every push and PR.

### `track-pr-lint.sh` — PR Branch and Title Linter

Runs in CI on pull requests. Validates that `task/*` branches follow naming conventions and PR titles include the task ID.

Checks:
- Branch matches `task/{project}.{task}-{slug}` exactly
- A task file exists for the branch's task ID
- The branch slug matches the task file slug (warns if not)
- PR title includes the task ID in brackets or parentheses (e.g. `[4.1] ...`)

Non-task branches are ignored — the check passes automatically.

```bash
# Usually run by CI, but you can test locally:
GITHUB_HEAD_REF="task/4.1-rewrite-skills" PR_TITLE="[4.1] Rewrite skills" bash .track/scripts/track-pr-lint.sh
```

### `track-complete.sh` — Post-Merge Completion

Called by the GitHub Actions workflow after a task branch merges into `main`. It:

1. Extracts the task ID from the merged branch name
2. Finds the matching task file
3. Sets `status: done`, updates `updated:`, and writes the `pr:` URL

```bash
bash .track/scripts/track-complete.sh "task/4.1-rewrite-skills" "https://github.com/org/repo/pull/42"
```

You never run this manually — the `.github/workflows/track-complete.yml` workflow calls it.

## Workflow Summary

```
  Create task file         Open draft PR           Mark ready for review      PR merges
  in .track/tasks/    →    on task/{id}-{slug}  →  (undraft the PR)       →  track-complete.sh
  status: todo             effective: active        effective: review          status: done
```

## Requirements

- **bash** (version 3.2+, ships with macOS)
- **git** (for reading state from `origin/main`)
- **gh** (GitHub CLI, optional) — needed for PR-aware status in `track-todo.sh` and PR validation in `track-validate.sh`. Falls back gracefully if missing.
- **GH_TOKEN** or **GITHUB_TOKEN** environment variable — needed for `gh` to authenticate. Scripts fall back to offline mode if unset.

## Limitations

- No web UI, no dashboard — `TODO.md` is the only view
- Parallel arrays in bash mean the scripts get unwieldy past ~50-60 tasks (performance is fine, readability isn't)
- Glob overlap detection is approximate — it compares path prefixes, not full glob semantics
- One PR per task only — if multiple open PRs map to the same task ID, it's flagged as a warning
- Branch names must follow `task/{id}-{slug}` exactly or the PR won't be linked
