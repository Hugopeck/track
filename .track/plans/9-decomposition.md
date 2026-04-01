---
title: "Project 9 decomposition"
created: 2026-04-01
project_id: "9"
---

| ID | Title | Mode | Priority | Depends | Files |
|----|-------|------|----------|---------|-------|
| 9.1 | Add canonical task status write helpers | implement | high | — | `skills/runtime/scripts/track-common.sh`, `skills/work/scripts/track-task-status.sh`, `skills/work/scripts/track-complete.sh`, `skills/work/scripts/track-complete-writeback.sh`, `tests/test-complete.sh` |
| 9.2 | Add PR lifecycle status sync runtime and workflow deployment | implement | high | 8.11, 9.1 | `skills/work/scripts/track-sync-pr-status.sh`, `skills/work/scripts/track-start.sh`, `skills/work/scripts/track-ready.sh`, `skills/setup-track/assets/install-manifest.json`, workflow files under `.github/workflows/` and `skills/setup-track/assets/workflows/` |
| 9.3 | Refactor validation for ordered canonical status sync | implement | high | 9.2 | `skills/validate/scripts/track-validate.sh`, `tests/test-validate.sh`, `tests/test-validate-extended.sh`, `tests/test-e2e-lifecycle.sh` |
| 9.4 | Add status reconciler and stale-state Track view warnings | implement | high | 8.11, 9.1 | `skills/work/scripts/track-reconcile.sh`, `skills/todo/scripts/track-todo.sh`, `tests/test-todo.sh`, `tests/test-todo-extended.sh` |
| 9.5 | Rewrite Track docs around canonical task status | implement | medium | 8.11, 9.2, 9.3, 9.4 | `TRACK.md`, `AGENTS.md`, `README.md`, `docs/skills-guide.md`, `skills/work/SKILL.md` |

Rationale:
- `9.1` is the foundation because every later lifecycle path needs one shared write mechanism.
- `9.2` batches lifecycle runtime, workflow ordering, and deployed assets because they change the same operational surface.
- `9.3` isolates validation semantics and lifecycle race coverage to the validation/test layer.
- `9.4` isolates read/repair behavior to the view and reconciliation layer.
- `9.5` lands last so docs describe the final canonical-status model rather than an intermediate state.
