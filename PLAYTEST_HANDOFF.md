# Sinkforge screen-led playtest handoff

## State

The opt-in playtest adapter is committed with the input contract test. It launches the ordinary `shell/main.tscn`, isolates settings/save files under a caller-provided directory, accepts only bounded physical key/mouse bursts, and captures a PNG plus JSON observation after each burst. It does not expose simulation state, target coordinates, inventory, or semantic gameplay commands.

Latest verified commit: see `git log -1`.

## Files

- `playtest/seat.gd` — paused-between-bursts Godot launcher.
- `playtest/input_bridge.gd` — physical key/mouse event bridge and validation.
- `playtest/command.py` — sends one JSON burst and waits for its response.
- `tests/test_playtest_input.gd` — 15 assertions for bounds, press/release edges, and mouse/key delivery.

## Run

```sh
SESSION="$(mktemp -d /tmp/sinkforge-player-XXXXXX)"
godot --path . --resolution 1280x720 --script res://playtest/seat.gd -- --session-dir="$SESSION"
python3 playtest/command.py "$SESSION" '{"ticks":1,"mouse":[640,360]}'
```

The Godot process must remain running in another terminal. Each command is limited to 1–300 ticks and must use viewport coordinates in 1280×720. The response and `frame_NNNN.png` are the player-visible evidence. Finish with `{"quit":true}`.

## Evidence from this session

Fresh boot showed the objective clearly: “Mine 4 ore 0/4 — Hold LMB on the silver-flecked rock two steps to your LEFT.” The world, miner, target ring, forge, depth chip, minimap, and bottom control legend were visible. A 60-tick LMB burst at the guessed target did not advance ore; a short left movement changed the camera, but the target remained unclear. This is diagnostic only: the pointer coordinate was guessed from the screenshot and the adapter is not yet a calibrated mouse/aim tool.

## Next Fable tasks

1. Read each fresh frame before choosing the next burst; do not use internal state or tutorial coordinates.
2. Calibrate pointer-to-world behavior from visible aim feedback, then attempt the opening again.
3. Record first ore, first ingot, first automation, hesitation, retries, and stop reason in a dated report.
4. Add an independent journey receipt only after the screen-led session is complete; replay the physical input log separately.
5. If changing the adapter, add a failing test first and preserve the player-visible boundary.

Known limitation: this environment has no OS-level desktop-control permission, so the adapter provides in-game event injection and screenshots, not a human mouse cursor or audio capture. Do not call the partial attempt a human-equivalent verdict.
