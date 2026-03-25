# r/opensource Post

**Subreddit:** r/opensource
**Type:** Text post
**Status:** Draft

---

## Title
I built an open-source protocol that replaces project management tools with a folder

## Body

I've been building Track — a git-native task coordination system for AI coding agents. It's MIT licensed, zero dependencies, and the entire thing is markdown files + bash scripts.

**The thesis:** When AI agents write your code, the project management layer needs to be in the repo, not in a SaaS tool. A `.track/` folder with markdown task files, validated by bash scripts, driven by PR state. No server. No account. No vendor lock-in.

**Why open source matters here:** Track is a protocol, not a product. The core will always be free — markdown tasks, bash validation, any-agent compatibility. I'm exploring open-core for team features (dashboards, analytics, approval workflows) but the coordination primitive is MIT forever.

**What it does:**
- Scaffolds a `.track/` directory in any git repo
- Markdown task files with YAML frontmatter (status, priority, dependencies, file scopes)
- Bash scripts validate state, generate TODO.md, lint PRs, auto-complete tasks on merge
- Works with Claude Code, Cursor, Codex CLI, Gemini CLI — any agent that reads files
- PR-driven status: draft PR = active, merged = done. No manual updates.

**Why I didn't just use Jira/Linear/GitHub Issues:**
- AI agents can't coordinate through a web dashboard
- File scoping (which agent owns which files) can't be expressed in traditional PM tools
- The agent IS the project manager now — it just needs a filesystem protocol

I'd love feedback from this community. What am I missing? What would you change about the open-core split?

GitHub: https://github.com/Hugopeck/track

---

## Posting notes
- Post during weekday business hours (US)
- Engage with every comment
- Don't cross-post same day as other Reddit posts
- r/opensource values genuine conversation — be ready for tough questions about the open-core model
