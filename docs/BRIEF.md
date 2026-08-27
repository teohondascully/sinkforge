# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-27. This round: ANVIL steps 1-2 (mini overnight session, per the director's
explicit queue in `docs/WORKING.md`).** Closed the `.git/info/exclude` hole (fifteen real doc paths
hidden from every fresh clone, one of them 3,447 lines), triaged and archived what it was hiding, added a
mutation-tested gate so it can't recur silently, then built ANVIL's own spine — event schema, append
tool, referential integrity checker, mutation-tested. Stopped after step 2d as instructed. Step 3
(economy authoring) is design work and waits for the director.

---

## EXPENSIVE, awaiting you

- **Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table, carrying no
  ARCHIVED/SUPERSEDED header** — found while executing this round's triage, explicitly NOT acted on
  (out of the confirmed scope): `A_PLUS_STATUS.md`, `BITS.md`, `BRANCHING.md`, `CAPTURE_MANIFEST.md`,
  `CONTENT_CATALOG_PLAN.md`, `ENGINEERING.md`, `HARNESS_LAYERS.md`, `LODE.md`, `SANDBOX.md`,
  `VISUAL_TRIAGE.md`. `docs/README.md`'s own rule: "if a document is not listed as normative below, it
  is not normative" — no third state is described, yet these sit in one. `docs/DECISIONS_LEDGER.md`
  D0062 has the full finding.
- **`incoming/ANVIL_ARCHITECTURE.md`'s eventual disposition** — currently `.gitignore`d as a staging
  area under review, not tracked or archived. Track once acted on, archive if not; not this session's
  call.
- Chunk size (D0019), coordinate type scheme (D0020) — unchanged, carried over.

## What was learned

- **A confirmed, already-approved bucket can still be wrong, and finding out is what "read before
  archiving" is for.** The director's own step 1b explicitly asked to read `CONVERGENCE_LEDGER.md` and
  the `FREIGHT_WINCH_*` handoff docs before archiving them, separately from the bucket-1/2 moves already
  confirmed. That read surfaced a real, dated, reasoned prior decision (2026-08-23) that directly
  contradicted this session's own already-confirmed proposal to track `legacy/tools/director_bus.sh`/
  `test_director_bus.sh`: a prior session deliberately kept them untracked specifically because this is a
  public portfolio repository and they are session-coordination tooling. Reversed before executing, not
  after — the two files moved to `.gitignore` instead. `docs/DECISIONS_LEDGER.md` D0062.
- **Design reasoning worth keeping surfaced in exactly the files flagged for having none read yet.**
  `FREIGHT_WINCH_ECONOMIC_ENVELOPE.md`, `FREIGHT_WINCH_GRAYBOX_PLAN.md`, `Q1_FREIGHT_WINCH_PAIN_OPTIONS.md`
  contain real, unduplicated engineering design — a route-scoped transit model that bypasses the normal
  per-tick flow step, a dangling-reference/cargo-preservation policy (fail closed at the route level,
  never destroy cargo), conservation-by-construction discipline throughout. `docs/GDD.md` §9 already names
  this exact mechanism as the closest analog to R1's shaft-to-surface haul. Not duplicated in any tracked
  document — pointed to, not copied, from `docs/archive/session-exhaust/README.md`.
  See below for the "vs. not-read-and-classified-by-proxy" contrast this makes plain, `docs/tracelog/`/
  `docs/handoff/`'s bulk was archived precisely because it was NOT individually read.
- **The same exclusion mechanism this round closed almost reopened itself inside the fix.** `.anvil/`
  fell under `.gitignore`'s own "every dotted directory is ignored by shape" rule the moment it was
  created — the new gate (`check_untracked_files.py`) caught `.anvil/README.md` before the commit that
  introduced it, not after. The gate paying for itself in the same round it landed.
- **A checker's mutation coverage written into the queue before any code exists survives contact with
  actually writing the code better than coverage chosen ad hoc.** The director's own queue named all
  eight `check_integrity.py` branches explicitly, in `docs/WORKING.md`, before `tools/anvil/` had a
  single file. `test_check_integrity.py` implements exactly that list — 16/16 cases (broken + fixed per
  branch), every one showing the failure actually fire, not just asserting from reading the code.

## What landed this round

Full detail and reasoning: `docs/DECISIONS_LEDGER.md` D0062-D0064. Three commits, pushed, CI confirmed
green on the final one (`bb8f6e7`, run `33057867315`).

1. **Triage buckets, as executed** (`74c397d`): 1 file into the tree (`legacy/tools/prose_words.txt`,
   completing the `legacy/` freeze); 2 files deliberately held OUT of that bucket after step 1b's read
   (`legacy/tools/director_bus.sh`/`test_director_bus.sh` — public-repo hygiene, moved to `.gitignore`
   instead); 14 files/paths into `docs/archive/` with dated headers (`PRIORITY.md`, two second-snapshot
   files whose twins diverge by 500-700 lines with authority left unreconciled rather than guessed, and
   ten more); `docs/tracelog/`+`docs/handoff/` (~3,055 files) archived whole per the director's explicit
   instruction, not deleted despite an initial recommendation to do so, because untracked deletion isn't
   reversible and archiving is.
2. **The exclusion hole itself, closed** (`14646fb`): `.git/info/exclude` reduced to the stock git
   template, nothing project-specific remaining. `tools/layer_lint/check_untracked_files.py` (QUALITY
   gate 27) fails on untracked-and-not-`.gitignore`-covered — mutation-tested, 3/3 branches: a real gap
   outside any pattern FAILs, a legitimately ignored file (`.DS_Store`) PASSes, a file hidden ONLY via
   `.git/info/exclude` still FAILs (the property that matters — proves the gate doesn't trust the file it
   exists to make irrelevant).
3. **ANVIL's own spine, steps 2a-2d** (`bb8f6e7`): `tools/anvil/schema.py` (seven event types, universal
   fields, `MEASUREMENT.source`/`FINDING.independent_of` non-defaulting, optional `narrative` on
   `DECISION`/`FINDING`), `append.py` (one file per event, `author` required not inferred, no
   `--force` escape hatch), `check_integrity.py` (dangling `supersedes`/`invalidates`/`assumes`, dangling
   `CONTENT_LINK.path` checked against the real tree, duplicate `id`), `test_check_integrity.py`
   (16/16 mutation cases, all eight required branches). 546 lines total.

## Gates

All 27 structural gates PASS (24 pre-existing + `check_untracked_files.py`, new this round, gate 27),
run and confirmed just now, not from memory. `check_size_limits` still WARNs (not fails) on
`sim/body/body.gd` at 309 lines — unchanged this round, no `sim/`/`core/` code touched.

**LOC ratio** (measured just now): instrument 5,097 (tools 2,210 + tests 2,887) / game 1,424. **Absolute
ratio 3.579** — up from 3.164 before this round. Stated plainly, matching the director's own framing from
this round's earlier discussion: `tools/anvil/`'s 546 lines are instrument LOC with no corresponding game
LOC yet, by design (steps 1-2 are process infrastructure; step 3 is where game-shaped `data/economy/`
content starts). Worth watching, not smoothed over — this is the exact dynamic ANVIL exists to arrest,
recurring in miniature inside ANVIL's own construction.

**Anvil line count: 546 / 800 cap for steps 1-2 (68%), 546 / 2,000 total budget (27%).** Comfortable
headroom on both this round; steps 3+ (economy instrument, projections, propagation, the loop) are where
the budget gets genuinely tight, per this session's earlier estimate.

**Commits used: 3 of the 12-commit budget.** Zero HARD STOPS triggered — no gate went red at all this
round (each ran clean on first attempt), so "not clearable in one attempt" never applied; no run of three
commits without a test going red-to-green (every code commit carried its own mutation evidence).

**Unpushed commits: 0** — all three pushed, CI green confirmed on `bb8f6e7` before this brief was written,
not assumed from the local pass.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- **Step 3 (economy authoring) and beyond** — explicitly stopped here per the director's own queue;
  design work, waits for a session the director is present for.
- Gate 10 (`reachable_state_can_reach_surface`) — filed as deferred per the director's ANVIL review;
  design reasoning preserved in `docs/WORKING.md`'s "Discoveries" section pending migration into ANVIL
  proper once claims exist to hold it.
- Item 2, the human-biased fuzzer — still blocked, `tests/body/recordings/` still empty.
- Rope (stage 4, step e) — deliberately not started.
- Chunk size (D0019), coordinate type scheme (D0020) — unchanged.

## Taste queue

0 fixtures. Unchanged.
