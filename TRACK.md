## Track — Task Coordination

Track is a git-native coordination protocol. It is the source of truth for task state, task ownership, and task history. Track runs as markdown task files, bash scripts, git hooks, and GitHub workflows — no server, no binary, no always-on runtime.

Projects, tasks, plans, specs, and activity logs live in `.track/`. `TODO.md` is the generated shared view of current work.

### Layout
- `.track/projects/{project_id}-{slug}.md` — project briefs
- `.track/tasks/{task_id}-{slug}.md` — flat task files
- `.track/plans/{slug}.md` — short-lived plan documents (auto-expire after 7 days)
- `.track/specs/{slug}.md` — durable architecture, design, and interface specs
- `.track/events/log.jsonl` — append-only activity log written by hooks and lifecycle actions
- `.track/scripts/` — bash enforcement scripts (managed by Track)
- `TODO.md` — generated view; gitignored and never canonical

### Task Format

```yaml
---
id: "{project_id}.{task_id}"
title: "One-line objective"
status: todo
mode: implement
priority: high
project_id: "{project_id}"
created: YYYY-MM-DD
updated: YYYY-MM-DD
depends_on: []
files: []
pr: ""
---

## Context
What needs to happen and why.

## Acceptance Criteria
- [ ] Primary outcome

## Notes
Append-only log.
```

### Fields
- `status`: `todo | active | review | blocked | done | cancelled`
- `mode`: `investigate | plan | implement`
- `priority`: `urgent | high | medium | low`
- `project_id`: filename-derived project identifier from `.track/projects/`
- `depends_on`: blocking task IDs
- `files`: glob patterns for files the task expects to modify
- `pr`: optional on raw task files; populated on `done` for historical traceability
- `cancelled_reason`: required when `status: cancelled`
- `blocked_reason`: required when `status: blocked`

### Raw vs Effective Status
- Raw status is the `status:` field stored in the task file
- Effective status is what `TODO.md` shows
- If raw status is `done` or `cancelled`, effective status matches it
- If raw status is `blocked`, effective status is `blocked` (skips PR overlay)
- Otherwise, an open draft PR linked by `Track-Task`, `track:{id}`, title ID, or `task/{id}-{slug}` makes the task effectively `active`
- Otherwise, an open ready-for-review PR linked by `Track-Task`, `track:{id}`, title ID, or `task/{id}-{slug}` makes the task effectively `review`
- Otherwise, effective status is `todo`

### Event Log and Attribution
- Track writes append-only activity events to `.track/events/log.jsonl`
- The wire format is defined in `.track/specs/event-contract.md`
- Core event types are `track.commit`, `track.pr.opened`, `track.pr.ready`, `track.pr.merged`, `track.task.started`, and `track.link`
- Untracked activity is first-class: an event may exist before it has a task attribution
- If work happened outside the normal task branch flow, ask `/track:work` to link the current branch to a task; this appends a `track.link` event for retroactive attribution

### Hooks and Automation
- `commit-msg` enforces conventional commit format locally
- `post-commit` writes `track.commit` events to the JSONL activity log and never blocks the commit
- GitHub workflows validate task linkage, lint PR commit history, complete merged tasks, cascade dependency unblocks, and regenerate Track views
- `/track:init` can also apply a GitHub Ruleset that requires `track-validate`, `track-pr-lint`, and `conventional-commit-lint`
- Default allowed commit types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`, `perf`, `style`, `build`, `revert`. Override per-repo via `.track/config.yml`:
  ```yaml
  commit_types:
    - feat
    - fix
    - custom-type
  ```

### Agent Protocol (primary)

1. Read `TODO.md` for the execution queue and `BOARD.md` for project context. Pick a `todo` task or resume an `active` one.
2. Check `files:` overlap against tasks already shown as `active` / `review` — do not touch files owned by another in-progress task.
3. Create a branch or use the current one.
4. Open a **draft PR** to start work. No PR = not started.
5. Prefer a PR title that includes the task ID: `[{id}] Title` or `({id}) Title`.
6. Always add `Track-Task: {id}` to the PR body. This is the primary linkage. Optional label: `track:{id}`.
7. If the PR also completes another small task as a drive-by, add `Also-Completed: {id}` to the PR body. On merge, Track marks those tasks done too.
8. If `gh` auth fails or PR creation fails, **stop and surface the error.**
9. Implement. When ready, mark the PR ready for review.

`BOARD.md`, `TODO.md`, and `PROJECTS.md` are generated — edit task files in `.track/tasks/`, not the generated views directly.

`/track:work` contains the full protocol with edge cases. Use it when this section is insufficient.

### Starting Work (details)
1. Read the task's `## Context` and `## Notes` — previous sessions may have left important context
2. Pick work that has no unresolved `depends_on` blockers
3. If the task's mode is `investigate` or `plan`, focus on understanding and documenting findings before writing implementation code
4. If acceptance criteria seem incomplete, update them before starting
5. Use a dedicated worktree or branch per task when possible

### Working a Task (Provisional PR lifecycle)
1. Create a branch from `main` (or use the current branch)
2. First commit updates the task file only:
   - set raw `status: active`
   - update `updated:`
3. Push and open a **draft PR** immediately
   - Always include `Track-Task: {id}` on the first line of the PR body
   - PR title must include the task ID: `[4.1] Title` or `feat(scope): (4.1) Title`
   - Optional label: `track:{id}`
   - CI resolves the task from body, labels, title, then branch name
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - set raw `status: review`
   - update `updated:`
   - mark the PR ready for review
6. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on `main`, unblocks newly-cleared dependency tasks, and regenerates Track views

Example PR linkage:

```text
Branch: any-branch-name
Title: feat(skills): [7.2] refine refresh-track skill
Body: Track-Task: 7.2
```

Example drive-by completion (primary task 7.1, also resolved 7.2):

```text
Branch: task/7.1-test-runner
Title: feat(tests): [7.1] unified test runner
Body:
Track-Task: 7.1
Also-Completed: 7.2
```

### Worktree Workflow

Track works best when each active task gets its own branch. For parallel agents, give each one its own git worktree:

```bash
git worktree add ../repo-7.4 -b task/7.4-pr-lint main
cd ../repo-7.4
```

Track assigns non-overlapping `files:` scopes to each task. Separate worktrees give each agent isolated filesystem state. Together: parallel agents, fewer conflicts, clearer PR ownership.

A single working tree is fine for serial work. The worktree pattern is recommended when running multiple agents simultaneously.

### Creating a Task
- Every task belongs to a project and uses `project_id`
- Open work must use dotted IDs like `1.1`
- Put scope and success definition in the project brief, not the task

### Decomposing a Goal
- Analyze module boundaries first
- Create one task per independent unit with non-overlapping `files:` scopes
- Use `depends_on` to sequence foundation work before integration work
- Prefer small reviewable PRs over multi-goal tasks

### Saving Plans
When any planning, investigation, or design work produces a plan, **automatically save it** to `.track/plans/`. Do not wait for the user to ask — persistence is the default.
- Filename: `{task_id}-{slug}.md` when linked to a task, or `{slug}.md` otherwise
- Add YAML frontmatter with `title`, `created` (today's date), and optionally `task_id`/`project_id`
- The body is freeform — paste the plan content as-is, no reformatting needed
- Plans auto-expire 7 days after `created`; update the date to keep one longer

### Writing Specs
Save durable architecture docs, design references, and interface contracts to `.track/specs/`.
- Filename: `{slug}.md` in lowercase, hyphenated form
- Add YAML frontmatter with `title`, `status`, `created`, `updated`, and optionally `task_id`/`project_id`
- `status` should be `draft`, `approved`, or `superseded`
- Specs do not auto-expire; if a newer spec replaces one, keep the old file and mark it `superseded`

### Regenerating `TODO.md`
After creating, updating, cancelling, or completing tasks, regenerate the shared view:

```shell
bash .track/scripts/track-todo.sh
```

Useful modes:

```shell
bash .track/scripts/track-todo.sh --local
bash .track/scripts/track-todo.sh --offline
```

### Validation
Run Track validation after changing task files, project briefs, or task lifecycle scripts:

```shell
bash .track/scripts/track-validate.sh
```

### Working Principles

- **Investigate before implementing.** When a task has mode `investigate` or `plan`, explore the codebase thoroughly before writing code. Read related files, check for existing patterns, understand dependencies. Only move to implementation when you have a clear path.
- **Update task files as you work, not after.** When you discover new context, constraints, or dead ends, append to the task's `## Notes` immediately. Future sessions depend on this context.
- **Check for conflicts before starting.** Scan active and review tasks for overlapping `files:` globs. Starting work on contested files creates merge conflicts.
- **Scope aggressively.** If a task grows beyond its acceptance criteria, split the new work into a separate task rather than expanding the current one.
- **Let the PR lifecycle drive status.** Open a draft PR — and set `status: active` in the task file. Mark it ready for review — and set `status: review`. The post-merge workflow handles `status: done` automatically. CI enforces these match.
- **Validate early and often.** Run `bash .track/scripts/track-validate.sh` after every task file change. Errors caught locally are cheap; errors caught in CI block the team.

### Troubleshooting

**Validation fails?** Run `bash .track/scripts/track-validate.sh` — it tells you exactly what's wrong and where to look.

**Track views are stale?** Run `bash .track/scripts/track-todo.sh` to regenerate. If you're offline: `bash .track/scripts/track-todo.sh --local --offline`

**"gh not found" or PR status missing?** Install `gh` and run `gh auth login`, then retry.

**An agent is not following Track?** Re-run `/track:init` to refresh the Track-managed block in `AGENTS.md`, then start a fresh agent session.

**Commands not showing up?** Re-run `~/.local/share/agent-skills/track/install.sh` to refresh the skill symlinks, then restart the agent session.
