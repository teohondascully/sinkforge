# tools/quality_check

## Purpose

Four code-quality instruments the repo had no coverage for at all before this round
(`docs/DECISIONS_LEDGER.md` D0096): function-length distribution, cross-language duplication, cyclomatic
complexity, and module fan-in/fan-out. Correctness gates (`tools/layer_lint`) already existed; nothing
measured modularity or duplication. The director's own framing for why: "the previous project carried
six near-identical copies of one function across fifty layers and nothing flagged it, because nothing
was looking."

**Dashboard, not a gate.** Every instrument here reports a distribution and flags statistical outliers
relative to that distribution (`scan.iqr_outlier_fence`, the standard boxplot rule). None exits nonzero
on a finding; none is wired into CI. Thresholds get proposed from what this prints, not decided ahead of
seeing it — a threshold set without the data first is "a guess wearing a decision's clothes."

    python3 tools/quality_check/dashboard.py

## The four instruments

1. **`function_length.py`** — distribution of function lengths, both languages. Complements (does not
   replace) `tools/layer_lint/check_size_limits.py`'s existing hard 50-line function cap, which was
   itself picked before this dashboard existed to show what the real distribution looks like.
2. **`duplication.py`** — **the headline instrument.** Token-level, identifier-normalized, exact-match,
   per function. Catches renamed copies (the actual legacy failure), not just literal text matches.
   Deliberately does NOT normalize literals (numbers/strings) — see its own docstring for why that
   specific choice matters for precision.
3. **`complexity.py`** — McCabe cyclomatic complexity per function. Python: exact, via `ast`. GDScript:
   approximate, via token counting (no real GDScript parser is available in pure Python) — stated as a
   real precision gap in the module docstring, not glossed over.
4. **`coupling.py`** — fan-in/fan-out per submodule, for `sim/` and `tools/` specifically (per the
   director's scope). Closes a real blind spot rather than just inheriting `layer_lint.py`'s documented
   one: `sim/`'s dominant coupling mechanism turned out to be GDScript's global `class_name` visibility,
   not `preload`/`load` (a real check against this tree found zero `res://`-based `sim/` references but
   13 `class_name` declarations) — see the module docstring for exactly what is and isn't closed.

## Shared infrastructure (`scan.py`)

File discovery, function-span extraction (GDScript spans reuse `check_size_limits.py`'s own scanner
directly, not reimplemented), two tokenizers (Python via stdlib `tokenize`, exact; GDScript hand-rolled,
approximate — both documented), the shared distribution/outlier-fence math every instrument that flags
outliers uses, and `run_cli` — the one-line dispatch (`result = analyze(); print(format_report(result));
return 0`) every instrument's own `main()` now delegates to, extracted after `duplication.py`'s first
real run found that exact shape clustered as a duplicate across all four `main()` functions
(`docs/DECISIONS_LEDGER.md` D0097). Factored out once four consumers needed the same thing — a
duplication detector whose own source duplicated this logic across four files would be the tool
disproving its reason to exist.

## Testability

`function_length.analyze`, `complexity`'s functions, and `duplication.analyze` all accept an injectable
list of synthetic `scan.Func` objects. `coupling.analyze` accepts an injectable `root` directory,
mirroring `tools/anvil/check_integrity.py`'s own `check_integrity(log_dir)` parameter — this project's
established fix for "a checker that can only be pointed at the real, live tree cannot be mutation-tested
without risking it."

## Mutation testing

`test_quality_check.py`, run directly (`python3 tools/quality_check/test_quality_check.py`) — 21 cases,
covering an outlier being flagged and a uniform distribution flagging nothing (length), branch counting
including that a nested function's complexity does not leak into its enclosing function's count
(complexity), a renamed-copy pair being caught while a genuinely different function is not, trivial
functions being excluded by the size floor, and the `main()` exclusion's own four branches — a trivial
pair not clustered, the SAME shape under non-`main` names still caught (the exclusion is keyed on the
name, not on being short), and a real over-threshold `main()` duplicated verbatim still caught (the
exclusion is keyed on length too, not on the name alone) (duplication), and — the trickiest logic in this
round — `class_name`-only coupling being caught, local-import-resolution correctly beating a same-named
module in a different subdirectory (the real `anvil`/`economy_check` `schema.py` collision, reproduced
synthetically), and a name matching multiple other subdirectories with no local match being left
uncounted rather than guessed (coupling). All 21 OBSERVED. One assertion — the local-resolution-wins
case — was independently confirmed to have real teeth by deliberately removing the guard it protects and
observing the test correctly fail against the broken version, not just pass against the correct one.

## LOC, reported honestly against the director's own sizing instruction

**847 implementation / 265 test / 1,112 total, as of `docs/DECISIONS_LEDGER.md` D0097** — up from
D0096's 794/217/1,011, not down, and that direction is stated plainly because the director's explicit
instruction after D0096 was to extract the `main()` boilerplate so "the line count comes down because
the actual duplication comes out." It did come out — `duplication.py` reports 0 clusters where it
found 1 (the four-`main()` cluster) at D0096 — but the boilerplate itself was small (16 lines: four
4-line `main()` bodies) and D0097 also added two things the director separately, explicitly required in
the same round: a *named, documented, mutation-tested exclusion* for the general `main()`-dispatch shape
(`duplication.MAIN_BOILERPLATE_MAX_LINES`/`_is_trivial_main_dispatch`, +29 lines with its risk statement)
and a shared dispatch home for the fix itself (`scan.run_cli`, +18 lines). Both are real, requested
content, not padding kept to protect a number. Full accounting, measured via `git diff --stat` against
the D0096 commit, not estimated: `scan.py` +18, `duplication.py` +29, `function_length.py`/`complexity.py`
/`coupling.py` +2 each (a one-line yield-counter header addition), `test_quality_check.py` +48 (4 new
mutation cases) — net +117/−16, +101 total. What D0096's number bought still applies unchanged (two
languages, four structural properties, heavy reuse, the `class_name` coupling fix); what this round adds
on top is the calibration decision the director asked for, mutation-tested to the same standard as
everything else here. Whether the tradeoff is right, now including this round's honest direction, is the
director's call — same as the Anvil cap adjustment (`docs/DECISIONS_LEDGER.md` D0074): the wrong response
to an overrun is cutting good, requested code to hide under a stale figure, not accepting the real number
with the reason recorded.

## Consumers

None yet. Not wired into CI. `dashboard.py`'s output is this round's actual deliverable — read once,
by the director, to see the real distribution before any threshold is proposed.

## Gotchas

- IQR outlier fences on small, heavily-zero-skewed distributions (this repo's current `sim/`/`tools/`
  module counts, for instance) become very sensitive — with most values at 0, the fence itself can land
  at 0, flagging any nonzero value as an "outlier." Real, not a bug, but worth reading the actual counts
  next to the outlier flag rather than trusting the flag alone on a small sample.
- `coupling.py`'s `tools/` resolution is filename-based, not `sys.path`-aware. It gets the specific real
  collision in this repo (`anvil/schema.py` vs `economy_check/schema.py`) right via local-first
  resolution, but a more exotic `sys.path` manipulation than "insert my own parent directory" (this
  repo's only pattern so far) could still fool it.
- Duplication's `MIN_LINES=4`/`MIN_TOKENS=15` floor is a judgment call, not derived from data the way the
  outlier fences are.
- `duplication.py` carries a named, length-bounded exclusion for Python `main()` functions
  (`MAIN_BOILERPLATE_MAX_LINES=8`, `_is_trivial_main_dispatch`) — added after four `main()` functions
  across this directory's own instrument files clustered as an exact duplicate at D0096, and calibrated,
  not guessed, against every other `main()` in the repo (D0097). **Risk, stated per the director's own
  instruction rather than left implicit**: if a future `main()` is both genuinely duplicated AND fits
  within the 8-line bound, this exclusion hides that duplication from the report. Logged as a real Anvil
  `DECISION` event (`.anvil/log/2026-08-28T213152.609167Z-d61283eb.json`), not only here.
