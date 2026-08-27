# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-27. This round: an independent external audit found run-structure specifications
neither of the prior two sweeps caught, and eight commits fixed them.** The reversal itself (last round)
touched six document groups; this round's audit read the corpus cold, with no model of which files
"should" need checking, and found real gaps in `CLAUDE.md` (the auto-loaded reading order still pointed
at retired `C001`), the claims methodology documents, eight `sim/*/MODULE.md` files, several
`harness/`/`shell/`/`data/` READMEs, and a wording collision inside `docs/GDD.md` itself. Every audit
claim was independently verified before acting — two were downgraded, one pre-existing governance gap
was fixed anyway per explicit instruction. No code touched. Stopped before `data/economy/`, as
instructed.

---

## EXPENSIVE, awaiting you

- **`data/economy/`** — the demand authoring, including the corrected reachability rule and the
  "decorative demand" critique this round's audit raised against it. Both explicitly held for you.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged this round. Your own framing: "the
  split collapses entirely into one world state, or it survives as a checkpoint-granularity question... 
  downstream of work that does not exist." Not resolved, not supposed to be yet.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.

## What was learned

- **A sweep bounded by the sweeper's own model of the corpus misses whatever the model never included as
  a candidate — and this is now measured twice, not asserted once.** D0026 (`no_engine_imports.py`
  checked a hand-picked class list; Godot's real registry had 276 more) was the first instance. This
  round's own two prior sweeps (the original reversal queue, then a `docs/GDD.md`-specific follow-up)
  both missed files outside their own list — `CLAUDE.md`, the claims methodology documents, eight
  `MODULE.md` files. An external audit reading cold, with no such list, found all of them in one pass.
  Recorded as a general rule (D0091): prefer a corpus-wide mechanical search over an enumerated file
  list; where that's not practical, an independent cold read is the next-best substitute.
- **Verifying an audit's claims independently is not optional even when the audit is mostly right.** Two
  of its "FALSE" ratings were overclaims — `CONTEXT.md`/`README.md`'s "a run must complete with no
  renderer" is the harness-execution sense, not a contradiction with "no session boundary." Caught by
  reading the actual sentence in context, not by trusting the audit's severity label.
- **A wording collision can be a real finding worth fixing even when it isn't a strict logical
  contradiction.** `docs/GDD.md` §9's dead-list entry ("Persistent-world progression... is dead") and §1's
  premise ("a persistent underground shaft") don't actually contradict once every referent is traced —
  but a cold reader has no reason to trace that carefully, and a document meant to be read cold is
  measured by what a cold reader takes from it, not by what a careful re-reading would eventually
  resolve. Fixed by naming mechanisms instead of properties (terminal products, a one-time descent gate, a
  research-tree menu) rather than by re-arguing that the two statements are technically compatible.
- **The "run" standardization removed an entire category of future disambiguation, not just fixed
  current instances.** Reserving "run" strictly for evaluation/harness executions meant most of
  `harness/*` needed nothing — three of four README files were already using it correctly, and that's now
  checkable by rule rather than by re-reading each sentence in context every time.
- **A citation error can hide inside a file that was otherwise carefully written.** `C003`'s own D1
  citation conflated the director's chat brief with `docs/GDD.md` §2 — a different document, entirely
  different content — introduced while writing the file last round, caught by the same external audit.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0084-D0091. Eight commits, grouped by surface per the director's
explicit ordering.

1. **`CLAUDE.md`** (`54dbe60`, D0084) — the auto-loaded reading order, fixed alone and first since it
   misleads every session before anything else can correct it.
2. **`docs/README.md`'s normative table** (`caaa19f`, D0085) — added the three documents `CLAUDE.md`
   already called normative. Pre-existing governance gap, not reversal damage, fixed anyway per explicit
   instruction.
3. **`docs/CLAIMS.md` + `docs/ARCHITECTURE.md` §5/§6** (`aa3ca85`, D0086) — the methodology and
   scenario-format documents; `C001`/Draft A as live worked examples genericized, not just updated to
   `C003`, so they don't go stale again when that claim resolves.
4. **`sim/*/MODULE.md`, the eight with real content** (`eaade2a`, D0087) — `terrain_gen`, `fluid`,
   `invariants`, `machines`, `transport` on top of `run`/`meta`/`commands` from last round. Three others
   (`items`, `economy`, `world`) checked and confirmed needing nothing.
5. **`harness/*`/`shell/`/`data/progression/` wording standardization** (`ee68508`, D0088) — three of
   four `harness/` files already correct under the new rule; `harness/bots/README.md` had zero hits,
   reported as a null result.
6. **`docs/GDD.md`:7 + the persistent-world disambiguation** (`94fcd2e`, D0089) — `docs/GDD.md` §9 and
   `docs/DECISIONS.md` both rewritten to name mechanisms, not properties.
7. **`C003`'s citation fix** (`1f07a0d`, D0090).
8. **The bounded-sweep meta-finding** (`84a21de`, D0091) — recorded as its own entry since it names a
   pattern across two unrelated incidents, not a fix to this round's own work.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` PASS, run and
confirmed just now. Test suites not re-run this round — no `.gd` file touched (confirmed, not assumed).

**LOC ratio: unchanged, 3.904** (instrument 5,559 / game 1,424) — no `core`/`sim`/`tests` code touched.
Still ADVISORY, game LOC under the 2,000-line floor.

**Anvil: unchanged this round** — implementation 513 / test 420 / total 933, cap 1,000/2,000. No Anvil
work this session.

**Commits this round: 8.** **Unpushed: 8**, to be pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged this round. `C003-cold-start-reaches-d1.md`: `BLOCKED`,
one citation fixed. `C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`** — waits for you, explicitly. The corrected reachability rule and the "decorative
  demand" critique both arrive with that session.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, still not something to resolve unprompted.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- **Cohesion note for Anvil step 4** (unchanged, unrelated to this round): projections should mirror
  `sim/invariants`/`replay_determinism_test` when built. Not started.

## Taste queue

0 fixtures. Unchanged.
