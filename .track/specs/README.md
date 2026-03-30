# Track Specs

This directory stores permanent architecture specs, design docs, and interface
contracts that need to live longer than a short-lived plan.

## Purpose

Use `specs/` for durable technical reference documents that other work will
build against. Unlike plans, specs do not auto-expire. They are the long-term
record for decisions that shape implementation across multiple tasks or repos.

## Naming Convention

- `{slug}.md` — lowercase, hyphenated, and specific to one concept
- Prefer concrete names such as `server-architecture.md` or
  `event-contract.md`
- One spec per stable topic; split unrelated concerns into separate files

## Format

Specs use YAML frontmatter plus a structured markdown body:

```yaml
---
title: "Track Server Architecture"
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
project_id: "8"     # optional — related project
task_id: "8.9"      # optional — originating task
---
```

Frontmatter rules:

- `title` — required human-readable document title
- `status` — required: `draft`, `approved`, or `superseded`
- `created` — required creation date
- `updated` — required last meaningful revision date
- `project_id` / `task_id` — optional links back to Track work

## Writing Guidance

- State the problem, scope, and intended audience near the top
- Prefer stable facts, interfaces, and decisions over session notes
- Update `updated` when the spec meaningfully changes
- If a spec is replaced, keep the file and mark it `superseded`

Plans capture how to do near-term work. Specs capture the durable contract that
future plans and tasks should follow.
