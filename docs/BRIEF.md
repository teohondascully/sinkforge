# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: LEGACY REVIVAL Slice 1.5 — the bite. 4 commits dated 2026-08-29
(`7199940`, `627e24b`, `ea33549`, `1ac7939`), plus this wrap. `docs/DECISIONS_LEDGER.md` D0199-D0204.**

**Headline: the Slice 1.5 brief's premise was false in both halves, and the real defect is the opposite
of the one it describes. Mining was already at the 4px resolution and collision already runs on it; what
was wrong is that one blow removed 1/16th of a metre while being charged a full metre's worth of legacy
hardness-seconds. Slice 1 mined 16x slower than legacy per unit volume, and nothing measured it because
the check was in seconds-per-CELL and the two codebases' cells are different sizes.**

---

## What was learned

Findings from this round, written while they're fresh — not the ledger's judgment-call record (that's
`docs/DECISIONS_LEDGER.md`), and not a work log.

### A feel report is data; the mechanism attributed to it is a hypothesis

The brief reads "one mine removes a whole logic cell, i.e. a chunk nearly the size of the body." Replaying
the session that produced that sentence (`tools/measure_play_session.gd`): 29.6 s, MINE held 876 ticks,
**504 of them aimed at AIR**, 29 cells broken, first break **11.4 s in**, **0.50 m** descended, **0.7 of
one body-volume** removed. The bite was 2.5% of the body's area — it takes **40 of them** to make a
body-sized hole. Half a minute of holding dug a hole smaller than the digger.

The perception ("the body is massive, mining feels weird") was exactly right. The mechanism was inverted:
the body is massive **relative to what a blow removes**. Building the requested probe would have made bites
16x *smaller* — except it couldn't, because they were already at that resolution, so it would have been a
no-op the director played, felt nothing from, and read as "granularity doesn't help — shrink the body."
**A measurement whose subject is absent doesn't return "no effect"; it returns a wrong reason** (D0200).

### The general rule was written down, one paragraph away, and still wasn't applied

D0195 established the right rule about REACH: legacy's `REACH_CELLS = 3.2` is 102.4px there and 51.2px
here, **because both codebases' cells are one metre, so the portable quantity is metres, not pixels**. The
same entry then validated the HARDNESS port in seconds-per-cell — 0.283s vs legacy earth's 0.28s — and
called it faithful. Legacy's cell is a square metre and one charge removes it; here a metre is 16 terrain
cells and one charge removed one. **0.06x legacy per unit volume.** Having the rule stated, correctly, in
the same file, about the adjacent constant, was not enough. The screen is: seconds *per what*, cells *of
what size* (`docs/CORRECTIONS.md`, D0200).

### The probe found a collision defect, and the tick it fails on excavates nothing

Replaying the director's session at radius 1 ejects the body from the world. The obvious read — "the bigger
bite broke something" — is wrong, and `cleared=0` on the failing tick says so: the grid is byte-identical
either side of it. It reproduces on a clean checkout without D0139's parked change, and then from a
**hand-authored 15-row map with no `Mining` in the script at all**. **Escalated, not fixed** (D0202);
`tests/fixture_step_up_into_wall_probe.gd` is a one-command reproduction.

**I then named the wrong mechanism, and the correction is the more useful finding** (D0203). I wrote that
"the step-up's HEIGHT is checked, the destination's FIT is not." `_try_step` checks its destination —
`_box_blocked` on the body's box translated up by the lift, half-open bounds correct. I inferred a missing
guard from legacy HAVING one plus our outcome being wrong, across two files, one of which I had not read.
The real tell was already in the trace: the tick ends with `floor_source = "try_step"` and
`on_floor = false`, which `_try_step` cannot produce — **the step succeeds and is undone later in the same
tick by the vertical pass.** That contradictory pair is a cheap general invariant nobody asserts yet.

The lesson beyond the bug: Slice 1 named the fuzzer's blind spot (it never sets `mine_held`) and moved on.
A bite radius is a shape generator, and it found a real resolver defect inside 987 ticks of one recorded
session. Wiring the fuzzer to the mining verb is now a much better bet than it looked.

### A build handed over for a feel judgment must be a clean checkout

The director's second session (710 ticks, bite=2) replays to **8 bad ticks in 4 episodes (1%)** on a clean
checkout and **268 in 12 episodes (38%)** in the working tree, because that tree carries D0139's parked
`vertical_resolve.gd`. **33x.** I told them that difference was "immaterial for a feel judgment" — a guess
generalised from D0198's 7% tick-count difference on a scripted `--mine-down` run, which never presses
LEFT or RIGHT against a wall and therefore could not contain the effect I was ruling out. A third of the
session they judged was spent inside rock, for a reason that is not in `main` (D0204).

### Every suite written in the last two slices ran nowhere

`test_material_palette`, `test_mining`, `test_reveal_scene_dig_edge`, `test_reveal_spawn_bounds` — all
written, all passing, all committed, in no CI job. Two of them are the bounds controls that were
deliberately mutation-tested so they could be trusted. Neither side looked wrong alone: a long
correct-looking workflow, a long correct-looking directory. After the fix the first run printed **"26
suites on disk, 26 referenced by CI"** while the sets still differed — the ledger's own "equal counts,
different sets", live. Gate 31 reports members, never a total (D0201).

### A derived rule and its repair are different sizes

D0192 derived "one solid cell between the body's edge and the boundary" and applied it to the left edge.
The entry shaft still opened row 0, so the body spawned with its head ON y=0 and **the first jump of any
session left the world** — one bounds violation in the director's own log. What found it was not a re-read
of that work but a new measurement of a new session (D0199).

## Gates

Run `python3 tools/gate_status.py`. **Two red, both D0139's parked uncommitted work, verified unchanged:**
`check_size_limits` (`resolve_floor` at 60 lines) and `check_untracked_files` (`test_vertical_resolve.gd`).
Every suite passes on a clean clone carrying this round's changes and not D0139's — isolated and checked,
not assumed. Gate 7 (LOC velocity) still red on its trailing window.

## Claims

`python3 tools/layer_lint/check_claim_references.py`. **`claims/C004` is still untouched on purpose** — a
real human session now exists in the tree, but deciding whether one qualifies is your judgment.

## The decision this round is waiting on

**Play it and sweep `--bite=0/1/2/3`** (`godot --path . tests/body/reveal_scene.tscn -- --play --bite=N`).
Radius 0 is bit-for-bit the build you played and called weird, so it is the control and should feel worse.
`docs/TASTE_QUEUE.md` T004 carries the measured table: the same 24-cell shaft takes 991 / 505 / 242 / 152
ticks at radius 0 / 1 / 2 / 3.

**And a third option the geometry raises, which no mining change reaches.** The world is 48 cells — 12 m —
wide. The body is **8.3% of the world's entire width** and **33% of the screen's height** at zoom 6. You
cannot zoom out to fix that: at zoom 6 the view is already 213px against a 192px world, so zooming out adds
background, not world. **Shrinking the body and widening the world are the same fix seen from two ends**,
and the brief's Option 1 is only one of them.

## Blocked, and what it's waiting on

- **D0202 / D0203, the step-up undone inside its own tick** — new, yours, and a hard stop for anyone not
  on the collision arc. It is NOT rare: the second `--play` session hits it 4 times in 710 ticks on a
  clean tree, at the shipped bite radius.
- **D0193 / the bounds invariant's magnitude** — unchanged, yours, gate 24's subject. It has now fired
  twice more (0.3125px, 3.4px) against the 15.85px it was built for.
- **D0139 / `resolve_floor`** — unchanged, untouched, still dirty on purpose.
- **Line of sight** — still not ported, so a player can mine through one tile of rock.
- **The fuzzer and `mine_held`** — named twice now, still its own unit of work.
- **The `ValueNoise` cross-platform float gap** (D0171/D0172), **three GDD contradictions** (D0177), **the
  persistent-world GDD reversal** (text exists only in pre-compaction history), **`data/economy/` D1-D6**,
  **`history/`'s 168-image cull**, **the parked Anvil CONSTRAINED finding** — all unchanged, all yours.

## Taste queue

**4 open.** T001 (`ore_copper` reads silver) and T002 (band tint at 0.10) carry over from Slice 0,
unanswered. T003 (mining times) is now partly re-framed by T004 — that table is seconds **per cell**, and
one blow no longer removes one cell. **T004 is the bite radius**, and it is the one that gates Slice 2.
