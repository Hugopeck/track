# Track Projects

This directory contains the narrative scope contracts for active Track projects.

## Purpose

Each project brief explains the initiative behind a group of tasks. The brief
owns scope, boundaries, shared context, and success definition. Tasks reference
projects by `project_id`, which is derived from the brief filename.

## Conventions

- Brief paths use `.track/projects/{project_id}-{slug}.md`
- `0-archive.md` is reserved for historical archived work
- The H1 must match the project title used in `BOARD.md` and `PROJECTS.md`
- Briefs include YAML frontmatter with project metadata:
  ```yaml
  ---
  id: "1"
  title: "Project Name"
  priority: high
  status: active
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  ---
  ```
- `id`: must match the numeric prefix from the filename
- `title`: must match the H1 heading
- `priority`: `urgent | high | medium | low`
- `status`: `planning | active | done | paused`

## Required Sections

- `## Goal`
- `## Why Now`
- `## In Scope`
- `## Out Of Scope`
- `## Shared Context`
- `## Dependency Notes`
- `## Success Definition`
- `## Candidate Task Seeds`
