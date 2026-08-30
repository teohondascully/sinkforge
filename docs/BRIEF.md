# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: gate hygiene and the last unblocked lifts, under a new
PR workflow. 5 commits across 2 PRs. `docs/DECISIONS_LEDGER.md` D0224-D0232.**

**Headline: a REQUIRED CI check had never evaluated a single dependency edge.** `layer_lint` printed
PASS on every commit for weeks while reporting, in its own output, `0 references checked` — it matched
`res://` paths against a codebase that couples entirely through `class_name` globals. **38 edges resolve
now and none is a violation**, so the boundaries genuinely hold; that is a measurement where there was an
assumption. The last ~586 liftable lines came over and **the batch is genuinely dry.** `docs/NEEDS_DIRECTOR.md`
is down to **6 items** and one of them, P010, is an operating rule you need before your next merge.

---

## What was learned

### A caveat in a docstring does not travel with a verdict

`layer_lint.py` carried an explicit paragraph saying it could not see `class_name` coupling and that a
PASS from it must not be read as "the dependency graph holds". That paragraph was **correct, prominent,
and worth nothing**: the gate sat in CI as a required check named "structural gates (layer boundaries,
…)", printed PASS, and had never once evaluated an edge. Nobody reads a tool's docstring at the moment
they read its verdict. **The fix is not a better caveat — it is putting the number in the output**, so
every run now prints the edges it actually resolved and the 14 it deliberately does not judge.

### The insight was already in the repository, in the tool next door

`tools/quality_check/coupling.py` had made this exact discovery earlier and written it down: a real check
against this tree found "**ZERO res://-based sim/ references but 13 class_name declarations**", so it
unions path edges with `class_name` edges. One tool knew the codebase's dominant coupling mechanism was
invisible to path scanning; the gate whose entire job was policing that coupling never got the memo.
**Two instruments over one subject, and only one of them was told.**

### The conversion that looks obviously equivalent

`seams.gd` could only enter `sim/` if its float rates became integers — `sim/` is deterministic by
contract and a float comparison is what differs between machines. The obvious form, `v < int(0.18 *
65535)`, **disagrees with the original on exactly 3 inputs out of 196,608** — one per rate, invisible to
any sample, and it would have silently re-grained one plane of every world. Caught by sweeping the whole
domain instead of sampling, and the wrong form is kept in the suite as a control that must keep failing.

### Branch protection made the merge button load-bearing

The authorship gate failed the first PR on a clean history: GitHub's synthetic merge commit is a second
committer identity. Pinning the job to the PR's real head fixes that. **What it cannot fix:** a
merge-commit or a squash-merge through the UI writes `noreply@github.com` permanently into `main`, and
the gate reads `git log --all`, so authorship would then fail on **every commit afterwards** with no
remedy short of a history rewrite. **Merge by rebase.** Verified: `main` still has one committer identity.

### Two of my own defects reached CI, both the same shape

A coordinate-naming violation in the file I had just written (I ran the gate set *before* writing it), and
an `ImportError` from inlining a function whose caller lived in another directory. **Both are "the corpus
I checked was smaller than the corpus that matters"** — a stale gate run, and a grep scoped to the file I
was editing. Now mirrored: the whole gates job, 27 checks, run locally before every push.

---

## Gates

**All 38 suites pass**, including four new ones. **Gate 7 (LOC velocity) is GREEN and the lifts are why**:
instrument +1,624 against game +1,249 over the window, **1.30x under a 2x limit**, game LOC 3,075 → 3,760.
The gate fixes alone measured **2.24x and FAILED** — which is why the two themes had to ship together, and
worth knowing before you plan a gates-only run.

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md`, 6 items.** Closed and deleted this round: P002, P003, P005, P006, and P007's
two free sub-items.

- **P010 — read this before your next merge.** Rebase only; merge-commit and squash both poison
  authorship permanently. You may prefer to disable those two buttons in repository settings.
- **P008** — the layer lint resolves `class_name` edges but cannot judge 14 that cross a sim module
  boundary, because `sim/world` has no `world.gd` and the convention says it should. Three ways to
  answer, cheapest being to amend §3 to match what the code already does.
- **P009** — `light_layer.gd` was lifted as ruled, and it is banked value for the parked coordinator,
  which is the criterion you declined option 2 by. The two decisions ought to agree.
- **P001, P004, P007** unchanged: the fuzz ratchet, the fuzzer's world, and the determinism-contract
  running hash. All still entangled, all still yours.

Carried, unchanged: **`grounded_no_floor`'s residual** (46); **Slice 1.5's bite radius**, `docs/TASTE_QUEUE.md`
T004; **the body/world proportion**; the **persistent-world GDD reversal** whose text exists only in
pre-compaction history.

## Blocked, and what it's waiting on

- **The coordinator rebuild is the keystone and it is the next thing we do together.** ~1,540 lines of
  world rendering unblock at once and it is the only route to changing how the game looks. Everything this
  run could reach without it has now been reached.
- **`data/economy/` D1-D6**, **line of sight**, the **`ValueNoise` float gap** (D0171/D0172), **three GDD
  contradictions** (D0177), **`history/`'s 168-image cull** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001 (`ore_copper` reads silver), T002 (band tint at 0.10), T003 (mining times),
T004 (the bite radius).
