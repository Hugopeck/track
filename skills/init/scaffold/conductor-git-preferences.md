# Conductor Git Preferences for Track

Use these repo-local Conductor settings for repos that use Track.

These prompts belong in Conductor Settings → Git for the repo. They are not
part of `conductor.json`.

## Create PR preferences

```text
Read `TODO.md`, `BOARD.md`, `.track/tasks/`, and `CLAUDE.md` first.

- Identify the primary Track task in this PR before writing anything.
- Identify any additional fully completed tasks that belong in this PR.
- Use one primary task per PR.
- Use the required conventional-commit title format from `CLAUDE.md`: `type(scope): description`.
- Include the primary task ID in the title as `[id]` or `(id)`, for example: `feat(scripts): [7.4] support explicit multi-task PR batching`.
- Always put `Track-Task: {id}` on the first line of the PR body. This is the primary linkage mechanism.
- For any other fully completed task, add `Also-Completed: {id}` lines, max 2.
- Never use multiple primary `Track-Task:` lines.
- After linkage lines, keep the body to `## Summary` and `## Test plan`.
- If task linkage is unclear, stop and ask instead of guessing.
```
