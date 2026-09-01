# tools/formatter

## Purpose

`.editorconfig` declares five properties for this tree and, until this directory existed, **nothing
checked any of them.** An editorconfig is a request to whichever editor happens to be open. This is the
gate: `formatter.py --check` reports every file that does not match the declared rules, `--write` applies
the fix, and the answers are mechanical by construction — nothing here has an opinion a reviewer would
want to argue with.

    python3 tools/formatter/formatter.py            # check, changes nothing
    python3 tools/formatter/formatter.py --write     # apply

## What it found before it was written

Measured against the tracked tree, not asserted afterwards — the reason this tool exists rather than the
reward for it existing:

| violation | files |
|---|---|
| blank line(s) before EOF | `interface/envelope.gd`, `tests/body/debug_scene_common.gd`, `tests/fixture_step_up_into_wall_probe.gd`, `view/visuals/crack_painter.gd` |
| a run of 3+ blank lines | `sim/body/body.gd`, `tests/test_mining.gd`, `tests/test_shaft_generator.gd`, `tests/test_wall_lode.gd`, `tests/test_reveal_spawn_bounds.gd`, `tools/layer_lint/test_check_loc_ratio.py` |
| no final newline at all | `tests/test_reveal_spawn_bounds.gd` |

Ten files. None of them anyone's carelessness: these are the differences a human eye does not register,
which is the whole argument for handing them to a tool.

Equally worth recording, because it bounds what this tool is for: the same sweep found **zero**
missing-space-after-comma, **zero** space-before-comma, **zero** space-before-close-bracket and **zero**
`#foo` comments across 153 `.gd` files. The GDScript here is already formatted by hand to a standard a
formatter cannot improve. What it can do is hold that standard mechanically, and catch the four
whitespace properties that were drifting precisely because nobody could see them.

## Rules

Six, in the order they run. Full set for `.gd`/`.py`; the byte-level four only for `.sh`/`.yml`/`.yaml`,
since a YAML block scalar and a shell heredoc carry indentation this tool has no grammar for.

| rule | scope | effect |
|---|---|---|
| `charset` | all | strips a UTF-8 BOM, rewrites CRLF/CR to LF |
| `trailing-whitespace` | all | strips trailing spaces/tabs — never inside a string literal |
| `file-edges` | all | no blank lines at BOF or EOF, exactly one final newline |
| `blank-run` | `.gd`, `.py` | collapses 3+ consecutive blank lines to 2 |
| `indent` | `.gd`, `.py` | tabs in `.gd`, 4 spaces in `.py` |
| `comment-space` | `.gd`, `.py` | `#foo` → `# foo`; `##` doc comments keep both marks |

## The two decisions worth reading before editing this

**`indent` refuses rather than guesses.** A `.gd` line indented with a whole number of 4-space groups
becomes tabs. Tabs and spaces mixed, or a space count that is not a multiple of 4, is reported with its
line number and left untouched — a formatter that reshapes an indentation it cannot read unambiguously is
changing program structure on a guess.

**`indent` exempts wrapped trailing comments, and that exemption was paid for.** Eight lines in this tree
are comment-only continuations aligned to a trailing comment in the line above (`sim/body/input_frame.gd:15-16`,
`sim/body/vertical_resolve.gd:21-23`, `tests/body/movement_course.gd:46`,
`tests/fixture_body_fuzz_probe.gd:58`, `tests/fixture_shaft_replay_probe.gd:28`). Their leading spaces are
column alignment, which no tab count can reproduce. A naive spaces-to-tabs pass corrupts all eight. The
rule has the exemption because the lines were read first; the alternative was a repair commit.

## Why not gdformat

`gdformat` (gdtoolkit) is the standard GDScript formatter and was rejected on two grounds. It reflows code
to its own line-length model, which over this tree's comment-dense, hand-aligned source produces a diff
too large to review on lines whose current shape was a decision. And it is a third-party dependency for a
project that has exactly one (`pyyaml`, for the schema validator). The trade taken here is the opposite
one: canonicalize only what has a single defensible answer, and state what is therefore left alone.

## What it deliberately does not do

No operator spacing, no comma spacing, no line wrapping, no argument alignment, no blank-line policy
between declarations. Each needs a real GDScript grammar, and no GDScript parser exists in pure Python —
the same limit `tools/quality_check/scan.py` states about its own tokenizer. They are not implemented at
all rather than implemented and never exercised.

## Scope

`.gd` comes from `tools/layer_lint/gd_scan.gd_files_excluding(root, {"legacy"})` — the same population
`check_size_limits.py` (gates 3-4) and `duplication.py` use, imported rather than re-derived, because a
second definition of "the files we lint" is how D0102 happened. `.py`/`.sh`: `harness/`, `experiment/`,
`tools/`. `.yml`/`.yaml`: `.github/workflows/` and `data/`. Anything git ignores is filtered out
(`gd_scan.git_ignored`, D0225), so a local run and a CI run see one population and `tools/scratch/` is
invisible to both.

`data/<kind>/generated.gd` is in scope on purpose. Those files are written by
`tools/data_codegen/generate.py`, they are already canonical, and keeping them in means this formatter also
fails the day the generator starts emitting something that is not.

## Exit codes

`0` clean. `1` a file needs reformatting (in `--check`), or an indentation this tool refuses to rewrite.
`2` VOID — empty population, a file that will not decode as UTF-8, or a formatting pass that is not
idempotent. `format_text` applies the pipeline twice on every file and raises rather than return an
unstable result: a formatter whose output is not its own fixed point turns `--check` into a coin flip, so
the property is asserted on every run, not trusted from a test.

## Status

- **Mutation tests pass.** `tools/formatter/test_formatter.py` — 76/76 branches observed, covering every
  rule's positive and negative controls, the string-awareness property, the wrapped-trailing-comment
  exemption (including the multi-line chain case), the mixed-indent refusal, idempotence, instability
  detection, self-inclusion (the formatter formats itself), exit codes, and discover scope. Uses the
  shared `Observations` class from `tools/layer_lint/gate_test_support.py` (D0232).
- **The tree has been reformatted.** `--write` fixed 10 files (blank lines at EOF, 3+ blank runs, one
  missing final newline). A second `--check` confirms idempotence: PASS.
- **Not wired into CI or `.githooks/pre-commit`,** and no `docs/QUALITY.md` gate number. Until it runs
  somewhere it cannot be bypassed, it is a tool, not a gate.
