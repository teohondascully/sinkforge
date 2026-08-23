# Branching

`main` is the only long-lived branch, and it is the only branch that is ever canonical. Everything else
is temporary by construction.

This document exists because the repository once carried 58 branches across 49 working trees. Nothing was
lost, but the inventory itself became misleading: thirty of those branches were "ahead of main" and none
of them were pending work. An ahead-count that means nothing is worse than no count, because it reads as
a backlog and invites merging.

## The workflow, as it actually runs

One clone, one working tree, `main`. Work lands as a sequence of small commits pushed straight to
`origin/main`, each one green on the configured sweep before it goes -- green meaning
`110 PASS / 0 FAIL / 0 SKIP` with `HARNESS_RESULT=yes` and no stand-down outside the registered set. It is
deliberately not called a FULL sweep: conditional assertion groups stand down under `SF_STRICT` and the
runner prints "this run does not count as a full sweep" whenever any did, which on this tree is every run. There is no feature branch, no integration
branch, and no merge: the history is linear because nothing else is ever open.

This is a deliberate reversal. The rules below were written after the repository reached 58 branches
across 49 working trees, and they describe how to close a branch safely because closing them was the work
that had to be done. Keeping them is not nostalgia — a branch is still occasionally the right tool, and
when one exists it declares the four things below. But the default is now that one does not exist.

A **temporary worktree** is a different thing and is allowed: a second checkout used to run a comparison
against another commit, or to hold a control while the canonical tree carries a treatment. Three rules
govern it, and they exist because each has already been paid for:

- It is for **reading**, not for building. Authored work goes in the canonical tree.
- **Never copy generated files out of one** — `.uid` and `.import` belong to the tree that produced them,
  and carrying one back is how a stale identifier reaches a commit.
- Remove it only after proving it holds nothing unique: `git status --porcelain` in it, every entry either
  preserved or classified as generated, and no process still running against it. Then `git worktree prune`.

`git worktree list` showing a single row is the normal state, and is worth checking before a release.

## Every branch declares four things

A branch with no owner is a branch nobody will close.

| Field | Why |
| --- | --- |
| owner | one person, named. Not a team, not a role. |
| purpose | one sentence. If it takes two, it is two branches. |
| base SHA | the exact commit it was cut from, so drift is measurable rather than felt. |
| expiry | a date. Not "when it's done". |

Record them in the branch's first commit message or its pull request body. An undeclared branch is
treated as expired.

## Rules

**One convergence checkpoint is the maximum life of a branch.** Past that it is renewed explicitly, with
a new expiry and a restated purpose, or it is closed. Renewal is a decision someone makes, not a default
that happens when nobody looks.

**No two live branches edit the same subsystem.** Parallel work on one subsystem produces two plausible
implementations and no way to say which is canonical. Sequence them instead.

**A branch substantially behind `main` is re-derived, not merged.** This is the rule that matters most and
it is the least intuitive. Merging a stale branch imports its whole history, including decisions that were
superseded on purpose, and a merge silently drops whatever nothing on the branch happens to reference. The
safe procedure is: inventory the branch's commits by domain, identify which solve problems still open on
current `main`, re-derive those onto `main` one domain at a time, run the suite after each, and record
what was rejected so it is archived rather than forgotten.

**A completed slice returns to `main` before the next one starts.** Not "before the feature ships".
Before the next slice.

## Closing a branch

Closing is not deleting. Nothing is removed until it is recoverable from somewhere else.

1. Snapshot the branch ref under `refs/archive/<date>/<name>`. A tag or archive ref keeps every commit
   reachable after the branch ref is gone.
2. Classify the working tree with `git status --porcelain`, never with a diff. **`git diff HEAD` cannot
   see untracked files.** A preservation pass built on diffs once captured zero of 175 untracked paths and
   reported success, because a diff of an untracked file is empty and an empty diff looks like no change.
3. Copy authored untracked files out of the tree bodily. Separate them from generated sidecars first, by
   listing the untracked set by extension: the census that matters is which of them a person wrote.
4. Save tracked modifications as a patch.
5. Verify the copies against their sources with `cmp` before removing anything, and reconcile the counts:
   every porcelain entry is either preserved or explicitly classified as generated.
6. Only then remove the working tree and delete the branch ref.

## Recovering archived work

    git for-each-ref refs/archive                    # what was archived, and when
    git log --oneline refs/archive/<date>/<name>     # read it
    git switch -c <new> refs/archive/<date>/<name>   # bring it back

Archive refs are local. Push one as a tag before relying on it surviving a fresh clone.
