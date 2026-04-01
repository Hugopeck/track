---
id: "9"
title: "Canonical PR Status Sync"
priority: high
status: planning
created: 2026-04-01
updated: 2026-04-01
---

# Canonical PR Status Sync

## Goal
Make task `status` the single canonical state in Track. GitHub PR lifecycle events should sync that status through bash scripts and workflows, validation should enforce invariants after sync, and reconciliation should repair drift when events are missed.

## Why Now
Track's current status movement is unreliable because ownership is split across agent instructions, read-time PR overlays, validation assumptions, and post-merge automation. That creates drift, stale views, and race conditions. Consolidating status movement into scripts and workflows is necessary for dependable project management using only skills and bash.

## In Scope
- Shared bash helpers for task status writes and frontmatter updates
- PR lifecycle status sync for opened, ready-for-review, converted-to-draft, reopened, and closed events
- Ordered workflow execution so status sync happens before validation on PR events
- Local lifecycle wrapper commands for starting work and marking ready for review
- Reconciler script to repair safe status drift from live PR state
- `track-todo.sh` changes to render canonical status and warn when GitHub checks are stale or unavailable
- Documentation updates to remove user-facing raw/effective status duality
- Tests covering lifecycle transitions, race prevention, reconciliation, and stale-warning behavior

## Out Of Scope
- Server-side or database-backed state management
- Replacing Track's markdown task files as the source of truth
- Marketplace/plugin-specific lifecycle logic outside the bash + skills model
- Unrelated workflow or docs cleanups beyond status sync and its direct dependencies

## Shared Context
This project is driven by `.track/plans/raw-status-pr-sync.md`, which defines the canonical-state architecture decision and phased rollout. The desired model is: task frontmatter owns canonical `status`; PR state is only an external signal consumed by sync and reconcile paths.

## Dependency Notes
This project can build on the existing task resolver, completion workflow, validation scripts, and event contract already present in project 8. The work should preserve same-repo writeback behavior, fallback semantics, and bash 3.2 compatibility.

## Success Definition
- No Track doc tells agents to hand-edit `active` or `review`
- PR open/ready/draft/close transitions update canonical task status through scripts alone
- Validation no longer fails because of workflow timing between PR state and task status writes
- `TODO.md` and `BOARD.md` render canonical task status and warn clearly when GitHub-derived checks are stale or unavailable
- A reconciler exists to repair safe drift after missed lifecycle events
- Tests cover lifecycle edges, validation ordering, and reconciliation behavior

## Candidate Task Seeds
- Add shared lifecycle status write helpers — `skills/work/scripts/**`, `skills/runtime/scripts/**`
- Add PR lifecycle status sync workflow — `.github/workflows/**`, `skills/work/scripts/**`
- Refactor validation around ordered sync — `skills/validate/scripts/**`, `.github/workflows/**`
- Add local lifecycle wrappers and work-skill integration — `skills/work/**`
- Add reconciler and stale-warning view behavior — `skills/work/scripts/**`, `skills/todo/scripts/**`, docs/tests
