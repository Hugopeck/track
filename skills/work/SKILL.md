---
name: work
description: |
  Track's operating protocol. Work either a tracked task session or an
  untracked session, promote to tracked work when one task deterministically
  matches, and let PR lifecycle automation drive review and completion. Loaded
  automatically in any repo with .track/.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:work` owns the active work session in a repo with `.track/`. It handles
two valid states: tracked work attached to a task, and untracked work that is
not ready to be forced into Track yet.

## Role

This skill is the fallback protocol. In repos with a complete Track section in
`CLAUDE.md`, that section is primary. This skill activates when the Track block
is missing or incomplete, or when invoked directly.

## What This Skill Owns

1. Read Track state, branch state, and PR state
2. Lock one operating mode for the session
3. Run a tracked task session when a task is known
4. Allow an untracked session when no task should be forced yet
5. Promote `untracked` work to `tracked` only through deterministic auto-patch
6. Start tracked work with `bash .track/scripts/track-start.sh {id}` when needed
7. Open or continue a draft PR and keep linkage correct
8. Append discoveries to task `## Notes` during tracked work
9. Persist planning output to `.track/plans/`
10. Hand off review through PR lifecycle automation

This skill does **not** own queue picking, standalone retroactive attribution,
standalone note-only task edits, direct `review` writes, or merged completion.

## Operating Modes

Lock one mode at the start and do not drift.

- `tracked` — the session is attached to a specific task
- `untracked` — no task was supplied and no tracked context safely applies
- `empty` — no open tasks exist

The only allowed mode change is `untracked` → `tracked` via deterministic
auto-patch. State the promotion explicitly.

Mode resolution:

1. If the user supplied a task ID or task file, lock `tracked`.
2. Else if the current branch or PR already resolves to one task, lock `tracked`.
3. Else if no open tasks exist, lock `empty`.
4. Else lock `untracked`.

Untracked work is valid. Do not force queue selection from `TODO.md`.

## Definition of Done

- `tracked` is done when task context is read, blockers and overlap are checked,
  tracked status is entered if needed, and a draft PR exists or the existing
  tracked PR/branch state is clearly advanced.
- `untracked` is done when work can continue without task mutation and the next
  step is clear, with an untracked PR or local branch state explained.
- `empty` is done when the user is told no open tasks exist and that untracked
  work is still allowed.

Do not report tracked work as started before `track-start.sh` succeeds. Do not
report success before the mode reaches its definition of done.

## State Sources

Read only the state needed for the locked mode.

- `TODO.md` and `BOARD.md` for shared context only, never queue picking
- `.track/tasks/*.md` for task state, blockers, and file scopes
- `.track/plans/*.md` for prior planning context
- `.track/specs/pr-instructions.md` for exact PR body and mergeability rules
- Branch name, PR body, PR title, and labels for task resolution
- Current diff or touched files when evaluating deterministic auto-patch

If the user asks for retroactive linking or note-only task edits, this skill is
out of scope. Name the out-of-scope request and stop.

## Tracked Session

Summary: when a task is known, work the task and let Track own the lifecycle.

1. Read the task file, `## Context`, `## Notes`, and any linked plan.
2. Check `depends_on` and stop if a blocker is unresolved.
3. Check `files:` overlap against `active` and `review` tasks.
4. If the task mode is `investigate` or `plan`, prioritize understanding and
   documentation before implementation.
5. If the task acceptance criteria are incomplete, tighten them before doing
   tracked implementation.
6. Use a dedicated branch or worktree when practical.
7. If `status: todo`, run:
   ```bash
   bash .track/scripts/track-start.sh {id}
   ```
8. Open or continue a **draft PR**.
9. For tracked PRs, keep `Track-Task: {id}` as the primary body linkage.
10. Do the work.
11. Append discoveries to `## Notes` during work, not after.
12. If the task mode is `plan`, persist the output to `.track/plans/{task_id}-{slug}.md`.
13. When ready for review, verify acceptance criteria with evidence labels and
    then mark the PR ready for review. Do not call `track-ready.sh`.

If `gh` auth fails or PR creation/update fails, STOP and surface the error.

## Untracked Session

Summary: no task is a valid state. Stay untracked until one task clearly fits.

1. Do not pick from `TODO.md`.
2. Read only the context needed to understand the work: current branch, current
   diff, existing PR state, and nearby task scopes if needed.
3. Work may continue locally or in a draft PR.
4. Do not call `bash .track/scripts/track-start.sh` while the session is
   untracked.
5. Do not mutate a task file by default.
6. If a draft PR exists, use the untracked template from
   `.track/specs/pr-instructions.md`.
7. Re-check deterministic auto-patch only when you have concrete file or PR
   context strong enough to justify promotion.

BAD: "No task was supplied, so I picked one from TODO.md."
GOOD: "No task was supplied, so this session stays untracked until one task
clearly matches."

## Empty Session

Summary: no open tasks is informative, not blocking.

1. Tell the user there are no open tracked tasks.
2. Say untracked work is still allowed.
3. Offer `/track:create` or `/track:decompose` as optional next steps.

Do not force task creation just because the queue is empty.

## Deterministic Auto-Patch

Summary: preserve the old pick-mode hatch without reintroducing queue picking.

Auto-patch is allowed only when all conditions are true:

1. Exactly one deterministic candidate task exists.
2. The task is not `done`, `cancelled`, or `blocked`.
3. The current work is cohesive with the task's existing intent.
4. Promotion would not create a second independent goal.

Deterministic signals only:

- current branch or PR already resolves to one task
- current diff or changed files match exactly one open task `files:` scope

Do not use fuzzy title matching or broad heuristics as the primary gate.

If the current protocol would classify the work as a split, do not auto-patch.
Stay untracked or create/split a task instead.

### Auto-patch transition steps

1. State the promotion explicitly: `Promoting untracked session to tracked task {id}.`
2. If the task is still `todo`, run:
   ```bash
   bash .track/scripts/track-start.sh {id}
   ```
3. Append a dated note to the task describing the branch and that previously
   untracked work was attached to this task.
4. If retroactive attribution is needed for current branch history, emit a
   `track.link` event using the event contract format.
5. Update the PR body from the untracked template to `Track-Task: {id}`.
6. Continue as `tracked`.

Auto-patch may update `## Notes`, `updated:`, PR linkage, and attribution
metadata. It may update `files:` only when that reflects cohesive real scope.
It must never silently absorb a second independent objective.

## Acceptance Criteria Evidence

Summary: verify claims with evidence you can actually support.

Classify each acceptance criterion as exactly one of:

- `MET`
- `PARTIAL`
- `UNVERIFIED`

Use this format:

```text
MET — Draft PR linked to task — evidence: PR body includes Track-Task: 1.7
PARTIAL — Notes updated during work — evidence: .track/tasks/1.7-plan-work-skill-redesign.md
UNVERIFIED — No automated check run for migration path
```

Rules:

- File paths and commands are valid evidence.
- Line numbers are optional, never required.
- If you cannot verify a claim, mark `UNVERIFIED`.
- Never fabricate file or line citations.

## When to Split Instead of Patch

Summary: Track prefers small cohesive tasks over silent scope growth.

Split or create a new task when any of these are true:

- the new work introduces a second independent goal
- acceptance criteria need a new primary outcome
- the work crosses into a second subsystem or concern
- the current protocol would call the bundle non-cohesive

Calibration — this is the bar: tightening one task's docs, scripts, and tests
for the same workflow is cohesive. Fixing a release workflow while redesigning
the work skill is not.

## Persisting Plans

Summary: planning output is state, not scratch text.

When planning, investigation, or design work produces a plan:

1. Save it to `.track/plans/` automatically.
2. Use `{task_id}-{slug}.md` when linked to a task, or `{slug}.md` otherwise.
3. Add YAML frontmatter with `title`, `created`, and optional `task_id` / `project_id`.
4. Paste the plan body as-is; do not rewrite it into a second format.

## Closing Message Matrix

Use exactly one template.

If mode is `tracked`:

```text
Tracked session: {task_id} on {branch}. PR: {pr_state}. Next: {next_step}.
```

If mode is `untracked`:

```text
Untracked session: {branch}. PR: {pr_state}. Promotion: {none|task_id}. Next: {next_step}.
```

If mode is `empty`:

```text
No open tracked tasks. Continue untracked if needed, or use /track:create or /track:decompose.
```

## Do Not

- Do not pick a task from `TODO.md`.
- Do not silently drift between modes.
- Do not teach or call `bash .track/scripts/track-ready.sh {id}`.
- Do not fabricate file or line citations.
- Do not treat untracked work as an error.
- Do not overwrite existing `## Notes` content — append only.
- Do not edit `TODO.md`, `BOARD.md`, or `PROJECTS.md` directly.
- Do not auto-patch on ambiguous matches.
- Do not widen a task into a second independent goal just to avoid creating or splitting a task.
- Do not continue after PR creation/update fails.
- Do not claim tracked work started before `track-start.sh` succeeds.

## References

- Read `references/session-handoff.md` for tracked vs untracked PR examples,
  ready-for-review handoff, and reconcile guidance.
- Read `.track/specs/pr-instructions.md` for exact PR templates and mergeability steps.
