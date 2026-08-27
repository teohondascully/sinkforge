# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-27. This round: the run-based roguelite structure is retired.** The director
brought a full design-reversal brief, a five-point review found four real errors in the director's own
edit list before any editing started (one of them — a load-bearing identity claim about to be deleted by
association — the director called potentially real damage), and six commits landed the reversal across
`docs/GDD.md`, `claims/`, `CONTEXT.md`/`README.md`, `ONBOARDING.md`, `docs/ARCHITECTURE.md`/`QUALITY.md`,
and the `sim/run`/`sim/meta`/`sim/commands` scaffolding. No code touched anywhere in this round — verified
directly, not assumed. Stopped before `data/economy/`, as instructed.

---

## EXPENSIVE, awaiting you

- **`data/economy/`** — the demand authoring itself (D1/D2/D3, the reachability rule). Waits for you, as
  instructed.
- **`sim/run`/`sim/meta`'s actual shape.** Deliberately left open rather than decided this round — see
  "What was learned" below. This is now a real architecture call, not just unbuilt scaffolding.
- **Whether lateral variety survives losing re-rolled geology** (new `docs/GDD.md` §8 question, your own
  instruction to state honestly rather than assume away).
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged, still
  deliberately unresolved.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged, still undetermined.

## What was learned

- **A review response caught four real errors before any editing started, and you found a fifth.** The
  D2 anti-vacuity rule was worded by layer when it needed to be worded by reachability (as written it
  would have fired three or four times total and been silent on demands 4-20, exactly where the legacy
  failure lived) — you supplied the corrected wording directly. "The terrain is the factory" was about to
  be deleted by association when §2's roguelite section retired, even though it's the project's most
  quoted identity claim and doesn't depend on runs at all — moved to §1 instead. A direct self-contradiction
  in the edit list (§5's idle-loop subsection marked both "keep verbatim" and "edit this exact phrase
  inside it") got caught before it could be resolved by accident. Machine retrieval was slated for
  retirement with run termination, but the underlying tension (pull a machine before its section floods)
  resurfaces under local, non-terminal flooding — reworded, not deleted.
- **A retired claim is a different fact from an edited one, and the corpus format already had a word for
  it.** `C001` measured a bounded run that no longer exists — title, falsifiable form, metric, and
  threshold all constructs of the retired structure. Marked `RETIRED` per `docs/CLAIMS.md` §4's own
  convention rather than rewritten in place, on your explicit reasoning: editing it would erase that a
  design change happened. `C003` replaces it, shaped as an episode claim (checkpoint/seed/policy/horizon)
  rather than a bounded run — threshold deliberately left unset, since there's nothing to derive one from
  until `data/economy/` exists, and a guessed number would be exactly the "guess wearing a decimal point"
  `docs/CLAIMS.md` §9 warns against.
- **The engineering layers really were unaffected, and this round is the first time that claim was
  checked rather than taken on faith.** All five ADRs, `core/`, `sim/world`, `sim/terrain_gen`, `sim/body`
  — confirmed clean via direct trace (ADR-0002's shaft-to-surface boundary maps identically onto one
  persistent shaft) and via `git diff --stat -- '*.gd'` across the full six-commit range, which returned
  nothing. The reversal's entire cost landed in prose.
- **"Everything that survives between runs" stopped meaning anything once nothing is disposable.**
  `sim/meta`'s whole definition was relative to a `sim/run` whose state got discarded. With nothing
  discarded, the definition has no referent — this is a deeper open question than the already-known
  rig-form one, and it's now stated as such rather than left as stale scaffolding that happens to compile
  because nothing reads it yet.
- **Two spots were left deliberately stale, on purpose, inside explicit "keep verbatim" instructions** —
  §2's "a forty-minute run cannot" and R2's "every run that fails to reach depth into a zero." Flagged in
  the ledger rather than silently fixed, matching the discipline the director's own corrections enforced
  twice this round (the §5 phrase-scope correction, and my own overreach on "run cadence" caught and
  reverted before it was committed).

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0076-D0081. Six commits, each its own document group so the
diff stays reviewable, per your explicit instruction.

1. **`docs/GDD.md`** (`ebf17e1`, D0076) — the full section-by-section rewrite: §1 gains the
   run-independent "terrain is the factory" claim; §2 drops to two genres; §3 states the one-word
   correction; R3 becomes continuous upkeep; §5/§7/§11 lose run-plural language via full rewrites where a
   one-line patch wasn't enough; §8 gains the honest lateral-variety question and the reworded machine-
   retrieval question; §9 records the retirement with your exact dictated text; §10's worked sketch moves
   to hour 1/5/12.
2. **`claims/`** (`23118e8`, D0077) — `C001` RETIRED, `C003-cold-start-reaches-d1.md` filed BLOCKED with
   a real `blocked_on` list, both `CONTEXT.md`/`ONBOARDING.md` "definition of done" citations updated in
   the same commit.
3. **`CONTEXT.md` + `README.md`** (`f415b5e`, D0078) — orientation-docs propagation, compressed to each
   file's own terse register.
4. **`ONBOARDING.md`** (`fc03219`, D0079) — build-roadmap propagation; stage 6 restated as an open
   question rather than a build target; Task 0's two historical `C001` mentions left untouched on purpose.
5. **`docs/ARCHITECTURE.md` + `docs/QUALITY.md`** (`31b1f84`, D0080) — §11 kept in full, retitled
   "pre-reversal design, not current spec" rather than deleted; six smaller stale references fixed
   individually, not pattern-matched.
6. **`sim/run`/`sim/meta`/`sim/commands` `MODULE.md`** (`87f127b`, D0081) — the run/meta split marked
   open, no replacement architecture invented unprompted.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` PASS, run and
confirmed just now. Test suites not re-run this round — no `.gd` file touched (confirmed, not assumed).

**LOC ratio: unchanged, 3.904** (instrument 5,559 / game 1,424) — no `core`/`sim`/`tests` code touched.
Still ADVISORY, game LOC under the 2,000-line floor.

**Anvil: unchanged this round** — implementation 513 / test 420 / total 933, cap 1,000/2,000. No Anvil
work this session.

**Commits this round: 6.** **Unpushed: 6**, to be pushed with this report.

## Claims

`C001-two-minute-run.md`: `BLOCKED` → `RETIRED`. `C003-cold-start-reaches-d1.md`: new, `BLOCKED`.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`** — waits for you, explicitly.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, not something to resolve unprompted.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- **Cohesion note for Anvil step 4** (unchanged, unrelated to this round): projections should mirror
  `sim/invariants`/`replay_determinism_test` when built. Not started.

## Taste queue

0 fixtures. Unchanged.
