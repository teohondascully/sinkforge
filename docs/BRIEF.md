# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03. This round: the A′ hand-off — the execution plan, the README, and the
stale-doc cleanup. Docs only. No code, no instrument, no dead code touched; nothing in the plan
executed.** Ledger: D0342 (D0341 is yesterday's recommendation).

**Headline: `docs/A_PRIME_REFACTOR_PLAN.md` exists and is self-contained.** A fresh session should
need only it, the flip analysis, and the tree. Its centrepiece is the classification the fog was
missing: of 491 code files, 281 are LIVE (the whole current build), and legacy's 210 split into **48
LIFT, 112 REFERENCE, 50 DEAD**, every one named with its destination or its reason. Then eight ordered
steps, each with files, acceptance signal, what re-pins, and whether it needs you.

---

## What landed

- **`docs/A_PRIME_REFACTOR_PLAN.md`** (§0 compaction contract; §1 the decision and why; §2 goal state
  and acceptance; §3 the file map incl. the 44 `.tres` records, the 144 legacy tools bucketed by the step
  whose subject they test, and the non-code corpus; §4 steps 0–8; §5 the 24 + 8 determinism rows with
  the fix per row and the save v3 keys; §6 code vs pattern; §7 the 120 Hz rules and two hypotheses; §8
  the eleven rulings only you can make; §9 traps; §10 done).
- **`README.md` rewritten.** What the old one had: a "Stage 4 of 7" status paragraph two pivots stale; a
  "Two pivots, and why they're a strength" section of dev-narrative; a ten-gate table that undercounts
  35; "there is no `view/`" when `view/` is 5,706 lines; adjectives where numbers belong. What the new
  one does: two concrete sentences up front; a measured table of what exists at `6f0d894e`; a plain
  paragraph of what does not; proof links (gate 8, the fuzzers, the recorded corpus, CI green); the
  legacy/plan pointer; size; license. No em dashes, no pivot story, no listicle.
- **Stale docs.** Archived with dated headers: `MASTER_PLAN_AUG30.md` (superseded twice; its cardinal
  rule survives in the plan), `WG4_CONVERSION_PLAN.md` (executed in full). Re-headed **reference** and
  given a `docs/README.md` section of their own: `LEGACY_GAP.md`, `PORT_ORDER.md`, `PERF_PLAN.md`,
  `COORDINATOR_CONTRACT.md` — measurements stand, sequence or status line does not. Amended in place:
  `LEGACY_MIGRATION_MAP` (KEEP-CURRENT on `factory_sim.gd` reversed), `ONBOARDING.md` (stage sequence
  superseded), `CONTEXT.md` (one closing paragraph), `docs/README.md` (plan row, reference section,
  archive notes). **`WORKING.md` reset** from 515 lines to the current stage per its own rule.
- Kept as is, deliberately: the flip analysis, the migration map, the ledger, GDD, ARCHITECTURE,
  QUALITY, CLAIMS, CORRECTIONS, `NEEDS_DIRECTOR.md` (not audited row by row), `CONTRIBUTING.md` (already
  declares itself stale).

---

## What was learned

1. **The classification is generatable, not authored.** Every legacy row in the plan came from the 17
   workers' per-file `FLIP_VERDICT` lines, re-bucketed for A′ by a script, and the buckets reconcile
   (src 8/8/2, scenes 20/15/8, tests 5/0/0, tools 15/89/40 = 48/112/50 = 210). A hand-typed version
   would have drifted the way `LEGACY_GAP.md`'s counts did.
2. **The director's question about 16 px was a units question.** Both builds' logic cell is one metre;
   the lag axis is cells per metre the per-frame code touches (880 vs 14,080 for the same view, D0340),
   not pixels per metre. The plan makes "machines, items, water and power live on the metre cell" a rule
   and names the two likely live causes of lag as hypotheses to measure, not facts.
3. **A third doc status was needed.** `docs/README.md` allowed normative or archived. Four plans carry
   measurements that stand and a sequence that does not; archiving them loses the measurements, keeping
   them normative misleads. "Reference" is that status, recorded as a judgment call (D0342).
4. **My own Write was refused once** because my amendment script had touched `WORKING.md` first in the
   same turn. Harmless here, but the same shape as every "two writers, one file" collision the fleet
   memory warns about; sequence writes to a file through one path.

---

## The decisions this round is waiting on

**Step 1 of the plan, EXPENSIVE, gates step 4:** where machines, items, water and power live —
`TileGrid` planes at the 16 px logic cell (proposed), or a separate `LogicGrid`. Needs an ADR.

**Plan §8's other rulings:** Splitter, Ore Vent, power gating (16 of legacy's 54 live tests); the
Crusher/packing/seep chain; `press_plate`/`mill_gear`; `earth` hardness 5.6 → 6 ticks; authored ramps
vs `Heightfield`; the resolver (P-28) before the grapple's collision half; the 36 untracked recordings
(gate 27 red); the `history/` cull.

**Standing:** P004, P015/P017, P026–P029, T001–T004.

---

## Anything that felt wrong even though it passed

**The plan's line estimates are the workers' estimates, not measurements.** Where a number is an
estimate the plan says "est." The counts (rows, files, dead lines) are measured; the effort is not.

**Two performance claims are hypotheses and are labelled so.** The 262,144-cell one-shot bake after
D0335 and the unmeasured widest zoom rung are the likely causes of the lag you feel, and nothing was
run to confirm either. The plan says measure first.

**`NEEDS_DIRECTOR.md` is 1,104 lines and I did not audit it.** Its own header already admits three
items said "open" after their rulings shipped. It is the one document in the normative table that may
still mislead by staleness.

---

## Blocked, and what it's waiting on

**A′ step 0 can start now** (no ruling needed). Step 4 waits on step 1's ruling. `main` is two
commits ahead of `origin/main` and not pushed.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
