# Claude Code Instructions

## Project Context

This is the Track plugin repo. Track is a git-native task coordination system distributed as a Claude Code plugin.

## Key Files

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/init/SKILL.md` — `/track:init` scaffolding skill
- `skills/init/scaffold/` — files copied into adopting repos
- `skills/work/SKILL.md` — `/track:work` core workflow protocol
- `skills/create/SKILL.md` — `/track:create` task/project creation
- `skills/validate/SKILL.md` — `/track:validate` wrapper
- `skills/todo/SKILL.md` — `/track:todo` wrapper
- `skills/decompose/SKILL.md` — `/track:decompose` goal breakdown
- `tests/` — bash test scripts and fixtures

## Workflow

- No build step, no runtime — this is a plugin made of markdown and bash
- Edit skills in `skills/`, test with `claude --plugin-dir .`
- Scaffold content in `skills/init/scaffold/` is what gets copied into adopting repos
- Run `/reload-plugins` after editing skills to pick up changes
- Use conventional commits: `feat(skills):`, `fix(scripts):`, `docs:`

## Important Context

- Track was extracted from the Archeia monorepo
- Adopting repos are self-contained — they never depend on this plugin at runtime
- The plugin teaches Claude the Track protocol; the scripts enforce it
- The CLAUDE.md section appended by `/track:init` is the minimal contract; `/track:work` is the full operational guide
