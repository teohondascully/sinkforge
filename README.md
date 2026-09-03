# Sinkforge

Sinkforge is a 2D vertical mining and factory game with a deterministic, engine-free simulation
underneath it. You bore a shaft from a permanent surface rig, build extraction and routing inside the
shaft, and haul refined material back up to a rig that keeps asking for more. The simulation runs
headless and byte-identically on replay, so scripted agents can play the same game a human plays and
the results can be compared.

The repository holds two things: the game, and the instrument that measures it. Neither is finished.
This file says what exists, what does not, and where the proof is.

## State of the build, 2026-09-03

A complete, playable version of this game exists in `legacy/`, frozen at tag `pre-pivot`
(2026-08-25). It has a forge, drills, ingots, water, a winch, a grapple, a full HUD and synthesized
audio, and it runs headless end to end. Its economy was terminal: demand died about fifteen minutes in.
Its simulation was not verifiable the way this project wants (two clocks, float kinematics in the
scene layer, no cross-process replay).

The current tree is the rebuild of that game on a deterministic substrate. What is in it, measured at
`6f0d894e`:

| area | lines | what it is |
|---|---|---|
| `core/` | 422 | i32 fixed point, seeded splittable RNG, generational ids |
| `sim/` | 2,992 | tile grid with a running state hash, seeded terrain generator, tick-only body, integer mining |
| `interface/` | 622 | `observe()` and `apply()`, the one door into the sim |
| `view/` | 5,706 | 17 visual modules and 3 shaders, HUD chips, audio, particles, all reading observations only |
| `tests/` | 16,438 | 68 suites run by CI under the pinned engine, 446 test functions |
| `tools/` | 8,709 py + 1,704 sh | 36 quality gates under 35 numbers (gate 30 is numbered twice) plus their mutation tests |

What is not in it: machines, items, water, power, transport, an economy, a grapple, a main scene.
`sim/machines`, `sim/items`, `sim/transport`, `sim/fluid` and `sim/economy` are `MODULE.md` files with
zero lines of code. You cannot play the current build as a game yet; you can run its debug scenes.

The plan to close that gap is `docs/A_PRIME_REFACTOR_PLAN.md`: lift legacy's simulation hub, which a
complete read found to be already fixed-tick and integer-shaped, onto the substrate as a block, then
port the views it unblocks, then redesign the economy. The analysis behind that decision, including a
per-file verdict on all 491 code files, is `docs/FLIP_ANALYSIS_2026-09-02.md`.

## What is verified, and how

Determinism is proven within a platform and open across platforms. `tests/test_shaft_replay_determinism.gd`
runs a real generated world with a body driven 20,000 ticks by seeded random input in two separate OS
processes and asserts 200 checkpoint hashes identical, then asserts them against goldens captured
from CI's Linux build. It is green. The same run diverges between macOS-arm64 and Linux-x86_64 at
checkpoint 3, because four sites on the terrain-generation path use floats (`docs/DECISIONS_LEDGER.md`
D0171, D0183). That is a known, diagnosed gap with a scoped fix, not a surprise.

The body is fuzzed goallessly every commit (100 seeds × 500 ticks) and nightly (1,000 × 1,500), with
six invariants held at zero. The tracked human play recordings replay as a binding regression corpus.
Every gate is mutation-tested: a check that has never been seen failing is not counted as a check
(`docs/QUALITY.md` §2). Run `python3 tools/gate_status.py` for the live gate state; it reads the CI
workflow rather than a hand-typed list.

CI: `.github/workflows/harness.yml`, green on `main` at the time of writing.

## Architecture in one screen

```
L4  experiment   claims, sweeps, ablations          (README-only today)
L3  harness      scenarios, envelopes, driver       (README-only today)
L2  interface    observe() and apply()              (built)
L1  sim          the game, deterministic, no engine (terrain, body, mining built; machines etc. not)
L0  core         fixed point, seeded RNG, ids       (built)
view/ and shell/ hang off L2 as peers of the agents.
```

Dependency direction is lint-enforced. `sim/` imports no engine class, reads no clock, does no IO.
Positions and velocities are fixed point. The sim advances only by explicit tick. Full detail:
`docs/ARCHITECTURE.md`; the design: `docs/GDD.md`; the four rules the design will not break: `CONTEXT.md`.

## Reading order

`CONTEXT.md`, then `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CLAIMS.md`, then
`docs/WORKING.md` for what is happening now. `docs/README.md` says which documents are normative; if a
document is not in that table it is not.

## `legacy/`

The pre-pivot game, read-only, excluded from the engine's import scan and from every gate, byte-identical
to tag `pre-pivot`. It is kept because it is the worked reference the rebuild ports from, file by file,
each commit naming the source path. `docs/A_PRIME_REFACTOR_PLAN.md` §3 classifies every file in it as
LIFT, REFERENCE or DEAD.

## Repository size

The pack is about 511 MB. `history/` (170 files) and `docs/media/` (72) are tracked captures and are
most of it; both are deliberate, both carry `.gdignore`. `legacy/` is 4.3 MB of tracked files.

## License

MIT. See `LICENSE`.
