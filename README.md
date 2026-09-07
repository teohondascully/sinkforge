# Sinkforge

Sinkforge is a 2D excavation and factory game, developed alongside tools for reproducible agent playtesting.

The current build is playable: movement and grapple traversal, mining, physical items, machines,
gravity transport, water and pumping, save/load, a guided opening, lighting, audio, and settings.
The intended long-term loop supplies a permanent surface rig to unlock deeper capabilities.
**The rig demand economy and its D1–D6 progression are not implemented yet.**

## Run

Use Godot **4.6.2** (the version pinned in CI). From the repository root:

```sh
godot --editor --path .
```

Let the editor finish importing, then press F6 on a scene or F5 for the game.
To launch the main scene directly after import:

```sh
godot --path .
```

Python tooling uses Python 3.12 in CI and PyYAML. Setup and test commands are in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Architecture

| Directory | Responsibility |
| --- | --- |
| `core/` | Fixed-point arithmetic, seeded randomness, state hashing |
| `sim/` | World, body, mining, items, machines, transport, fluid simulation |
| `interface/` | Commands and observations shared by game and test clients |
| `view/` | Rendering, HUD, audio, effects |
| `shell/` | Main scene, input, settings, session and save IO |
| `data/` | Validated YAML content and generated GDScript records |
| `playtest/` | Working screenshot/input adapter, replay, supervision, evidence |
| `tests/`, `tools/` | Regression suites, checks, code generation, diagnostics |

The simulation runs headlessly in Godot. It uses explicit ticks and separates simulation state
from scene rendering; it is not an engine-independent runtime.
The `harness/` and `experiment/` directories describe planned layers and remain scaffolding.
See [architecture](docs/ARCHITECTURE.md) for contracts and [playtest usage](playtest/README.md)
for the working adapter.

## Evidence and limitations

Regression suites cover state conservation, traversal, mining, machines, saves, and replay.
[Quality requirements](docs/QUALITY.md) and the
[CI workflow](.github/workflows/harness.yml) identify the enforced checks.
[Playtest reports](docs/playtests/) retain observations against named builds.
A successful tutorial episode does not establish that the full game or demand economy is complete;
agent observations do not replace human play evaluation.

Consult [current work](docs/WORKING.md) and the [backlog](docs/BACKLOG.md) for current limitations.
Older numerical measurements apply to their recorded commit, platform, seed, and scenario.

## Reading further

- [Documentation guide](docs/README.md): design, engineering contracts, and historical evidence.
- [Game design](docs/GDD.md): intended mechanics; proposals are not implementation status.
- [Contributing](CONTRIBUTING.md): setup and verification.
- [Legacy reference](legacy/README.md): the frozen pre-pivot source used by the port.

Historical captures are retained as evidence. Routine local recordings can be much larger than the
tracked source tree; see the [evidence policy](docs/EVIDENCE.md).

MIT licensed; see [LICENSE](LICENSE).
