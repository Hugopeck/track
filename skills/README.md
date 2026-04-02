# Skills

Skills are markdown protocols that teach AI agents the Track workflow. Each installable skill lives in a directory with a `SKILL.md` file containing YAML frontmatter (name, description, allowed tools) and step-by-step instructions the agent follows at runtime.

Skills are the instruction layer. Scripts (in `.track/scripts/`) are the enforcement layer. Together they form the coordination system — skills tell agents what to do, scripts verify they did it right.

## Skill inventory

| Skill | Command | Purpose | Auto-loaded? |
|-------|---------|---------|:------------:|
| [setup-track](setup-track/) | `/track:setup-track` | Scaffold Track into a repo, install scripts/hooks/workflows, import existing markdown | No |
| [work](work/) | `/track:work` | Pick a task, open a draft PR, implement, hand off to merge | Yes |
| [create](create/) | `/track:create` | Create tasks and projects from natural language | No |
| [decompose](decompose/) | `/track:decompose` | Break a goal into parallelizable tasks with non-overlapping file scopes | No |
| [refresh-track](todo/) | `/track:refresh-track` | Regenerate `BOARD.md`, `TODO.md`, and `PROJECTS.md` | No |
| [update-skills](update-track/) | `/update-skills` | Refresh the installed Track skill clone on this machine | Yes |

## Shared support scripts

Every directory under `skills/` is now a real installable skill with a `SKILL.md`.
Shared bash support lives at the repo root instead:

- `scripts/validate/` — owns `track-validate.sh` and `track-conventional-commit-lint.sh`
- `scripts/lib/` — shared runtime helpers such as `track-common.sh`

## Directory conventions

Every installable skill directory must contain `SKILL.md`. Optional sibling
directories are added only when they carry real content:

- `scripts/` — executable helpers owned by that skill
- `references/` — read-on-demand supporting documentation
- `assets/` — static files, templates, or install-time resources such as hook and workflow assets

Discovery and installation must key off `SKILL.md`, not raw directory
enumeration. That keeps internal support directories out of the user's skill
catalog.

## How skills work

Each `SKILL.md` follows a strict protocol structure:

1. **What This Skill Owns** — defines the skill's scope boundary. A skill never acts outside its ownership.
2. **Operating Modes** — the skill locks into one mode at the start of a run and stays in it.
3. **Definition of Done** — exact completion criteria. The skill is not done until every condition is met.
4. **Closing Message Matrix** — each mode has one closing message template, used verbatim.
5. **Do Not** — hard constraints that are never violated.

### Tool permissions

Each skill declares its allowed tools in the YAML frontmatter. This controls what the agent can do:

| Skill | Bash | Read | Glob | Grep | Edit | Write | Agent |
|-------|:----:|:----:|:----:|:----:|:----:|:-----:|:-----:|
| setup-track | x | x | x | x | x | x | |
| work | x | x | x | x | x | x | |
| create | x | x | x | x | x | x | |
| decompose | x | x | x | x | x | x | |
| refresh-track | x | x | | | | | |
| update-skills | x | x | | | | | |

Notable: `refresh-track` and `update-skills` are narrow bash-first utility skills. Validation remains available through scripts and workflows, not slash commands.

### Auto-loading

The `work` skill is auto-loaded in any repo that contains a `.track/` directory. `update-skills` is also auto-loaded so it can check for Track updates at session start. Other skills are invoked explicitly.

## Adding a new skill

1. Create a directory under `skills/` with the skill name.
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`) and the protocol body.
3. Add `scripts/`, `references/`, or `assets/` only when the skill actually needs them.
4. Follow the protocol structure: scope, modes, definition of done, closing messages, do-not rules.
5. Keep internal support directories under `skills/` free of `SKILL.md` so install/discovery skips them.
6. Add or update a repo test under `tests/` when the skill contract changes.
