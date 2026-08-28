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
approximate — both documented), and the shared distribution/outlier-fence math every instrument that
flags outliers uses. Factored out once four consumers needed the same thing — a duplication detector
whose own source duplicated this logic across four files would be the tool disproving its reason to
exist.

## Testability

`function_length.analyze`, `complexity`'s functions, and `duplication.analyze` all accept an injectable
list of synthetic `scan.Func` objects. `coupling.analyze` accepts an injectable `root` directory,
mirroring `tools/anvil/check_integrity.py`'s own `check_integrity(log_dir)` parameter — this project's
established fix for "a checker that can only be pointed at the real, live tree cannot be mutation-tested
without risking it."

## Mutation testing

`test_quality_check.py`, run directly (`python3 tools/quality_check/test_quality_check.py`) — 17 cases,
covering an outlier being flagged and a uniform distribution flagging nothing (length), branch counting
including that a nested function's complexity does not leak into its enclosing function's count
(complexity), a renamed-copy pair being caught while a genuinely different function is not, and trivial
functions being excluded by the size floor (duplication), and — the trickiest logic in this round —
`class_name`-only coupling being caught, local-import-resolution correctly beating a same-named module
in a different subdirectory (the real `anvil`/`economy_check` `schema.py` collision, reproduced
synthetically), and a name matching multiple other subdirectories with no local match being left
uncounted rather than guessed (coupling). All 17 OBSERVED. One assertion — the local-resolution-wins
case — was independently confirmed to have real teeth by deliberately removing the guard it protects and
observing the test correctly fail against the broken version, not just pass against the correct one.

## LOC, reported honestly against the director's own sizing instruction

**794 implementation / 217 test / 1,011 total.** The director's instruction was explicit: "if the whole
suite cannot be built in a few hundred lines, it is too clever." This is over that literal bar, and
that's stated here rather than left for someone else to notice. What it bought: two languages, four
distinct structural properties, heavy reuse of existing gate code where reuse was possible
(`check_size_limits.py`'s function-span scanner, `layer_lint.py`'s `module_of`/`references_in`), and one
real correctness fix (the `class_name` coupling closure) that a smaller version would have shipped
without — measuring `sim/`'s actual dominant coupling mechanism instead of reporting a near-vacuous
"no coupling" on it. Whether that tradeoff was the right one is the director's call, not asserted here as
settled.

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
  outlier fences are. This run's own results include a borderline case worth knowing about when tuning
  it: four `main()` functions across this very directory's own five instrument files clustered as an
  exact duplicate (`result = analyze(); print(format_report(result)); return 0`) — real duplication, but
  about as low-stakes as duplication gets, and a useful data point for where the floor should sit.
