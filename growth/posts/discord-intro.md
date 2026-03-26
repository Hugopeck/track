# Discord Introduction Message

**Use in:** Claude Code, Cursor, AI agent builder, and indie hacker Discord servers
**Post in:** #show-and-tell, #projects, #tools, or equivalent channel
**Adapt tone to each server's culture**

---

## Template

Hey! Been working on an open-source tool called **Track** — it coordinates multiple AI coding agents working on the same repo.

**The problem:** When you run 3+ agents in parallel (like with Conductor), they step on each other — same files, duplicate PRs, wasted tokens.

**How Track solves it:** A `.track/` folder in your repo with markdown task files. Each task declares which files it touches. Agents read the state, pick non-conflicting work, and report progress through git PRs.

No server, no SaaS, no accounts. Just markdown + bash + git.

Works with Claude Code, Cursor, Codex, and Gemini CLI.

GitHub: https://github.com/Hugopeck/track

Less managing, more getting shit done. Would love feedback from anyone running multi-agent workflows — what coordination problems do you hit most?

---

## Server-specific notes

**Claude Code Discord:** Emphasize the plugin angle, `/track:init` command
**Cursor Discord:** Mention Cursor plugin support, link to marketplace listing
**AI builders:** Focus on the protocol design, multi-agent coordination problem
**Indie hackers:** Focus on the build-in-public story, open-core model
