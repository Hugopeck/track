---
name: test
description: |
  Run Track's internal test suite in one locked mode. Orchestrate bash script
  tests, headless skill smoke tests, or both; classify failures semantically;
  and return a structured pass/fail report without mutating the real repo.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
---

## Purpose

`/track:test` owns Track's internal test orchestration. It selects a single
mode, runs the matching suite, validates invariants instead of brittle exact
output, classifies failures semantically, and returns one structured result.

## What This Skill Owns

1. Select exactly one test mode and stay locked to it
2. Run `tests/run-all.sh` for script coverage
3. Run headless smoke tests for Track skills in isolated git worktrees
4. Validate protocol invariants: tool-call chain, closing message format, and
   `Do Not` compliance
5. Classify failures into actionable buckets
6. Return one final pass/fail report from the closing message matrix

This skill does NOT own fixing failing tests. It diagnoses and reports. Another
task or skill applies fixes.

## Operating Modes

Lock one of these modes at the start and do not switch mid-run:

- `scripts` — run `bash tests/run-all.sh`, parse per-file results, and classify
  failures from the runner output
- `skills` — run headless smoke tests for Track skills in isolated worktrees;
  default smoke set is `validate` and `todo`
- `full` — run `scripts`, then `skills`, and emit one unified report
- `single` — run exactly one named script or one named skill

Mode selection rules:

1. If `$ARGUMENTS` is empty, use `full`
2. If `$ARGUMENTS` starts with `scripts`, `skills`, or `full`, use that mode
3. If `$ARGUMENTS` starts with `single`, treat the remaining token as the target
4. If `$ARGUMENTS` is a bare skill name (`validate`, `todo`, `/track:validate`),
   use `single`
5. If `$ARGUMENTS` is a script path or script basename, use `single`

Target resolution in `single` mode:

1. If the target starts with `/track:`, strip the prefix and treat it as a skill
2. If `skills/{target}/SKILL.md` exists, test that skill
3. Else if `tests/{target}` exists, test that script
4. Else if `tests/test-{target}.sh` exists, test that script
5. Else STOP: "Unknown test target `{target}`. Expected a Track skill name or a
   file under `tests/`."

## Definition of Done

- The selected mode ran to completion, or stopped with a concrete blocker
- Every required command for that mode actually ran
- Every failure is classified into a semantic bucket with evidence
- `skills` and `full` mode run each skill test in an isolated git worktree
- Skill smoke tests validate invariants, not exact free-form prose
- The closing message is emitted from the matrix below
- Do not report success if any required test or invariant failed

## Steps

### Phase 1: Preflight

1. Confirm repo root contains `skills/` and `tests/`
2. For any mode that touches bash tests, require `bash`
3. For any mode that touches headless skill tests, require `git`, `claude`, and
   `jq`
4. If a required dependency is missing, STOP with a precise message naming the
   missing command

### Phase 2: Run `scripts` mode

1. Require `tests/run-all.sh`. If missing, STOP: "Test runner missing at
   `tests/run-all.sh`. Implement task 7.1 or add the unified runner first."
2. Run `bash tests/run-all.sh`
3. Parse lines beginning with `PASS ` and `FAIL ` to build per-file results
4. If the runner exits non-zero, keep parsing its output — do not stop at the
   first failure
5. For each failed script, read the script file and classify the failure:
   - `environment` — missing executable, auth, or OS dependency
   - `fixture-drift` — expected fixture or generated file is missing/mismatched
   - `protocol-regression` — assertions around skill wording, required sections,
     or workflow guarantees failed
   - `script-regression` — a Track bash script produced the wrong behavior
   - `runner-regression` — `tests/run-all.sh` output itself is malformed
6. Report the failing file, bucket, and one concrete next fix. Do not paste raw
   logs without interpretation.

### Phase 3: Run `skills` mode

1. Build the smoke list:
   - Default list: `validate`, `todo`
   - In `single` mode, the resolved skill target only
2. For each skill in the list:
   - Create a temp directory with `mktemp -d`
   - Add an isolated worktree from `HEAD`:
     `git worktree add --detach "$tmp_dir/repo" HEAD`
   - `cd` into the worktree root and ensure cleanup runs afterward:
     `git worktree remove --force "$tmp_dir/repo" && rm -rf "$tmp_dir"`
3. Read `skills/{skill}/SKILL.md` before invocation. Use it to confirm allowed
   tools, closing message rules, and `Do Not` constraints.
4. Invoke the skill headlessly:

   ```bash
   claude -p "/track:{skill} {skill_args}" \
     --plugin-dir . \
     --output-format json \
     --bare \
     --max-budget-usd 0.50
   ```

5. Parse the JSON with `jq`. Validate invariants, not exact full output:
   - Required Bash call happened
   - Forbidden tool calls did not happen
   - Final assistant message matches the skill's closing-message contract
   - No `Do Not` rule was violated
6. Classify failures:
   - `environment` — `claude`, `jq`, or `git worktree` failed
   - `tool-chain-regression` — required tool call missing or forbidden tool used
   - `closing-message-regression` — final message does not match contract
   - `do-not-violation` — the skill violated a hard constraint in its own spec
   - `budget-or-transport` — invocation hit budget, timed out, or returned
     malformed JSON

### Phase 4: Skill smoke recipes

Use these built-in recipes unless the user names a different skill explicitly.

#### `validate`

- Prompt: `/track:validate`
- Required tool signal: a Bash call containing `.track/scripts/track-validate.sh`
- Forbidden tool signals: `Edit`, `Write`
- Closing message must match one of:
  - `Validation passed: {N} tasks ({X} todo, {Y} active, {Z} done).`
  - `Validation failed with {N} errors. Fixes listed above.` followed by
    `Re-run /track:validate after applying fixes.`
- `Do Not` checks:
  - Never report success if validation failed
  - Never suggest a fix without reading the offending file first

#### `todo`

- Prompt: `/track:todo --local --offline`
- Required tool signal: a Bash call containing `.track/scripts/track-todo.sh`
- Required artifact: `TODO.md` exists in the isolated worktree after the run
- Closing message must match:
  - `TODO.md regenerated (mode: {full|offline|local}).`
- `Do Not` checks:
  - Never edit `TODO.md` by hand
  - Never override user-supplied flags with auto-detection

If the user names a skill without a built-in recipe, read its `SKILL.md` and
build the smoke test from that file's allowed tools, closing message section,
and `Do Not` section. If the skill does not expose machine-checkable invariants
yet, STOP: "Skill `{skill}` has no smoke recipe yet. Add one to
`skills/test/SKILL.md` or test it manually."

### Phase 5: Run `full` mode

1. Run `scripts` mode first
2. Run `skills` mode second, even if `scripts` mode failed
3. Produce one unified report with both result sets
4. Overall status is `FAIL` if either sub-suite failed

### Phase 6: Run `single` mode

1. Resolve the target once at the start
2. If the target is a script, run only that file with `bash`
3. If the target is a skill, run only that skill's smoke recipe
4. Emit the single-target closing message only

## Failure Classification Guide

Use these labels exactly when reporting failures:

- `environment` — missing local dependency or unsupported shell behavior
- `fixture-drift` — test fixtures or generated artifacts do not match
- `protocol-regression` — skill contract changed without test updates
- `script-regression` — Track's bash behavior is wrong
- `runner-regression` — the unified runner did not enumerate or report cleanly
- `tool-chain-regression` — required tool usage changed
- `closing-message-regression` — closing message no longer matches spec
- `do-not-violation` — a hard constraint was broken
- `budget-or-transport` — headless invocation failed before a valid result

Every reported failure must include:

1. Target (`tests/test-foo.sh` or `skill:validate`)
2. Bucket from the list above
3. One sentence of evidence
4. One concrete next fix

## Closing Message Matrix

Show exactly one closing message after the report:

If mode is `scripts`:

```
Script suite: {PASS|FAIL}
  total: {N}
  passed: {P}
  failed: {F}
```

If mode is `skills`:

```
Skill smoke suite: {PASS|FAIL}
  total: {N}
  passed: {P}
  failed: {F}
```

If mode is `full`:

```
Track test suite: {PASS|FAIL}
  scripts: {SP}/{ST} passed
  skills: {KP}/{KT} passed
```

If mode is `single` and the target is a script:

```
Single test: {target} {PASS|FAIL}
  type: script
```

If mode is `single` and the target is a skill:

```
Single test: {target} {PASS|FAIL}
  type: skill
```

## Do Not

- Do not switch modes mid-run
- Do not run skill smoke tests in the real working tree; use isolated worktrees
- Do not treat exact free-form wording as the assertion target when an
  invariant-based check is sufficient
- Do not skip reading a skill's `SKILL.md` before validating its protocol
- Do not claim success if any required test, invariant, or artifact failed
- Do not edit repo files as part of testing
