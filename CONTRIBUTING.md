# Contributing

`README.md` covers what the game is; `docs/ARCHITECTURE.md` covers where the code lives. This file is
the working setup: what the test suite protects, how to run part of it without invalidating the part
you did not run, and what a change has to do before it is finished.

## Setup

Godot 4.6.2. `project.godot` targets the 4.6 feature set and CI installs `4.6.2-stable`. Nothing else
is required: there is no build step, no package manager, and no code generation.

```sh
git clone https://github.com/teohondascully/sinkforge
cd sinkforge
git config core.hooksPath .githooks      # once per clone; see "Commits" below
godot --path .
```

The hooks are tracked in `.githooks/` rather than sitting in `.git/hooks/`, because `.git/hooks` is not
version-controlled and produces a guard that exists on exactly one machine. The one-line `git config`
above is what activates them, and `tools/check_trailers.sh` asserts inside the suite that you ran it.

Set a local identity too, or the `pre-commit` hook will refuse the commit:

```sh
git config --local user.email <the address in git log>
```

## Running the game

```sh
godot --path .
```

Opening `project.godot` in the editor and pressing play is the same thing. `SF_SEED` overrides the
default world seed (1337) if you need a different world; `scenes/main.gd` `default_seed()` is where that
is read.

## Running the tests

```sh
bash tools/run_harness.sh
```

That is the whole suite: 103 layers, each in its own process (a Godot run for all but one, which is a
shell script), up to the CPU count in parallel. It takes a machine-wide lock first, so a second sweep
queues rather than competing.

Do not pipe it. `tools/run_harness.sh | tail` gives you `tail`'s exit status, and a red layer
disappears. Run it unpiped, or read the exit line out of the log directory it names.

### The switches you will actually use

| | |
| --- | --- |
| `SF_ONLY='regex'` | run the layers whose names match. A filtered run says so and refuses to print the all-pass line. |
| `SF_HEADLESS=1` | force the no-display path. This is what CI runs, and it is not the same run. |
| `SF_STRICT=1` / `0` | make any skip fail the run, or tolerate skips. Defaults to strict wherever there is a display. |
| `JOBS=1` | serialize. Useful when a failure might be contention rather than the code. |
| `SF_GL_ONLY=1` | run only the layers that need a real display. This plus `SF_NOT` is exactly what CI's second job does. |
| `SF_NOT='regex'` | drop the layers whose names match. CI excludes `check_frametime` this way. |
| `SF_LOG_DIR=/path` | keep every layer's output there. Without it the directory is still printed, and kept unless the run was perfectly clean. |
| `GODOT=/path/to/Godot` | point at a different engine binary. |

The runner takes no command-line arguments. Every switch is an environment variable, so a flag such as
`--headless` is accepted in silence and ignored rather than refused. Five more variables exist for
narrower jobs — `SF_LOCK_WAIT`, `SF_NO_LOCK`, `SF_LOCK`, `SF_REAL_HOME` and `SF_HOME` — and the runner's
own header comment is their reference.

### Exit codes

There are six, and treating "not zero" as "a test failed" misreads four of them:

```
0  everything that ran passed, and anything skipped is named in the summary
1  a layer failed
2  could not start — the sentinel would not arm, or SF_ONLY matched nothing
3  the production save slot was touched (layer results are moot)
4  something was skipped while SF_STRICT was on: not a full sweep
5  another harness run holds the lock
```

They are ordered by severity, so 1 masks 4: a run that both failed a layer and stood assertions down
exits 1, and only the printed summary says the run was also incomplete.

### Anything that boots Godot takes the lock

Not just the harness. A single layer, a capture, a profile: all of them fight each other for the box,
and several layers measure milliseconds. Run one-off scripts through the wrapper.

```sh
bash tools/with_machine.sh --headless --script res://tools/check_mining.gd
```

It supplies `--path <repo>` itself, so do not pass one. It takes the same lock, passes Godot's exit
code through so the three-state protocol survives, and redirects `HOME` and `XDG_*` to an isolated
directory. The redirection is load-bearing: Godot keys `user://` on the project name rather than the
directory, so every checkout on one machine, worktrees included, shares one save slot and one fixture
namespace, and a bare `godot --script ...` writes into the slot the real game is saved in. The
sentinel that hashes that slot around a sweep only guards runs that go through the runner.

### The parse check that saves ten minutes

A GDScript parse error in a dependency does not fail fast. The scene loads with null nodes and spams
errors from `_process` while the process looks healthy from the outside. Check each file you touched
before you run anything that boots it. This boots Godot, so it goes through the wrapper like everything
else:

```sh
bash tools/with_machine.sh --headless --check-only --script res://scenes/main.gd
```

`--check-only` parses and exits on its own, so there is no `--quit` to add, and the wrapper supplies
`--path`.

**Read the output, not the exit code.** `--check-only` prints the parse error and then exits **0** anyway.
That is Godot's behaviour rather than the wrapper's: a bare `godot --headless --path . --check-only
--script <a file with a syntax error>` also exits 0, while the wrapper passes a genuine non-zero through
unchanged, so `quit(7)` still arrives as 7. A script that treats this command's status as the answer gets a
green on every broken file it is handed.

```
SCRIPT ERROR: Parse Error: Expected expression for variable initial value after "=".
          at: GDScript::reload (res://tools/probe.gd:4)
   ...
exit 0
```

### Before you push

Run both:

```sh
bash tools/run_harness.sh                # the full-fidelity run, with a window
SF_HEADLESS=1 bash tools/run_harness.sh  # what CI's headless job does
```

A GDScript guard cannot skip a layer that Godot never boots, so a layer can be green in one run and
dead in the other. Neither result substitutes for the other.

## House conventions

### Formatting

`.editorconfig` has it: tabs in `.gd`, two spaces in Markdown, YAML, JSON and shell. UTF-8, LF,
trailing newline, no trailing whitespace. The `pre-commit` hook rejects mojibake (U+0080 to U+009F),
which is what a byte-oriented editor leaves behind when it re-encodes a UTF-8 file as Latin-1.

### Types are a compile error, not a style rule

`project.godot` sets `gdscript/warnings/untyped_declaration=2`, where 2 means error. Every declaration
needs a type and the editor refuses to run code without one. `:=` inference satisfies it. Loop variables
count: `for cell: Vector2i in cells:`.

### The sim stays node-free

Nothing under `src/` may extend `Node` or call `get_tree()`. Every script there extends `RefCounted`,
`Resource`, or another script in the same directory, and that is what lets `tests/` construct a sim with
no scene tree at all. The representation layer in `scenes/` reads the sim and never writes to it; player
input reaches the sim through the reach-gated verbs on `scenes/main.gd` and nowhere else.

### Content is a data file, not a class

A machine is a `.tres` in `src/data/machines/`; a material is a `.tres` in `src/data/materials/`. The
sim is generic over both. A machine that is not a plain recipe-runner carries a `behavior: StringName`,
and adding one means four things: its hook functions, one row in `FactorySim._BEHAVIORS`, one row in
`Visuals.MACHINE_STYLE`, and the `.tres`. A machine that only runs a recipe still wants the style row,
so its face is its own. Never a scattered if-ladder.

The known cost is registration. Several hand-maintained lists have to agree with the data directory,
and `WorldRenderer._material()` resolves an unknown id to `earth` with no error at all, so a material
missing from its table renders silently as dirt. Two harness layers guard the existing lists. A new
hardcoded registry needs its own.

### Same seed, same world

Moving or adding an `rng.randf()` call reshuffles everything downstream of it, so worldgen edits are
never local. Every worldgen fixture uses a fixed, committed seed for that reason; a randomly-seeded
worldgen check is worse than none.

### Comments say why

The file-level `##` docstring says what the thing is for and, where there was one, the defect that
motivated it. Inline comments explain reasoning, not mechanics: the code already says what it does.

One rule is specific enough to write down. A comment that states a number is a test with no runner.
`docs/ARCHITECTURE.md` described the seal's rows and the descent quota as "rows 56-57" and "40" long
after they had become 84 and 64, and nothing anywhere could notice. Either derive the fact from the
constant (`"%d ingots" % FactorySim.DESCENT_QUOTA`, not `"64 ingots"`) or put it somewhere the harness
checks it.

### UIDs

Godot's `.uid` sidecars are committed for `scenes/`, `src/` and `tests/`, because those scripts are
referenced by `uid://`. They are gitignored for `tools/`, whose scripts are only ever run by path.

## Adding a harness layer

`docs/HARNESS_LAYERS.md` is the full version. The short one:

```gdscript
extends "res://tools/check_base.gd"

## Harness layer: ONE SENTENCE SAYING WHAT MUST BE TRUE.
##
## Then the defect that motivated it, and then NON-VACUITY: how this layer would fail, and what stops
## each assertion passing by never happening.
##   bash tools/with_machine.sh --headless --script res://tools/check_thing.gd

const FLOOR: int = 3

func _initialize() -> void:
    var sim: FactorySim = FactorySim.new()
    # ... arrange the situation, then assert the property, not the variable
    _check(sim.thing() >= FLOOR, "the thing holds at or above the floor (%d)" % sim.thing())
    _verdict("check_thing", "the thing holds")
```

`check_base.gd` gives you `_check(cond, label)`, `_verdict(layer, note)`, `_skip_layer(layer, why)`,
`_stand_down(what, why)` and the reserved `SKIP` code, and nothing else; the fixture is yours to build.
The label is a sentence about the property, not a variable name: "the backup holds the older save,
intact", not "bak_seed == 11".

Note the `extends` line: by path, not by `class_name`. A layer runs under a bare `--script`, and its own
base must not depend on the global class cache being current. That rule is about the base class only.
Referencing `FactorySim` and the rest of the game by name inside the layer is fine and normal. Then
register it in `tools/run_harness.sh`:

```sh
add      "check_thing (what it guards)"  "res://tools/check_thing.gd"   # headless
add_gl   "check_pixels (what it guards)" "res://tools/check_pixels.gd"  # needs a real window
add_excl "check_timing (what it guards)" "res://tools/check_timing.gd"  # needs the machine to itself
```

`add_gl` for anything judging pixels: the headless driver paints blank frames, and a "no dead space"
pass over an all-black image is a lie. `add_excl` for anything measuring time, because a frame-time
layer sharing the box with fifteen other Godot processes is timing the contention.

The exit protocol is three-state. `_verdict()` gives you 0 or 1; `_skip_layer(layer, why)` exits 42 and
means *did not run*, never 0; `_stand_down(what, why)` is for a layer that passed with some assertions
left unmade, and prints a `SKIP:`-prefixed line the runner greps for. That prefix is a contract with the
runner, not a formatting choice.

If the layer's result depends on the world seed, add it to `tools/seed_corpus.sh`. Do not have it build
its own fixture instead: a hand-built world is identical across every seed, which the corpus flags as
seed-blind rather than counting as coverage.

### Non-vacuity

A layer that cannot fail is worse than no layer, because it also spends the credibility of the ones that
can. Break the code and watch the new assertion go red before you commit it. If you cannot make it go
red, you have not written a test.

Never lower a floor to buy green. A threshold may move only when you can write down the reason the
property was never real. Thresholds carry their derivation in a comment beside them: what was measured,
on what, and how much slack the number leaves. A number chosen before running the thing is a wish.

## Commits

One author, and no trailers. Nothing crediting a co-author, and no line attributing any part of the
work to a tool. The `commit-msg` hook refuses them and `tools/check_trailers.sh` sweeps every ref inside
the suite, so `--no-verify` defers the failure rather than avoiding it.

Never `git add -A`. Stage what you changed. The working tree carries ignored scratch output and local
overrides that must not be swept in, and the ignore rules are not a substitute for looking.

The subject line is `type(scope): a lowercase sentence`, and the sentence names the reasoning or the
failure rather than restating the diff. `docs`, `feat`, `fix` and `test` carry most of the history, with
`refactor`, `chore`, `perf`, `viz` and `ci` behind them; past that the type is just the area the change
belongs to, and that set is open rather than fixed. `git log --format='%s'` is the only current list.
Real examples:

```
fix(water): the waterline was sampled every 32px and the ripple constant said 46
fix(harness): the probe that asked whether the rope could bite was moving the body
feat(T3.8): a dropped item now lands somewhere, instead of puffing where it left
docs(decisions): a search's null bounds the search, never the world
```

Bodies are long here and that is deliberate. A commit that fixes something explains what the defect
actually was, why the first diagnosis was wrong if it was, and what evidence says the fix works: the
numbers, not the adjective. If a full sweep was run, say what it returned and whether any failure was
pre-existing.

## Things to leave alone unless the change is the point

- Captured images. `history/` and the canonical `_moment_*.png` are a record of builds that no longer
  exist; re-running the capture tool does not reproduce them. Never `rm` or `git rm` one. To take
  something out of the repository use `.gitignore` or `git rm --cached`, and copy the file somewhere
  outside the tree first: untracking is not preservation, and a later rebase will finish the job.
- `docs/CAPTURE_MANIFEST.md` is generated. `bash tools/capture_manifest.sh` rewrites it and CI runs
  `--check`, so adding or re-shooting a capture is two commits: the frames, then the manifest.
- Worldgen constants. Moving one reshuffles every world downstream of it, including the fixed-seed
  worlds a dozen harness layers measure their floors on. Expect collateral failures and read them before
  concluding anything.
- Harness thresholds. A floor moves only with the distribution in hand and the reason written down. A
  green suite bought by editing a number is worse than a red one, because it is also quieter.
