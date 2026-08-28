# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the `--json` output mode built (pulled forward from "later" to
"now"), plus a director-requested clean baseline snapshot, measured, before `data/economy/` content
starts landing.** `tools/economy_check/` is closed as an instrument: schema approved, three-part rule
built, reference integrity added, the two-hop residual named in output and logged as an Anvil FINDING,
and now a machine-readable mode so the first real check run can become a `MEASUREMENT` event directly.
`test_check_tier_rule.py`: 44/44 OBSERVED. No `data/economy/` content, no `core/`/`sim/` code touched.
Holding — the next substantial thing is D1-D6, authored by the director, checker already green on it.

---

## The baseline (`docs/DECISIONS_LEDGER.md` D0095) — this is the floor `data/economy/` moves from

- **`tools/economy_check/`**: 566 implementation (`schema.py` 128 + `check_tier_rule.py` 438) / 500 test
  (`test_check_tier_rule.py`) / **1,066 total.**
- **Instrument/game ratio**: instrument (harness+experiment+tools+tests) **6,625** / game
  (core+sim+interface+view+shell) **1,424** — **absolute ratio 4.652.** Trailing-10-commit window:
  instrument +1,066, game +0. Still ADVISORY (game LOC under the 2,000-line floor).
- **Anvil**: implementation **513 / 1,000 cap (51.3% used, 487 lines of headroom)**. Test 420. Total
  933 / 2,000 total cap.
- **`.anvil/log/`**: **5 events** — 2 external-audit FINDINGs, 1 DECISION, 2 artifact-instrument
  FINDINGs (one from D0075, one this session's two-hop-gap finding, D0093). Verified by reading each
  event's own `type` field, not inferred; `check_integrity.py`: `PASS -- 5 event(s), referentially
  sound.`
- **Game LOC (`core`+`sim`) is unchanged at 1,424 all session** — nothing game-shaped has landed since
  the persistent-shaft reversal. This is the number that should start moving once `data/economy/` does.

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — the real demand/material/recipe/unlock rows, authored with you
  present, checked against `tools/economy_check/` as they land. This instrument does not author content.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged this round.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **Whether `tools/economy_check/` gets wired into CI, and whether/when `--json` output actually becomes
  a `MEASUREMENT` event** — both deferred until real data exists to check and measure.
- **The two-hop decorative gap itself** — logged, not fixed, on purpose. When D1-D6 land, this is the
  finding to check the chain against by hand (`.anvil/log/2026-08-28T165338.936688Z-a677726d.json`).

## What was learned

- **"Build the bridge before the water" applies recursively, not just once.** The checker was built
  before the economy so the economy never launders an untested rule. This round applied the same
  ordering one level up: the machine-readable bridge between checker and log gets built before the data
  that would first cross it, not after — pulled forward from a "later" flag the moment the director
  noticed the ordering argument also applied to itself.
- **A structured field beats a citation embedded in prose, even for a note whose whole point is
  disclosure.** `RESIDUAL_NOTE` already stated the two-hop gap in prose; `to_json_report`'s `residual`
  object turns "cites D0093" into an actual `decision_ledger: "D0093"` field and `anvil_finding_id` into
  a real, quoted UUID — the difference between a human reading a sentence and a script being able to
  join against it without parsing English.
- **Self-caught fixture bugs are now a recognizable, repeating pattern, not a one-off.** Two more this
  round (a recipe output referenced but not registered in two separate fixtures) — same shape as D0093's
  first instance. Reference integrity is functioning as a general-purpose fixture-correctness check, not
  just a chain-correctness check, which was not the original reason it was built.
- **A "clean baseline" is itself a claim that needs verification, not a formality.** Every number in this
  round's snapshot was re-measured at writing time — the `.anvil/log/` event breakdown specifically had a
  wrong ledger citation caught and fixed before landing (attributed one FINDING to the wrong round),
  which is exactly the kind of small transcription error a "just report the numbers" task invites if the
  numbers aren't actually re-derived from source.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0094 (the `--json` mode), D0095 (the baseline).

`tools/economy_check/check_tier_rule.py` gained `to_json_report` and a `--json` CLI flag; `RESIDUAL_
ANVIL_FINDING_ID` added as a static citation constant. `test_check_tier_rule.py` gained fixture 9 (JSON
structure) and a CLI end-to-end test, 10 new cases, all OBSERVED. No new Anvil events this round — the
baseline snapshot only reads `.anvil/log/`, doesn't write to it. Committed and pushed alongside this
report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` re-run and PASS.

**`tools/economy_check/` split: 566 implementation / 500 test / 1,066 total** (up from 484/375/859 —
this round added 82 implementation / 125 test lines).

**LOC ratio, Anvil, `.anvil/log/` count**: see the baseline section above — these are the same numbers,
not repeated twice for effect.

**Commits this round: 1** (D0094 + D0095 together, one build + one measurement, same commit). **Unpushed:
0**, pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present. The checker is built,
  mutation-tested, machine-readable, and its own known gap is on record. This is the floor; the ratio
  moves next.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
