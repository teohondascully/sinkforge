> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot despite `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 recommending KEEP as-is. The doc set that actually shipped (`docs/README.md`'s normative table) is
> smaller than the plan recommended — a later, real decision, not corrected here. A working document for
> a pre-pivot hardening tranche; the tranche's own target code is now under `legacy/`. Moved here while
> closing the `.git/info/exclude` hole (ANVIL step 1). Kept for provenance.

---

# Release hardening ledger

Working document for the post-push hardening tranche. Not published; kept on disk and excluded
locally rather than through `.gitignore`, because the ignore file ships and would carry the name.

## Phase 0 — baseline

| | |
|---|---|
| Baseline commit | `bd2b1d72556bf400adfbf313e369570ca92fcb13` |
| `origin/main` | identical — pushed `aa52ace..bd2b1d7`, 153 commits, fast-forward |
| Divergence | 0 ahead / 0 behind |
| Dirty tracked files | 0 |
| Untracked files | 0 |
| Worktrees | 42 (8.5 GB; 20 of the 50 branches have zero unique commits) |
| Open bus directives | none (0056 and 0059 resolved) |
| Off-repo freeze | `/Users/thondascully/Projects/sinkforge-freeze-20260820` (900 MB, 890 commits, 37 refs) |
| Rescued object | `8a3f713`, tagged `rescued/machine-identity`, bundled into the freeze |

Reproducibility: the baseline is a clean tree at a pushed commit, so any measurement below can be
re-taken by checking out `bd2b1d7` and running the command named beside it.

## The four reds, with current disposition

### 1. `worldgen` — frontier richness margin

    the frontier richness edge is a meaningful margin, not noise (1.13x spawn)

Status: **open, design question.** Not yet investigated in this tranche. Requires a seed corpus and
a rejection-reason histogram before any constant is touched. No ruling exists yet.

### 2. `check_rock_reads` — rock against air in the dark

**Status: the layer is not stable enough to gate on, and the game is genuinely marginal. Both are true.**

Five serial runs on identical code at `bd2b1d7`:

| run | best cue | | run | best cue |
|---|---|---|---|---|
| 1 | 74.69% | | 4 | **75.91% pass** |
| 2 | 73.44% | | 5 | **75.91% pass** |
| 3 | 71.67% | | | |

    mean 74.32   median 74.69   range 71.67 – 75.91   spread 4.24   floor 75.00

Two of five runs pass. The layer's own source already records the mechanism: the delve lands in a
slightly different place each run, and the statistic pools every rock cell against every air cell in
whatever frame results. The renderer comment at `world_renderer.gd:3853` states the historical spread
as 53-63% on identical code.

Two separate defects follow, and they must not be conflated:

- **The instrument.** A gate that returns pass on 2 of 5 identical runs is reporting where the delve
  landed. It needs either a fixed sampling region or enough samples to collapse the spread, and its
  verdict should be a mean or median against the floor, not a single reading.
- **The subject.** The mean sits 0.68 under the floor, so the cue really is short. Measured
  medians: rock luminance 11.7 against air 9.0, and rock grain 2.98 against air 1.86.

**No constant has been changed.** Tuning `VOID_FLOOR` against a single 73.62% reading would have been
fitting to a sample from a 4-point distribution. The prior history is a caution in the same direction:
the void was once *brighter* than rock (air 12.0, rock 9.4, 56% readable), and the fix for that was
subtractive on empty cells rather than a global lift.

Open question for the ruling: whether air's grain of 1.86 is legitimate. Empty space should be close
to flat, and a flatter void would sharpen the grain cue without touching brightness at all.

### 3. `check_texture` — paint roughness

    roughness 6.53% (ceil 6.50%)   lag-1 0.91 (floor 0.55, passing)

**Status: population mismatch. Evidenced, and the opposite character to item 2.**

Five serial runs give **6.53% every time, zero spread.** Deterministic, so the excess is real and not
noise. It is also nowhere near visible: the ceiling's own calibration puts 5.9% at "reads as rock",
6.5% as a guard rail whose "job is to stop the slide back, not to name a target", and 12.7% at
"unmistakably a grid of tiles at any magnification".

The history came out of the retained sweep logs rather than a bisect. Filtered to the main tree on
branch `main`, 42 sweeps give four states:

| first observed at | across | down |
|---|---|---|
| `be91925` | 6.0% | 5.6% |
| `ff3acc4` | 5.9% | 5.7% |
| `588d891` | 6.4% | 5.7% |
| `d5fe87d` | 6.5% | 6.1% |

**The 5.9 to 6.4 step is legitimate and deliberate.** `598a530` found that this layer's rebake never
wired `grammar_at`, so it had been measuring a flattened all-clastic world that never runs, reading
5.93% while the game printed 10.40%. The paint was then retuned (`GRAM_SEAM` 2.20 to 0.70) to 6.4%,
described in that commit as "the value that clears the calibrated ceiling". It left 0.1 of headroom.

**The 6.4 to 6.5 step is not a paint change at all.** No commit in `588d891..d5fe87d` touches
`scenes/fine_terrain.gd` or `src/data/materials/`, and the only `src/core/fine_terrain.gd` change is
comment-only. What did change is `9d1841c fix(worldgen): scatter shelf bands instead of banding rows
0 to 31`, a 615-line rewrite of `layered_world_gen.gd` altering depth-banded material placement. The
layer bakes the real world through `sim.material_at(c)` over rows 60 to 110, so a change in which
materials sit in that band moves the pooled roughness with the paint untouched.

**Recommended disposition, no threshold change.** The layer is named for paint but measures paint
convolved with worldgen, so any worldgen edit can move its verdict. Assert per material, or hold the
material mix fixed in the fixture, so the number is a property of the painter. That is an instrument
repair rather than a threshold move, and it would have caught the real 10.40% defect too.

### 4. `play-tests` — third progression rung

    RUNG 3 — the L2 iron chain (missed twice)   15 pass / 1 fail

Rungs 1 and 2 pass. Fails serially as well as under the sweep, so it is not contention. Under
diagnosis; the question is whether the goal is unreachable, the pilot cannot execute it, or the
success predicate is wrong.

## Known skips at baseline

| Layer | Stood down | Reason |
|---|---|---|
| `check_frametime` | 1 | 8.33 ms budget not asserted without a declared performance host |
| `check_text_contrast` | 2 | bright-backdrop column has no decided bound |
| `check_ceremony_reads` | 2 | legibility against open sky has no decided bound |
| `check_grapple_reads` | 1 | previous cap was `1.01` over a quantity bounded at `1.0` by construction |

## Contention findings, carried forward

Two layers fail under `JOBS=12` and pass alone. CI's pixel job already runs `JOBS: "1"`, so neither
reaches CI, but the local default does not:

- `check_grapple_reads` — registered `add_excl`, passes alone three times with identical readings
- `check_material_grammar` — passes alone

## Tests to re-run after each phase

    bash tools/run_harness.sh                                  # full sweep
    bash tools/with_machine.sh --script res://tools/<layer>.gd  # serial re-run of any failure
    bash tools/capture_manifest.sh --check                     # capture manifest gate

A red under parallel jobs is not a red until it is re-run serially. A single reading of a layer with
a known spread is not a result.
