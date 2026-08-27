# Convergence ledger

UNTRACKED. Opened 2026-08-23 as a mandatory operating lane. **One `main`, one canonical worktree, one
active writer.** Disposable worktrees only for explicitly isolated evaluation or read-only comparison.

**Nothing has been deleted.** Every disposition below that ends in "close" is QUEUED at the authorization
boundary, because deleting a branch or a ref is on the stop list. Preservation happened first, in both
cases, and is verified rather than asserted.

## Active worktrees

| path | base SHA | owner | file scope | expiry | purpose |
|---|---|---|---|---|---|
| `/Users/thondascully/Projects/sinkforge` | `defdc44` (`main`) | the coordinator, sole writer | everything | none, it is canonical | the product |
| `/private/tmp/sinkforge-agent-journey-eval` | created from `main` at `4b7e160`, now `dacfd4c` | lane A | `tools/eval/**` ONLY | on the director's next review, or once its patch and receipts are archived | agent-journey readiness laboratory |

The lane A worktree **does not overlap another lane**: no other lane may write `tools/eval/**`, and lane A
may not write `scenes/`, `src/`, gameplay, Freight, HUD, terrain, the harness registry, thresholds, or
canonical captures. It is disposable and **will not become an alternative product branch**: it is detached,
it may not push, and its work reaches `main` only by cherry-pick or re-derivation after review. Its patch
is already archived at `docs/handoff/lane-a/0001-*.patch`, so the worktree can be destroyed at any moment
without losing it.

## Active branches

| ref | head | ahead/behind vs `main` | disposition |
|---|---|---|---|
| `main` | `defdc44` | canonical | the single source of truth |
| `origin/main` | `9377a91` | `main` is 5 ahead, 0 behind | receipt written; push at the boundary, NOT taken |
| `localmain` | `22bb4e0` | 850 unique / 979 the other way | **OBSOLETE. See below.** |

## `localmain`, and why the counts are not the evidence

`localmain` is a remote-tracking ref at `22bb4e0`, dated **2026-08-20**, three days behind. It reports
**850 commits not on `main`**, which looks like a large divergent branch and is not one: `main`'s history
was rewritten on 2026-08-19, so those commits are the same work re-hashed. **Commit counts here measure
re-hashing, not divergence**, which is exactly why the rule is to compare sets and content.

Compared as sets rather than counts: **162 commit SUBJECTS on `localmain` appear nowhere on `main`.** By
type they are **153 `docs`, 3 `chore`, and 6 candidates for lost code**. The 153 are the process corpus the
history rewrite deliberately removed, which is a rejection already made and recorded, not a loss.

**Every one of the 6 was checked by content, not by message:**

| candidate | verdict | evidence |
|---|---|---|
| `harness: agentic play-tests (layer 6)` | already integrated | `tools/play_tests.gd` is on `main` and registered |
| `Run the agentic play-tests under the game clock` | already integrated | same file |
| `Merge branch 'worktree-agent-...'` | no unique content | a merge commit |
| `fix(6b): the contact fixture was running the lens...` | **already integrated** | `tools/check_contact_edge.gd` is 814 lines on BOTH refs and **every difference between them is a comment**; zero non-comment lines differ |
| `fix(save): declare _ruins_cache's disposition` | **`main` is strictly better** | the only non-comment difference is that `localmain` HAND-ROLLS the verdict tail (`if _failures == 0: print; quit(0)`) where `main` routes through `_verdict()`. That hand-rolled tail is the precise defect the verdict-route conversion removed and `check_verdict_route` now gates. Taking `localmain`'s version would reintroduce it. |
| `feat(coordination): add the director bus` | **untracked authored work, preserved** | see below |

### The one real finding: two authored files tracked on `localmain` and absent from `main`

    tools/director_bus.sh        8034 bytes   tracked on localmain, ABSENT on main, PRESENT on disk
    tools/test_director_bus.sh   3256 bytes   tracked on localmain, ABSENT on main, PRESENT on disk

Both on-disk copies are **byte-identical to `localmain`'s tracked versions** (`git show localmain:<f> | cmp
- <f>`), so nothing has been lost and nothing needs re-deriving. The history rewrite untracked them because
they are peer-session coordination tooling, which is the process corpus it was removing. They are archived
outside the canonical tree anyway, because untracking is deferred deletion: a file that is present only as
an untracked working-tree copy is one `git clean` from gone.

**Disposition: leave untracked on `main`, keep on disk, archived.** Re-tracking them would put session
coordination back into a public portfolio repository, which is the thing the rewrite existed to undo.

## Tags

All seven predate the rewrite and none is contained in `main`. They are the same class as `localmain` and
carry the same content, so they are **obsolete as refs and preserved as history**. Not deleted.

    baseline/2026-08-21-converged   a67bc1a      candidate/2026-08-21-domain1  2b9eb8b
    freeze/capture-deafness-...     2e94c91      pre-lode                      27fe6a3
    pre-merge-capture-deafness      a697d23      pre-msg-rewrite               af99f20
    rescued/machine-identity        8a3f713

## Preservation artifacts

    /Users/thondascully/sinkforge-archive/prerewrite-refs-2026-08-23.bundle    302 MB
        localmain + all 7 tags. `git bundle verify` reports "The bundle records a complete history."
    /Users/thondascully/sinkforge-archive/untracked-on-main/director_bus.sh
    /Users/thondascully/sinkforge-archive/untracked-on-main/test_director_bus.sh

Outside the canonical tree, as required. The bundle is the rollback for every disposition above: any ref
in it can be restored with `git fetch <bundle> <ref>`.

## Other refs

`23dce828` is a dangling commit, and it is the known one: it appears in an old session's start-of-run
snapshot and sits on no branch, because the rewrite landed between it and the next commit. Any SHA quoted
from before `c3e5284` may be orphaned; check with `git merge-base --is-ancestor <sha> main` before citing.
No stashes. No other worktrees. No local branches besides `main`.

## Definition of done, against the director's five criteria

1. **Valuable work re-derived or explicitly rejected** — yes. 6 candidates examined by content; 5 already
   present or superseded, 1 explicitly rejected with a reason.
2. **No unowned authored files lost** — yes, and this is where the one real finding was. Two files,
   verified byte-identical, archived.
3. **No unexplained branches or worktrees** — yes. Three refs, one laboratory, all classified above.
4. **`main` is the only canonical product state** — yes.
5. **The next session can resume from one current state without archaeology** — this file is that state,
   alongside `Current status` in `docs/handoff/OVERNIGHT_RUN_STATE.md`.

## Queued at the authorization boundary, not taken

- **Delete `refs/remotes/localmain`** and the seven pre-rewrite tags. Preserved in the bundle and proven
  to carry nothing `main` lacks. Deleting a ref is on the stop list, so it waits for an explicit yes.
- **Push `main` to `origin/main`**, five commits. Receipt at `docs/handoff/RELEASE_RECEIPT_2026-08-23b.md`.
- **Destroy the lane A worktree** once its receipts are archived. Its patch already is.
