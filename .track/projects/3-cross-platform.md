# Cross-Platform Expansion

## Goal
Make Track work with the three launch-critical AI coding agents beyond Claude Code — Cursor, Codex CLI, and OpenCode. Each platform reduces single-vendor risk and opens a distinct distribution channel, but the launch scope stays narrow enough to ship quickly.

## Why Now
Claiming credible cross-platform support on launch day is critical to the narrative. Minimal viable support for Cursor, Codex CLI, and OpenCode gives us the strongest reach with the least fragmentation in the next 72 hours.

## In Scope
- Cursor plugin (port skills to Cursor plugin spec)
- Codex CLI support (AGENTS.md + docs)
- OpenCode support (agent instructions + setup docs)
- Platform-agnostic install documentation
- "Works with" badges on README

## Out Of Scope
- Full feature parity across all platforms (Claude Code stays the primary)
- Platform-specific UI integrations
- Gemini CLI, Windsurf, and Aider support before launch
- Paid/enterprise platform partnerships (that's project 5)

## Shared Context
Track's bash scripts are already platform-agnostic. The skills (SKILL.md files) are the Claude Code-specific part. Cross-platform means adapting the skill instructions to each agent's format.

## Dependency Notes
Cursor plugin is highest priority (largest user base). Codex CLI is the fastest low-effort expansion into the OpenAI ecosystem. OpenCode gives us a third supported agent without reopening the entire platform matrix. Each completed platform unblocks a content piece in project 4.

## Success Definition
Track README shows Claude Code plus Cursor, Codex CLI, and OpenCode badges. Each of the three target platforms has a working install path and getting-started doc. At least 2 of the 3 target platforms are verified working.

## Candidate Task Seeds
- Refocus project scope on Codex, Cursor, and OpenCode
- Research Cursor plugin spec and map Track skills
- Build and submit Cursor plugin
- Create AGENTS.md for Codex CLI
- Create OpenCode getting-started guide and support file
- Update README with platform status table
