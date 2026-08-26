# Recorded input logs

Written by `tests/body/play_scene.gd` — one file per session, named `<mode>_<timestamp>.log`, where
`<mode>` is `play` (a real human session, real keyboard input) or `agent` (a scripted `ScriptedTraverse`
self-test of the renderer's own tick/record loop, not a real play session).

Format: a two-line comment header (`# ...`), then one line per tick — `tick,move_dir,jump_pressed,
jump_held,mantle_hold`, comma-separated, matching `InputFrame`'s own fields exactly.

Kept deliberately, not gitignored: per the director, these are "the seed of the golden corpus" once the
acceptance driver is eventually rebuilt onto `interface/` (`docs/ARCHITECTURE.md` §6's real `input.log`
output) — the only artifact from this stage with value beyond the controller itself. `agent_*.log` files
are a self-test byproduct, not a real session; delete them freely. `play_*.log` files are real recorded
play and should not be deleted without checking with the director first (`CONTEXT.md`: never delete user
artifacts without confirmation).
