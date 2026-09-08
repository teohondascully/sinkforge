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

## Iteration tools (opt-in)

`python3 playtest/timing_report.py /absolute/path/to/batch_109-114.json` reads existing artifacts only.
It separates summed seat time from the span/union of observed command intervals; neither includes full
boot/shutdown time. Missing inputs, malformed timing, duplicate IDs, incomplete runs and mismatched
builds are warnings, not gameplay verdicts. Between-command time is not a pure inference measurement.

`python3 playtest/step_tool.py --session /absolute/path/to/owned/session` is an MCP stdio pilot.
Configure that command in an MCP-capable client, using the script from the frozen runtime copy and a
fresh, exclusively assigned seat. It does not launch a seat or change any agent configuration itself.
The `play_step` tool takes `command` (the existing physical burst JSON) and optional `note`; its one
response includes the original PNG and only the existing player receipt fields. No `--full` access.
It supports MCP initialize/tools protocol versions through 2025-11-25; it is not a full MCP platform.
Reference: [MCP image/tool schema](https://modelcontextprotocol.io/specification/2025-11-25/schema).

Do not use `command.py` and the pilot concurrently on the same seat. The pilot locks other pilot
servers, not legacy command senders. Failures return a generic actor error; the evaluator inspects
local artifacts before retrying, because an input may already have executed. Journals, timings and
original images remain on disk. This was protocol-tested against a disposable filesystem seat and the
real command adapter, not a live model/client latency trial. It is not enabled for existing missions.
Tests live in `tools/test_timing_report.py` and `tools/test_step_tool.py` so the existing CI glob runs them.
