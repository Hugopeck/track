# r/programming Post

**Subreddit:** r/programming
**When:** Day 3 of launch week (stagger from r/ClaudeAI)
**Note:** r/programming prefers technical content, not self-promotion. Link to a blog post or the GitHub repo.

---

## Title

Git-native task coordination for AI coding agents (600 lines of bash, zero dependencies)

## Body

(Link post to GitHub repo or DEV.to article)

If submitting as text post:

When multiple AI coding agents work on the same repo, they need a way to not step on each other. Most solutions involve external services — but the repo already has everything needed: files, git history, and PRs.

Track is a protocol (not a service) that stores task state in your repo:

- A `.track/` folder with markdown task files
- Each task declares which files it touches (collision prevention)
- Status is derived from GitHub PR state, not manual updates
- ~600 lines of bash for validation, TODO generation, and PR linting

The interesting technical decisions:
- **File scoping over locking:** Tasks declare `files: [src/auth.ts]`, not file locks. This is advisory, not enforced at the filesystem level, because agents follow instructions.
- **PR-driven status:** `draft PR = active`, `ready PR = review`, `merged = done`. No manual status updates ever.
- **YAML frontmatter in markdown:** Each task file is valid markdown that's also machine-readable. Git diff shows exactly what changed.
- **Bash 3.2+:** Works on stock macOS. No node, no python, no runtime.

GitHub: https://github.com/Hugopeck/track

Curious what the community thinks about this approach to multi-agent coordination. The "PM tools are dead" thesis is controversial but I think the filesystem is underrated as a coordination mechanism.
