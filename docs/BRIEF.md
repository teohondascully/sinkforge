# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: built `tools/economy_check/`, the tier-rule checker, against
synthetic fixtures — no `data/economy/` content, which the director authors next.** Two-stage: a schema
proposal reviewed and approved with four corrections plus one addition, then the build. One further
design gap found and fixed during implementation, not dictated by the review — output-consequence clause
(b) needed the same "referenced elsewhere in the graph" discipline clause (a) got, confirmed necessary by
the most important of the six mutation fixtures. All 19 mutation cases observed firing correctly. No
`core/`/`sim/` code touched.

---

## EXPENSIVE, awaiting you

- **`data/economy/`** — the real demand/material/recipe/unlock rows, checked against
  `tools/economy_check/` once authored. Explicitly held for you.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged this round.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **Whether `tools/economy_check/` gets wired into CI** — not decided. No real data exists yet for a
  gate to check; deferred until `data/economy/` does.

## What was learned

- **Output-consequence clause (b) had the same vacuity clause (a) did, for a structurally different
  reason, and it only surfaced while building the mutation fixture meant to catch it.** If a demand's
  numeric capability grant is what causally satisfies the *next* demand's input-provenance requirement —
  the normal shape of a hardness-escalator chain — then by construction that same grant "opens access"
  to that same material, so clause (b) as originally specified would pass trivially at every step of the
  single most common real pattern. That's a restatement of input provenance wearing output-consequence's
  clothes, exactly the "policed inputs only" vacuity the three-part rule replaced. Fixed by requiring the
  newly-opened material to also be consumed by a recipe or the breach — mirroring clause (a)'s "referenced
  elsewhere" test exactly. Verified necessary by hand before writing the fix (traced the vacuous case),
  then confirmed by the fixture itself (`docs/DECISIONS_LEDGER.md` D0092).
- **The "chain of three decorative demands" fixture (the director's own emphasis: "if the checker stays
  silent on it the checker is wrong") is what found the clause (b) gap.** A fixture built to exercise a
  known failure mode surfaced a second, unrequested one nearby — the value of building the fixture the
  director called most important first, not last.
- **The checks compose usefully even where neither was specifically aimed.** Running the decorative-chain
  CLI case incidentally tripped check 3 (terminal products) on the fixture's own unused recipe output,
  unprompted — direct evidence for the "residual gap" reasoning in the checker's own docstring: a fake
  chain built to dodge one check tends to trip another.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0092.

`tools/economy_check/` — `schema.py` (97 lines), `check_tier_rule.py` (279 lines), `README.md`,
`test_check_tier_rule.py` (255 lines, 19 mutation cases, all OBSERVED). CLI verified directly against a
clean hand-built chain (exit 0) and the decorative-chain fixture (exit 1, correct FAILs). `tools/README.md`
gained one entry for the new subdirectory. Uncommitted at the time of writing; committing alongside this
report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` re-run and PASS after
the build (`check_untracked_files` correctly FAILed pre-commit on the new, then-untracked files —
expected, resolves on commit).

**LOC ratio: instrument grew +631 this window (`tools/economy_check/`), game +0 — absolute ratio 4.347.**
Still ADVISORY, game LOC (1,424) under the 2,000-line floor. Reported per instruction, not reacted to.

**Anvil: unchanged this round** — implementation 513 / test 420 / total 933, cap 1,000/2,000. No Anvil
work this session; `tools/economy_check/` is a separate instrument and does not count against this cap.

**`tools/economy_check/` own split: 376 implementation / 255 test / 631 total.**

**Commits this round: 1** (this build, landing with this report). **Unpushed: 1**, to be pushed with this
report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`** — waits for you, explicitly, this round more than ever: the checker is now built
  and mutation-tested, ready to validate the first real chain the moment it exists.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
