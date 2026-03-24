# Track Projects

This directory contains the narrative scope contracts for active Track projects.

## Purpose

Each project brief explains the initiative behind a group of tasks. The brief
owns scope, boundaries, shared context, and success definition. Tasks reference
projects by `project_id`, which is derived from the brief filename.

## Conventions

- Brief paths use `.track/projects/{project_id}-{slug}.md`
- `0-archive.md` is reserved for historical archived work
- The H1 must match the project title used in `TODO.md`
- Briefs are markdown-only; do not add frontmatter

## Required Sections

- `## Goal`
- `## Why Now`
- `## In Scope`
- `## Out Of Scope`
- `## Shared Context`
- `## Dependency Notes`
- `## Success Definition`
- `## Candidate Task Seeds`
