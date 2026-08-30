# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: the third teleport closed, then Slice 2 — `interface/` exists, the
build makes a sound, and mining throws chips. 7 commits, `c953117`..`5c655b7`.
`docs/DECISIONS_LEDGER.md` D0213-D0220, `docs/adr/0007-l2-interface.md`.**

**Headline: the instant-translation class is closed at its third and last instance, and L2 is real.
`interface/` and `sim/commands/` stop being skeletons, which was the literal blocker on the presentation
batch. But the batch itself is mostly blocked by the run's own non-negotiable — measured, not guessed —
and `docs/NEEDS_DIRECTOR.md` is a new file carrying six parked items. Read it before this one.**

---

## What was learned

### A gate that cannot pass is a deletion, not a gate

The brief asked for the corner nudge to be gated the way step-up and mantle were: on being grounded.
`resolve_ceiling` is reached only while moving upward, `move_and_resolve` clears `on_floor` before any
substep, and `_handle_jump` zeroes coyote on launch — so every corner correction that has ever fired ran
at `on_floor=false, coyote=0`. Applying that gate and re-running measured the consequence rather than
arguing it: **`corner_correction_success_rate` went from 100% to 0.** A ceiling is only ever contacted
airborne. What the three instances of the class actually share is the CONSENT half — `_try_climb` has
required `vel_x != 0` all along, and this was the one instant translation in the module with no motion
condition of any kind. **The right generalisation was one clause over from the one that was proposed, and
only a mutation test could tell them apart.**

### A regex over a file that does not parse still finds every string it is looking for

Two CI step names written with an unquoted colon made `harness.yml` invalid YAML. **GitHub ran zero jobs**
on that commit and reported it as an ordinary red push; gate 31 read the same bytes locally, found every
`res://tests/test_*.gd`, and printed PASS. Worse than an ordinary blind spot because of what the file IS:
a workflow that cannot load runs no gate, so every OTHER gate's verdict for that commit was also
unchecked, and nothing anywhere said so. The gate parses first now, and its mutation test asserts the old
regex-only version still matches through both broken files — the claim made checkable, not described.

### The fuzzer is only as wide as the geometry it is pointed at

D0213's consent invariant reports **0 in the fuzzer with the defect present and 0 with it fixed**, so its
green means nothing. Isolated rather than assumed: wiring the same line to `bounds_violation_this_tick`
prints 922, so the count path works and the CONDITION is never reached. The first explanation written
down was wrong — it blamed the input distribution, and the shaft replay running the identical goalless
driver falsifies that by hitting the case twice. **The cause is the WORLD:** `HostileChamber` fires
`corner_corrected_this_tick` **0 times in 50,000 ticks**, because D0055's hand-placed corner tile stopped
being reachable once the held-jump bug it was fitted against was fixed, and nobody re-placed it.

### "No unsatisfied dependency" and "has a consumer" are different questions

Six of the migration map's 63 LIFT files reference no missing legacy type. Reading them: `art.gd` loads
sprites from a directory that does not exist, `light_layer.gd` is a canvas for light math living in a
coordinator that does not exist, `seams.gd` needs a `docs/BITS.md` not in this tree. Lifting any of them
lands dead code. Two had real consumers — `score.gd` (its entire interface with the game is one float) and
`particles.gd` (`sim/mining` already reports break and breach every tick) — and those are the two that came
over.

### A milestone pair is only a pair if every knob was held

`MILESTONES.md` says the point of fixing resolution, camera and seed is that only the CONTENT differs.
Two of those three were held. The bite radius and the tick were not: Slice 1's `delve` is bite 0 at tick
940, Slice 2's would have been bite 2 at tick 216, because D0200 moved the bite default and the scripted
run now finishes at 228 instead of 991 — which is also why the `delve` shutter silently wrote no file.
**The overrides for this existed; what was missing is that the DEFAULTS also form a pair.** The pair is
not claimed, and how to build it is written down instead.

---

## Gates

**All 36 suites pass locally**, including the four new ones (`test_corner_consent`, `test_interface`,
`test_score`, `test_particles`). Golden re-captured from CI's Linux build, run `33331589523`.

**Gate 7 (LOC velocity) is the one red, and this round made it much worse** — four new suites, a new
gate mutation test, and two new `view/` modules. Its own message stands: "the next unit of work is game,
not another check." D0207's finding still applies: gate 7 aborts the `structural gates` job, so ten
BLOCKING checks after it report `skipped` rather than pass or fail.

## Claims

`python3 tools/layer_lint/check_claim_references.py` reports VOID — zero scenarios exist to carry a
reference. **`claims/C004` still untouched on purpose**: whether a session qualifies is your judgment.

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md` is new and is where these live now**, with the numbers and a proposed remedy
for each. Six items: P001 (ratchet the fuzz `bounds` count at 922 rather than leaving it ungated), P002
(promote the recorded-session replay from scratch to a real CI test — makes every recording you make
binding), P003 (the size gate lints gitignored files locally and none in CI), P004 (point the fuzzer at a
generated shaft, since the chamber poses neither the corner mechanic nor its defect), **P005 (the
presentation batch — three options, and only option 3 changes how the game looks)**, P006 (the MODULE.md
60-line cap is violated by 10 of 10 modules, two of them this session's).

Carried, unchanged: **`grounded_no_floor`'s residual** (now 46, down from 59 — full support vs perching is
still a feel call, not a bug); **Slice 1.5's bite radius**, `--bite=0/1/2/3`, `docs/TASTE_QUEUE.md` T004;
**the body/world proportion**.

## Blocked, and what it's waiting on

- **D0193 / the bounds invariant's magnitude** — yours, gate 24's subject. The full sweep's `bounds` count
  is **1,179,015 of 1.5M ticks** and gated by nothing; P001 proposes the ratchet.
- **The fuzzer still never sets `mine_held`** — named four times now, still its own unit of work.
- **Line of sight** — still not ported; a player can mine through one tile of rock.
- **The `ValueNoise` cross-platform float gap** (D0171/D0172), **three GDD contradictions** (D0177), **the
  persistent-world GDD reversal** (text exists only in pre-compaction history), **`data/economy/` D1-D6**,
  **`history/`'s 168-image cull** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001 (`ore_copper` reads silver), T002 (band tint at 0.10), T003 (mining times,
partly re-framed by T004), T004 (the bite radius). **T004 no longer gates Slice 2 — Slice 2 shipped.**
