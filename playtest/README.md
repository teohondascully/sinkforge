# Playtest adapter

Status: working adapter; command signatures checked at `61b50fa4`, 2026-09-07.

This directory contains the current game-driving tools. The top-level `harness/` directory
is planned architecture scaffolding, not the launcher for these sessions.

- `seat.gd`: Godot seat serving physical input bursts and captures.
- `seat.sh`: macOS LaunchServices launcher; requires an absolute session directory.
- `stranger.py`: pins session provenance and classifies validity from receipts.
- `replay.py`: replays recorded inputs.
- `supervisor.py`: detects stalled sessions.
- `ceiling.py`: scripted opening and checkpoint creation.
- `evidence.py`: extracts per-burst evidence for review.

Read each tool's `--help` for current options. The launcher is macOS-specific; do not assume
Linux CI uses LaunchServices. Select the engine with the launcher's optional binary argument
or its GODOT environment variable.

Example launch (creates a session and opens a game window):

```sh
python3 playtest/stranger.py start /absolute/path/to/session --mission /absolute/path/to/mission.md
```

Validate an existing session:

```sh
python3 playtest/stranger.py validate /absolute/path/to/session --json
```

Keep diagnostic evaluator receipts distinct from the player-visible observation.
Freeze the tested build during an episode and identify loaded checkpoint provenance.
A valid episode proves only its measured outcome. Invalid episodes retain artifacts and do not count
as player successes or failures. See [evidence retention](../docs/EVIDENCE.md) and
[the active backlog](../docs/BACKLOG.md).
