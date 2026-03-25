# Cross-Platform Expansion

## Goal
Make Track work with every major AI coding agent — Cursor, Codex CLI, Gemini CLI, Windsurf, Aider. Each new platform is both a survival strategy (reduces single-platform risk) and a growth event (new audience).

## Why Now
Claiming "works everywhere" on launch day is critical to the narrative. Minimal viable support for 2-3 platforms beyond Claude Code needed within 72 hours.

## In Scope
- Cursor plugin (port skills to Cursor plugin spec)
- Codex CLI support (AGENTS.md + docs)
- Gemini CLI support (markdown skills format)
- Windsurf support
- Aider support
- Platform-agnostic install documentation
- "Works with" badges on README

## Out Of Scope
- Full feature parity across all platforms (Claude Code stays the primary)
- Platform-specific UI integrations
- Paid/enterprise platform partnerships (that's project 5)

## Shared Context
Track's bash scripts are already platform-agnostic. The skills (SKILL.md files) are the Claude Code-specific part. Cross-platform means adapting the skill instructions to each agent's format.

## Dependency Notes
Cursor plugin is highest priority (largest user base). Codex and Gemini are low effort. Each completed platform unblocks a content piece in project 4.

## Success Definition
Track README shows 4+ platform badges. Each platform has a working install path and getting-started doc. At least 2 platforms verified working.

## Candidate Task Seeds
- Research Cursor plugin spec and map Track skills
- Build and submit Cursor plugin
- Create AGENTS.md for Codex CLI
- Create Gemini CLI getting-started guide
- Research Windsurf extension format
- Update README with platform status table
