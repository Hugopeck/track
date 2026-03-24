# Claude Code Instructions

## Project Context

This is the Track plugin repo. Track is a git-native task coordination system distributed as a Claude Code plugin.

## Key Files

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/init/SKILL.md` — `/track:init` scaffolding skill
- `skills/init/scaffold/` — files copied into adopting repos
- `skills/work/SKILL.md` — `/track:work` core workflow protocol
- `skills/create/SKILL.md` — `/track:create` task/project creation
- `skills/validate/SKILL.md` — `/track:validate` wrapper
- `skills/todo/SKILL.md` — `/track:todo` wrapper
- `skills/decompose/SKILL.md` — `/track:decompose` goal breakdown
- `tests/` — bash test scripts and fixtures

## Workflow

- No build step, no runtime — this is a plugin made of markdown and bash
- Edit skills in `skills/`, test with `claude --plugin-dir .`
- Scaffold content in `skills/init/scaffold/` is what gets copied into adopting repos
- Run `/reload-plugins` after editing skills to pick up changes
- Use conventional commits: `feat(skills):`, `fix(scripts):`, `docs:`

## Important Context

- Track was extracted from the Archeia monorepo
- Adopting repos are self-contained — they never depend on this plugin at runtime
- The plugin teaches Claude the Track protocol; the scripts enforce it
- The CLAUDE.md section appended by `/track:init` is the minimal contract; `/track:work` is the full operational guide

## Track — Task Coordination

Projects and tasks live in `.track/`. `TODO.md` is the generated shared view of current work.

### Layout
- `.track/projects/{project_id}-{slug}.md` — project briefs
- `.track/tasks/{task_id}-{slug}.md` — flat task files
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
- `status`: `todo | active | review | done | cancelled`
- `mode`: `investigate | plan | implement`
- `priority`: `urgent | high | medium | low`
- `project_id`: filename-derived project identifier from `.track/projects/`
- `depends_on`: blocking task IDs
- `files`: glob patterns for files the task expects to modify
- `pr`: optional on raw task files; populated on `done` for historical traceability
- `cancelled_reason`: required when `status: cancelled`

### Raw vs Effective Status
- Raw status is the `status:` field stored in the task file
- Effective status is what `TODO.md` shows
- If raw status is `done` or `cancelled`, effective status matches it
- Otherwise, an open draft PR for `task/{id}-{slug}` makes the task effectively `active`
- Otherwise, an open ready-for-review PR for `task/{id}-{slug}` makes the task effectively `review`
- Otherwise, effective status is `todo`

### Before Starting Work
1. Read `TODO.md` or scan `.track/tasks/*.md`
2. Check `files:` overlap against tasks already shown as `active` / `review`
3. Pick work that has no unresolved `depends_on` blockers
4. Use a dedicated worktree or branch per task

### Working a Task (Provisional PR lifecycle)
1. Create branch `task/{id}-{slug}` from `main`
2. First commit updates the task file only:
   - set raw `status: active`
   - update `updated:`
3. Push and open a **draft PR** immediately
   - PR title must include the task ID in brackets or parentheses: `[4.1] Title` or `feat(scope): (4.1) Title`
   - CI will lint the branch name and PR title against the task file
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - set raw `status: review`
   - update `updated:`
   - mark the PR ready for review
6. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on `main`

### Creating a Task
- Every task belongs to a project and uses `project_id`
- Open work must use dotted IDs like `1.1`
- Put scope and success definition in the project brief, not the task

### Decomposing a Goal
- Analyze module boundaries first
- Create one task per independent unit with non-overlapping `files:` scopes
- Use `depends_on` to sequence foundation work before integration work
- Prefer small reviewable PRs over multi-goal tasks

### Regenerating `TODO.md`
After creating, updating, cancelling, or completing tasks, regenerate the shared view:

```shell
bash scripts/track-todo.sh
```

Useful modes:

```shell
bash scripts/track-todo.sh --local
bash scripts/track-todo.sh --offline
```

### Validation
Run Track validation after changing task files, project briefs, or task lifecycle scripts:

```shell
bash scripts/track-validate.sh
```
