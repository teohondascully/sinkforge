# How to add a harness layer

Until this file existed the honest answer to "how do I add a layer?" was *copy the nearest one and hope*,
and that is how fifty layers came to carry six cosmetically different copies of the same eight-line
function. This is the short version; the architecture handover §5 is the long one on what makes an assertion
worth writing.

## The shape

```gdscript
extends "res://tools/check_base.gd"

## Harness layer: ONE SENTENCE SAYING WHAT MUST BE TRUE, in caps, because this is the thing the layer
## exists to protect and every reader should meet it first.
##
## Then the reason it exists — ideally the defect that motivated it, because a guard whose motivating bug
## is written down is a guard the next person can judge. Then NON-VACUITY: say how this layer would fail,
## and what stops each assertion passing by never happening.
##   godot --headless --path . --script res://tools/check_thing.gd

const THING: int = 3

func _initialize() -> void:
    _check(sim.thing() == THING, "the thing is a thing (%d)" % sim.thing())
    _verdict("check_thing", "the thing holds")
```

Then register it in `tools/run_harness.sh`:

```sh
add      "check_thing (what it guards)"  "res://tools/check_thing.gd"   # headless
add_gl   "check_pixels (what it guards)" "res://tools/check_pixels.gd"  # needs a real window
add_excl "check_timing (what it guards)" "res://tools/check_timing.gd"  # needs the machine to itself
```

`add_gl` for anything judging PIXELS — the headless driver paints blank frames, and a "no dead space" pass
on an all-black image is a lie. `add_excl` for anything measuring TIME, which cannot share a box with
fifteen other Godot processes.

## What the base gives you

| | |
|---|---|
| `_check(cond, label)` | assert and print, counting failures. The label is a **sentence about the property**, not a variable name |
| `_verdict(layer, note)` | print the tally, exit 0 or 1 |
| `_skip_layer(layer, why)` | the whole layer did not run — exits 42, never 0 |
| `_stand_down(what, why)` | this layer passed, but some assertions were not made |
| `SKIP` | 42, the runner's reserved "did not run" |

Extend by **path**, not `class_name`: a layer runs under a bare `--script`, which must not depend on the
global class cache being current.

## The exit protocol

```
0    ran, asserted, everything held
1    ran, asserted, something failed
42   DID NOT RUN — stood down whole. Never 0.
```

A layer that returns 0 without asserting anything is the failure this whole suite was rebuilt around: the
runner once printed `ALL 61 HARNESS LAYERS PASS` over four layers that had drawn nothing. The runner now
reports PASS / FAIL / **SKIP** separately and refuses the word "ALL" unless every layer ran.

For a partial stand-down use `_stand_down()`. The `SKIP:` line prefix is a **contract with the runner**,
which greps for it to report "passed without verifying everything" — not a formatting convention.

## The part that actually matters

**A layer that cannot fail is worse than no layer**, because it also spends the credibility of the ones
that can. Before you commit an assertion, break the code and watch it go red. If you cannot make it go
red, you have not written a test.

The failure modes that have actually bitten this project are catalogued in `the working notes` §12 —
thirteen of them, every one from a real green that meant nothing. The recurring ones:

- **An assertion that cannot fail in the environment it runs in.** Two blank textures compare equal
  headless. This is why pixel layers use `add_gl` and stand down rather than pass.
- **An assertion inside a loop that may not iterate**, especially one driven by the constant it is testing.
- **A test that sets the value it then observes.**
- **A floor no configuration can reach**, quietly passing on noise.
- **A fixture that never reached its subject.** `check_underground` judged a sunlit surface frame against
  a standard written for lamp-lit deep rock, because its dig silently never started. **Prove the premise
  before the verdict** — assert the agent got where it was sent, assert the phase did the work its name
  claims.
- **A hand-written list of the ways something can happen.** It is a snapshot with an expiry date and
  nothing prints the date. Derive the list from the source of truth and assert you covered all of it.

## Thresholds

**Measure first, then set the floor.** A number chosen before running the thing is a wish, and this
project has four commits reverting one. State the derivation in a comment next to the constant: what was
measured, on what, and how much slack the number leaves. `check_underground`'s `MIN_DELVE` is the pattern —
it says which observations bracket it and why the gap is safe.

**Never lower a floor to buy green.** If a floor is genuinely wrong, that is an argument to make out loud
with the distribution in hand, not a number to quietly edit.

## Layers that boot a generated world

If your layer's result depends on the seed, add it to `tools/seed_corpus.sh` and run the sweep — every feel
floor in this project's history was measured on seed 1337 alone. Do not add a layer that builds its own
fixture: its columns will be identical across every seed, which the corpus flags as **SEED-BLIND** rather
than counting as coverage.

## Before you push

```sh
tools/run_harness.sh                # unpiped — piping makes the exit code `tail`'s and hides a red layer
SF_HEADLESS=1 tools/run_harness.sh  # what CI actually runs
```

Both. A GDScript headless-guard cannot skip a layer Godot never boots, and that distinction once kept CI
red for thirty-three pushes. And take the harness lock — anything that boots Godot shares one `user://`,
because Godot keys it on the project **name**, not the directory. Worktrees do not save you.
