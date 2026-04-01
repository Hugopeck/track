---
title: "Mirror raw task status to PR lifecycle reliably"
created: 2026-04-01
---

# Goal

Make Track project-management state reliable when the team wants raw task frontmatter to mirror PR state.

Target outcome:
- draft PR => canonical `status: active`
- ready PR => canonical `status: review`
- merged PR => canonical `status: done` + `pr:`
- closed unmerged PR => canonical `status: todo`
- converted back to draft => canonical `status: active`
- reopened PR => canonical status restored from current draft state

The important constraint is not just correctness of each script in isolation. The whole system must have one clear owner for each transition and one ordered path that prevents race conditions between sync, validation, and view generation.

# Architecture Decision

Adopt a single canonical state model:

- `status` in task frontmatter is the only canonical task status
- GitHub PR state is an external signal that Track consumes to update canonical status
- validation compares canonical status against observed PR state
- reconciliation repairs drift when canonical status and observed PR state diverge
- `TODO.md` and `BOARD.md` render canonical status, not a separate user-facing "effective" status model

Track may still compute an internal observed state from GitHub for validation, warnings, and reconciliation. That internal comparison is an implementation detail, not a second product-level status system.

# Current Failure Mode

Today the system has split ownership:
- skills/docs tell the agent to edit `status: active` and `status: review` manually
- `track-todo.sh` overlays a second read-time status from live PR metadata
- `track-validate.sh` fails if raw status does not already match the PR draft state
- `track-complete.sh` already owns `review -> done`

That means the same transition is partly owned by agents, partly by GitHub, and partly by read-time overlay logic. This is the root cause of unreliability.

# Ownership Model

Adopt a single principle:

**Lifecycle Writes Principle** — PR-driven task status changes are written by Track scripts, not by agent prose instructions.

Concretely:
- Agent skills may trigger the lifecycle scripts, but do not own direct frontmatter edits for `active` / `review` / `done`
- PR event workflows own status writes caused by GitHub state changes
- Validation owns invariant checking, not lifecycle advancement
- `track-todo.sh` renders canonical state and surfaces stale-data warnings; it is not a second status engine

# Desired End State

## 1. One transition engine

Create one shared script, likely `skills/work/scripts/track-sync-pr-status.sh`, that:
- resolves the primary task from PR body / labels / title / branch using `track_resolve_task_id()`
- computes the desired canonical status from event type + draft state
- rewrites the task file atomically
- updates `updated:`
- writes `pr:` only on merged completion
- optionally emits lifecycle events to `.track/events/log.jsonl` when running locally, or logs machine-readable output in CI

This script should be the only implementation of:
- `todo -> active`
- `active -> review`
- `review -> active`
- `active/review -> todo` on closed-unmerged PR

Keep `track-complete.sh` only if it becomes a thin merged-case wrapper around the same shared write helpers. Prefer one code path over parallel AWK implementations.

## 2. Ordered PR lifecycle workflow

Do not keep sync and validate in separate racing workflows for PR events.

Create a single PR lifecycle workflow, for same-repo PRs, with ordered jobs:
1. `sync-status`
2. `validate-track`
3. `pr-lint`
4. optional `refresh-views` / writeback step if needed

Use pull request event types:
- `opened`
- `ready_for_review`
- `converted_to_draft`
- `reopened`
- `closed`
- optionally `edited`, `labeled`, `unlabeled`, `synchronize` only for validation/lint, not status writes

Status mapping:
- `opened` + `draft=true` => `active`
- `opened` + `draft=false` => `review`
- `ready_for_review` => `review`
- `converted_to_draft` => `active`
- `reopened` + `draft=true` => `active`
- `reopened` + `draft=false` => `review`
- `closed` + `merged=false` => `todo`
- `closed` + `merged=true` => delegate to completion path => `done`

Important: if workflow ordering is not guaranteed, validation will continue to see stale status and fail spuriously.

## 3. Local bash wrappers for immediate consistency

To avoid waiting for CI for every local action, add thin local wrappers that the skill can call:
- `track-start.sh {task_id}`
- `track-ready.sh {task_id}`
- optional `track-abandon.sh {task_id}`

These wrappers should:
- update the task file through the shared write helper
- run local validation
- then perform the GitHub action (`gh pr create --draft`, `gh pr ready`, etc.)
- surface errors and stop if GitHub operations fail

This keeps bash as the owner while making the UX fast. CI still reconciles and repairs drift.

The skill change then becomes simple:
- replace “set status: active/review manually” with “run the Track lifecycle command for this transition”

# Validation Changes

Validation should enforce invariants without fighting the lifecycle workflow.

Keep these checks:
- open PR must resolve to exactly one task
- duplicate open PRs for one task are errors
- blocked task with open PR is an error
- done/cancelled task with open PR is an error unless processing the merged-close completion path
- orphaned PRs with no task file are errors
- dependency rules stay as-is

Change these checks:
- remove the assumption that the agent edited status by hand before CI saw the PR
- validate expected canonical status from PR state after sync, not before sync
- if validation still runs on events that do not call sync first, make it tolerant by reading the event payload and allowing the pre-sync state only for that event window

Preferred approach: avoid tolerance logic by guaranteeing workflow order.

# Read Model / TODO View Changes

`track-todo.sh` should stop presenting a user-facing second status model. Its main job is to render canonical task status and warn when GitHub-based checks are unavailable.

Add a visible stale-state signal:
- if `gh` lookup fails, render a warning that PR overlay is unavailable
- optionally mark the generated footer as `offline/partial`
- do not hide that the board may be stale

If Track still computes observed PR state during generation, use it only to warn about possible drift or suggest reconciliation. Do not silently replace canonical status in the rendered views.

This prevents a network/tooling failure from looking like project-management truth.

# Reconciler

Add `skills/work/scripts/track-reconcile.sh`.

Purpose:
- scan all tasks and open PRs
- recompute expected canonical status from live GitHub state
- repair safe mismatches
- regenerate views
- print unresolved conflicts for manual intervention

Safe automatic repairs:
- task canonical `todo` but linked draft PR exists => set `active`
- task canonical `active` but PR is ready => set `review`
- task canonical `review` but PR converted to draft => set `active`
- task canonical `active/review` but PR closed unmerged => set `todo`

Do not auto-repair:
- blocked/cancelled/done mismatches that imply semantic disagreement
- ambiguous linkage
- multiple PRs per task

This becomes the recovery tool when hooks/workflows miss an event.

# Eventing Alignment

The event contract already names:
- `track.pr.opened`
- `track.pr.ready`
- `track.pr.merged`
- `track.task.started`

Use the status-sync path to emit or at least standardize these transitions.

Recommended mapping:
- `opened` draft => emit `track.pr.opened` and `track.task.started`
- `ready_for_review` => emit `track.pr.ready`
- `closed merged` => emit `track.pr.merged`

Do not make event logging a prerequisite for status correctness. Status sync must still succeed if event emission is unavailable.

# Implementation Phases

## Phase 1 — Normalize ownership

1. Add shared frontmatter write helpers for status changes
2. Refactor `track-complete.sh` to reuse them where practical
3. Update docs/skills to remove manual ownership of `active` / `review`
4. Rewrite docs to define `status` as the only canonical status; demote "effective status" to an internal implementation detail or remove it entirely
5. Keep current workflows unchanged for the moment

Deliverable: there is one bash-level write path for task status transitions and one canonical status model in the docs.

## Phase 2 — Add PR status sync workflow

1. Add `track-sync-pr-status.sh`
2. Add a PR lifecycle workflow for `opened`, `ready_for_review`, `converted_to_draft`, `reopened`, `closed`
3. Limit writes to same-repo PRs
4. On merged close, call completion logic rather than writing `done` separately

Deliverable: GitHub events can drive raw status accurately.

## Phase 3 — Remove race with validation

1. Consolidate PR-triggered Track jobs into one workflow or otherwise guarantee order
2. Move `track-validate` behind `sync-status`
3. Trim strict pre-sync assumptions from `track-validate.sh`

Deliverable: no false validation failures caused by timing.

## Phase 4 — Add local wrappers

1. Add `track-start.sh` and `track-ready.sh`
2. Teach `/track:work` to call them
3. Keep CI as reconciliation/repair authority

Deliverable: immediate local consistency plus reliable server-side enforcement.

## Phase 5 — Add reconciler + stale warnings

1. Add `track-reconcile.sh`
2. Update `track-todo.sh` warning behavior for offline/failed PR lookup
3. Document the recovery path

Deliverable: missed events no longer leave the system permanently wrong.

# Test Plan

Add or extend tests for these cases:

## Script-level transitions
- opened draft PR sets `active`
- opened ready PR sets `review`
- ready-for-review sets `review`
- converted-to-draft sets `active`
- reopened draft sets `active`
- reopened ready sets `review`
- closed unmerged resets to `todo`
- merged close sets `done` + `pr:` and unblocks dependents

## Validation behavior
- post-sync PR branch validates cleanly
- blocked task with open PR fails
- duplicate PRs fail
- orphaned PR fails
- ready PR no longer races validate when sync is enabled first

## Reconciler behavior
- safe mismatch repairs are applied
- ambiguous mismatch is reported and not auto-fixed

## View behavior
- TODO/BOARD warns clearly when live PR overlay could not be loaded
- effective status still reflects live PR state when available

# Documentation Changes

Update these sources together so the protocol is coherent:
- `TRACK.md`
- `skills/work/SKILL.md`
- setup-track assets that install workflows/scripts
- any docs that currently say the agent must edit `status: active/review` directly

New wording should say:
- agents trigger lifecycle commands
- scripts/workflows own status movement
- validation checks invariants
- reconcile repairs drift

# Open Design Decisions

Decide these before implementation:

1. Should `opened` with `draft=false` immediately set `review`?
   - Recommended: yes

2. On closed-unmerged PR, should status always return to `todo`?
   - Recommended: yes, unless the task is already `blocked` or `cancelled`

3. Should same-repo writeback push directly to the PR branch or always use a writeback PR?
   - Recommended: push directly for same-repo branches; fallback to writeback PR only on push failure

4. Should local wrappers be required by the skill, or optional convenience commands?
   - Recommended: required in skill docs; CI remains backstop

# Acceptance Bar

This effort is done when:
- no Track doc tells agents to hand-edit `active` / `review`
- no Track doc presents raw/effective as separate user-facing status concepts
- a PR open/ready/draft/close transition updates canonical task status through scripts alone
- validation no longer fails because of workflow timing
- `track-todo.sh` renders canonical status and can warn about stale GitHub checks instead of silently degrading
- a reconciler exists for repair after missed events
- tests cover the lifecycle edges above
