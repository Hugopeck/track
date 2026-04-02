# Session Handoff Reference

Read this when you need exact tracked vs untracked PR examples or when an
untracked session is being promoted to tracked work.

## Tracked PR template

```text
Track-Task: 1.7
Also-Completed: 1.5

## Summary
One short paragraph covering the full PR diff.

## Test plan
- [ ] Specific verification step
- [ ] Another verification step
```

Use at most one `Track-Task:` line.

## Untracked PR template

```text
untracked task

## Summary
One short paragraph covering the full PR diff.

## Test plan
- [ ] Specific verification step
```

Untracked PRs are valid. Do not force Track linkage until one task
deterministically matches.

## Ready-for-review handoff

1. Verify acceptance criteria using `MET`, `PARTIAL`, or `UNVERIFIED`.
2. Mark the draft PR ready for review.
3. Let PR lifecycle automation move tracked work to `review`.
4. Do not call `bash .track/scripts/track-ready.sh {id}` from the skill.

## Untracked → tracked promotion

Use this only when one task deterministically matches and the work is cohesive.

1. Run `bash .track/scripts/track-start.sh {id}` if the task is still `todo`.
2. Add a dated note explaining that the current branch was previously untracked.
3. If branch history needs retroactive attribution, emit a `track.link` event.
4. Replace the untracked PR body header with `Track-Task: {id}`.

## Recovery

- If PR state and task state drift, use `bash .track/scripts/track-reconcile.sh`.
- If overlap comes from stale `active` or `review` state, repair the stale task;
  do not hand-edit another task's scope.
- For exact mergeability and PR-body rules, read `.track/specs/pr-instructions.md`.
