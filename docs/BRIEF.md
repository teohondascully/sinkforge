# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-01. This round: the overnight run — eighteen PRs merged green (#16–#34), ledger
D0286–D0314, every one rebase-merged with authorship clean.** WG-4 fully converted, five legacy ports
landed with their sources named, and **six separate greens found to be measuring nothing.**

**Headline: a capture diff of ZERO pixels has two causes — the painter drew nothing, or the moment did
not pose it — and nothing in the output separates them.** `SeamPainter` shipped correct, mounted on the
real coordinator, mutation-tested, and its verification read **0 of 2,073,600 pixels changed**, which is
exactly the signature D0289 taught this project to read as a dead layer. It was not the painter. The
move that separates the two, in one run, is an **ungated full-viewport fill from the same layer**: it
read 99.8% and proved the plumbing live and the gate closed. Then the fix went stale **inside the hour**
when a world constant moved under it, and the replacement control passed on a frame that *still* diffed
at zero — because the subject was **posed and off-camera**. "Posed" and "in frame" are different claims.

---

## What landed

**WG-4 is fully converted (D0305, D0307).** `cave.frequency` 0.11 → 0.0656, tuned and BUILT-PARKED per
your ruling. The sweep behind it **falsified two predictions, one of them load-bearing**:

| `freq` | lateral periods | void | pockets | median pocket | shelf carved |
|---|---|---|---|---|---|
| `0.11000` (before) | 2.51 | 0.0866 | 271 | 7 | 1 / 46080 |
| **`0.06560` (shipped)** | **1.50** | **0.0845** | **139** | **15** | **6 / 46080** |
| `0.02750` (metre-correct) | 0.63 | 0.0822 | 47 | **121** | **0 / 46080** |

The metre-correct value does **not** make lateral caves vanish — it **consolidates** them, seventeen-fold.
And **void fraction is flat across the whole 4× range**, which excludes `MASTER_PLAN_AUG30`'s stated
most-likely explanation for P021's missing 15%.

**Five ports, sources named.** The grain reveal (**D0308**, `world_renderer.gd:2262-2344`) — which
closed PRE-4 and gave `core/seams.gd` its first caller after four sessions unwired behind one `int`. The
stride and the stagger (**D0310**, `player.gd:45-71, 411-432, 625-643`), T1 #9 and #10. Per-material
strike voices (**D0313**, `sfx.gd:26-35`). The bedding depth boost (**D0312**,
`world_renderer.gd:1591-1594`) and `cave.frequency` (**D0307**) are the other two, both below.

**PRE-1, PRE-3 and PRE-4 are all closed** and `LEGACY_GAP` had recorded none of it. **PRE-2, the `Fx`
vector layer, is the only prerequisite genuinely open** — verified in the tree, not inferred. It gates
the grapple.

---

## What was learned

**The house failure class ran six times this session and five were my own instruments.** Listed
together because the shape is the lesson:

1. **A capture that could not pose its subject** (D0309/D0311) — above. Twice, with the second failure
   being a control that answered a *different question* from the one that mattered.
2. **A suite printing `ALL PASS`, exit 0, with three tests calling methods that no longer existed**
   (D0310). Only the D0115 masked-crash detector failed the run.
3. **A palette test measuring a material that does not exist** (D0312). `matrix_color` answers an
   unmapped material with a flat debug brown, so every patch measured a **constant**; spread read 0.0000
   at both depths and the surviving comparison was `0 >= 0` and **passed**.
4. **A mutation escaping because the population could not pose the gate** (D0308). The assertion "every
   cell shares the worked cell's seam" was posed on a HORIZONTAL run — which walks `(1,0)`, and
   `Seams.at` keys HORIZONTAL to the row. Every cell in it is horizontal *by construction*.
5. **A probe wrong by a factor of fifteen** (D0314). It carved an already-carved grid and reported 66
   shelf cells where the truth is 990. Only routing the *suite* through the same function exposed it —
   **a shared implementation is a parity check that runs itself.**
6. **A shipped Tier-0 closure resting on one cell** (D0307) — see below. The only one that is not mine.

**And two harness traps I had already recorded and hit again:** `grep -c "ALL PASS"` as a pass detector
matches `run_gd_test`'s own *"never printed its own ALL PASS line"* failure; and `godot ... | grep -m2`
kills the engine with SIGPIPE **before the shutter fires**, writing no PNG while reporting nothing wrong.

**Constants do not all convert the same way, and the check is comparing them, not reasoning about
them.** WG-4 converts world-gen by ×4/×16/×0.5 because legacy's cell was a metre. The body is the
**opposite regime**: `RUN_SPEED` 150, `GRAVITY` 900, `JUMP` −365, `MAX_FALL` 560 — four for four against
legacy. So the stride and stagger port in **pixels**, unchanged. Converting them would have been the
right procedure in the wrong regime.

---

## The decisions this round is waiting on

**P028 · ANSWERED, and the answer changes P026 (D0314).** The 200-seed run is done. **990 shelf cells of
3,072,000 — the mechanism is REAL**, WG-3's octave port genuinely gave the field a tail, and D0258's
sentence is correct. **And 62.5% of individual seeds carve no shelf cell at all**, so `shelf_frac > 0.0`
over six of them is a lottery: the shipped suite passes on **1 of its 6 seeds**, now printed every run.

*What is yours:* whether to replace it with a rate criterion. My own P028 proposed "≥1% of the non-shelf
rate" — **measured, it is 0.52%**, so my recommendation would have failed a correct build. Derived, the
threshold is ~0.3%.

***And this un-blocks P026.*** D0307 read "0 of 46,080 over 3 seeds at `cave.frequency` 0.0275" as WG-2
re-opening. Against a base rate where 62.5% of seeds carve nothing, **three zeros is expected ~24% of the
time at the shipped frequency**. **The blocker on the seventeen-fold larger cave was a sample size, not a
defect** — and that reasoning was mine, hours earlier, drawing a categorical conclusion from n=3.

**P029 · legacy's bedding boost and this build's glimmer floor cannot both be satisfied.** Legacy's 2×
requirement needs a constant ≥1.83; anything above ~1.0 pushes deepstone inside glimmer's shipped **0.25**
distinctness floor, and glimmer is the reveal material. **No value satisfies both.** Shipped 1.0 — the
largest that breaks nothing, still a **53% recovery** of post-veil deep spread. Option (2) in the entry,
re-hueing glimmer away from deepstone, buys the whole range back and is an art call.

**P026 · `cave.frequency`** — BUILT at 0.0656, full sweep table in the entry. **P027 · the veil's two
missing halves.** **P004 · the per-commit fuzzer** now provably cannot pose a third mechanic: its longest
unbroken heading in 50,000 ticks is **10**, against the **55** a stride needs.

---

## Anything that felt wrong even though it passed

**I merged PR #30 before its post-rebase CI reported.** The branch had been green, I rebased it twice
more against a moving main, and the `until` loop I used to wait returned an empty string rather than a
count — so it fell through and the merge went ahead. **Main was then verified directly** (seven suites
plus every structural gate, all green, and CI on main is green), so the outcome is fine and the
*process* was not. A wait condition that can't distinguish "zero pending" from "I couldn't tell" is the
same defect class as everything in "What was learned", one layer up.

**The `grain` capture moment is pinned to a tick, and a tick is a claim about a world.** It went stale
once already, within an hour. It now carries its own positive control and the tool fails when the frame
does not contain the subject — but the underlying fragility is unfixed: the right answer is a shutter
that holds until its subject is posed, and I did not build one.

**A probe I wrote to answer P028 was wrong by a factor of fifteen, and only parity caught it.** Its first
version carved an already-carved grid; it reported 66 shelf cells where the truth is 990. What exposed it
was routing the *suite* through the same function and finding the six-seed numbers no longer reproduced.
**A shared implementation is a parity check that runs itself** — two copies would have let the tool be
confidently wrong forever.

**Five of the six "instrument measured nothing" findings were in code I wrote this session.** The rate
is not obviously falling. The one structural improvement that came out of it is worth more than the
individual fixes: *when a verification reads zero, the second move is an ungated full-strength version of
the same thing* — it separates "the mechanism is dead" from "the gate is closed" in a single run.

---

## Blocked, and what it's waiting on

**Nothing is in flight.** Every branch this run opened is merged and deleted; **zero open PRs**, and
`origin/main` is green.

**Determinism held at every world and body change** — two processes bit-identical (first mismatch −1),
seed+1 control diverging at checkpoint 0, at all three re-pins. Goldens harvested from CI's own Linux
build per D0167 and cross-checked elementwise against local macOS: **0 of 200 differ, all three times.**

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
