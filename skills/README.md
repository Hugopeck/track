# Skills

Skills are markdown protocols that teach AI agents the Track workflow. Each skill lives in its own directory with a `SKILL.md` file containing YAML frontmatter (name, description, allowed tools) and step-by-step instructions the agent follows at runtime.

Skills are the instruction layer. Scripts (in `.track/scripts/`) are the enforcement layer. Together they form the coordination system — skills tell agents what to do, scripts verify they did it right.

## Skill inventory

| Skill | Command | Purpose | Auto-loaded? |
|-------|---------|---------|:------------:|
| [init](init/) | `/track:init` | Scaffold Track into a repo, import existing markdown, onboard new users | No |
| [work](work/) | `/track:work` | Pick a task, open a draft PR, implement, hand off to merge | Yes |
| [create](create/) | `/track:create` | Create tasks and projects from natural language | No |
| [decompose](decompose/) | `/track:decompose` | Break a goal into parallelizable tasks with non-overlapping file scopes | No |
| [validate](validate/) | `/track:validate` | Run validation, explain errors, suggest fixes | No |
| [todo](todo/) | `/track:todo` | Regenerate the `TODO.md` coordination view | No |
| [test](test/) | `/track:test` | Run Track's internal test suite and classify failures | No |

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
| init | x | x | x | x | x | x | |
| work | x | x | x | x | x | x | |
| create | x | x | x | x | x | x | |
| decompose | x | x | x | x | x | x | |
| validate | x | x | x | x | | | |
| todo | x | x | | | | | |
| test | x | x | x | x | | | x |

Notable: `validate` and `todo` cannot write files — they are read-only diagnostic skills. `test` can spawn sub-agents for isolated skill smoke tests.

### Auto-loading

The `work` skill is auto-loaded in any repo that contains a `.track/` directory. This means the agent always knows the Track protocol without the user needing to invoke a command. All other skills are invoked explicitly via `/track:<name>`.

## Adding a new skill

1. Create a directory under `skills/` with the skill name.
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`) and the protocol body.
3. Follow the protocol structure: scope, modes, definition of done, closing messages, do-not rules.
4. Register the skill in the plugin manifest (`.claude-plugin/plugin.json`) if it should be user-invocable.
5. Add a smoke test recipe in the `test` skill if the skill should be covered by `/track:test`.
