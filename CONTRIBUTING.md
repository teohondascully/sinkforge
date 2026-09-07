# Contributing

Status: current workflow, checked against the scripts at `61b50fa4` on 2026-09-07.

## Setup

Use Git, Bash, Godot 4.6.2, and Python 3.12 with PyYAML (the Python dependency installed by CI).
Install PyYAML in your preferred isolated Python environment; for example, an environment outside
the checkout:

```sh
python3 -m venv ../sinkforge-python
source ../sinkforge-python/bin/activate
python3 -m pip install pyyaml
git config core.hooksPath .githooks
godot --editor --path .
```

Wait for the initial import to finish. Launch the game with `godot --path .`.
The main scene is `shell/main.tscn`. No export is required for development.

## Verify changes

Run commands from the repository root, with `godot` on PATH (or replace it with an absolute binary path).

One focused suite:

```sh
bash tools/run_gd_test.sh godot res://tests/test_items.gd
```

The per-commit Godot suite set, selected from CI, with one worker:

```sh
bash tools/run_suites.sh godot 1
```

Structural gates and per-commit Godot suites:

```sh
bash tools/run_local_battery.sh godot
```

The local battery reads the `gates` and `tests` jobs. It does not reproduce every GitHub job,
headed check, scheduled fuzz run, or remote CI environment. Inspect the actual
[workflow](.github/workflows/harness.yml) for those.
Do not pipe verification commands into a command that hides their exit status.
Use isolated fixtures for save-writing tests; the single-suite wrapper itself does not promise
a machine lock or production-save isolation.

Inspect gate implementation/status (this actively runs local checks, including mutation tests,
and can take several minutes):

```sh
python3 tools/gate_status.py
```

Read individual outcomes: some checks may be VOID, unavailable, or remote-only.
This is broader than a quick inventory; do not repeat it after every small edit.

## Content changes

Edit YAML sources in `data/`, then validate and regenerate:

```sh
python3 tools/schema_validator/schema_validator.py
python3 tools/data_codegen/generate.py
python3 tools/data_codegen/generate.py --check
```

Commit corresponding generated records. Do not hand-edit `generated.gd`.

## Review and commits

Read the relevant module contract and [architecture](docs/ARCHITECTURE.md) before structural work.
Preserve concurrent changes. Keep moves separate from behavioral changes and preserve Godot resource
references and UIDs. Follow [branching policy](docs/BRANCHING.md).

This repository uses the owner's commit identity, `teohondascully@gmail.com`, and forbids co-author
and tool-generation trailers. Do not substitute a different person's identity.
Record design judgments under stable IDs in [the ledger](docs/DECISIONS_LEDGER.md);
the commit hook requires a new entry for changes to `core/` or `sim/`, unless its documented
mechanical-change exception applies.

Report what was checked and what was not. A focused suite does not imply the full battery passed.
Update [current work](docs/WORKING.md) and the owning backlog record when a task changes status.
[Quality](docs/QUALITY.md) contains the full verification policy.

## Playtesting

See [playtest/README.md](playtest/README.md). Keep simulation time, wall time, and model waiting time
distinct. Preserve invalid-run evidence and record the build, seed, inputs, and receipt provenance.
