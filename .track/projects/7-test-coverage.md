# Automated Test Coverage

## Goal
Comprehensive testing for all Track scripts and skills. Bash scripts tested via existing harness; skills tested via agent-driven orchestration. A single `/track:test` skill runs everything.

## Why Now
Track has 7 test files but only 4 run in the main test command. No test exercises the full task lifecycle across scripts. Skills have zero automated testing — protocol compliance is verified only by manual usage. As more repos adopt Track, regressions become costlier.

## In Scope
- Unified test runner for all bash script tests
- End-to-end lifecycle tests across scripts
- Error message and edge case coverage
- `/track:test` internal skill for intelligent test orchestration
- Skill smoke tests via `claude -p` headless invocation
- Investigation of promptfoo and sub-agent testing patterns

## Out Of Scope
- Testing vendor-specific plugin or package repos
- Web UI or visual test dashboards
- Performance benchmarks
- GitHub API integration tests requiring live `gh` auth

## Shared Context
Scripts live canonically at `skills/init/scaffold/track/scripts/`. Test harness uses `run_test()`, `assert_eq()`, `check_contains()` patterns. Skills are LLM protocols — testing them requires running an actual agent via `claude -p --plugin-dir . --output-format json --bare`.

## Dependency Notes
Independent of project 1 (blocked status). If blocked status lands first, tests should cover it, but that is additive.

## Success Definition
- A single `bash tests/run-all.sh` runs every script test file
- Every `print_error` call in `track-validate.sh` has a corresponding test
- Each skill has at least one smoke test validating protocol compliance
- `/track:test` can run the full suite and produce a structured report

## Candidate Task Seeds
- Unified test runner
- `/track:test` skill
- E2E lifecycle tests
- Validate error coverage + TODO accuracy
- Script mirror consistency
- Skill smoke tests via `claude -p`
- Promptfoo investigation
- Sub-agent testing investigation
