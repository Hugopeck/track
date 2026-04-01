# Track Plans

This directory stores plan documents — short-lived reference artifacts that capture
decisions, approaches, and context produced during investigation or planning work.

## Purpose

Plans bridge the gap between a task's acceptance criteria and the actual
implementation. They persist context that would otherwise be lost between
sessions, and they're discoverable by any agent working in the repo.

## Format

Plans use minimal YAML frontmatter and a freeform body:

```yaml
---
title: "Brief description of what this plan covers"
created: YYYY-MM-DD
task_id: ""       # optional — linked task
project_id: ""    # optional — linked project
---

(freeform content — pasted as-is from any source)
```

The body is intentionally unstructured. Different tools and agents produce
different plan formats — Track doesn't enforce a template. Paste whatever you
have.

## Naming Convention

- `{slug}.md` — lowercase, hyphenated (e.g., `auth-migration.md`)
- `{task_id}-{slug}.md` — when linked to a task (e.g., `1.1-migration-plan.md`)

## Expiry

Plans auto-expire **7 days** after their `created` date. The validation script
deletes expired plans on each run. If a plan is missing a `created` field, it
cannot be auto-expired and validation will warn about it.

To keep a plan longer, update its `created` date.
