# r/SideProject Post

**Subreddit:** r/SideProject
**When:** Day 3-4 of launch week

---

## Title

I replaced my PM tool with a folder. AI agents get shit done, they don't need a Kanban board.

## Body

**What I built:** Track — a git-native task coordination system for AI coding agents. It's a Claude Code plugin that stores task state in your repo as markdown files. No server, no SaaS, no accounts.

**The problem it solves:** When you run multiple AI agents on the same codebase, they clash — editing the same files, duplicating work, creating merge conflicts. Track gives each task a list of files it'll touch, so agents know what's available.

**The bigger vision:** If a folder can coordinate AI agents on code, why not any project? I'm building toward "a folder is your project manager" — managing anything with just markdown files and git.

**Tech stack:** Bash 3.2+, git, markdown. That's literally it. ~600 lines of bash scripts + markdown skill files for Claude Code.

**Status:** v1.1.0, working and dogfooding it on itself. Zero users besides me (launching today). Free and open source (MIT).

**What I'd love feedback on:**
- Does the "PM tools are dead" thesis resonate?
- Would you use this for non-code projects?
- What would make you try it?

GitHub: https://github.com/Hugopeck/track

Stop managing. Start tracking. Get shit done.

Building in public — happy to share everything about the journey.
