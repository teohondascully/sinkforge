# Recorded input logs

**Two different dialects share this directory — do not assume one format from a filename alone.**
(`docs/DECISIONS_LEDGER.md` D0140 names this exact collision; a prior version of this file only
documented one of the two, which was itself a live instance of the same confusion.)

- **`tests/body/play_scene.gd`** writes `<mode>_<timestamp>.log` (`play` = real keyboard input, `agent` =
  a scripted `ScriptedTraverse` self-test, not a real session). Header: `# sinkforge input recording --
  mode=%s chamber=hostile_chamber ticks=%d`. Columns: `tick,move_dir,jump_pressed,jump_held,mantle_hold`.
  Always the same fixed `HostileChamber` — no `site=`/`seed=` needed to rebuild the grid.
- **`tests/body/reveal_scene.gd`** writes `reveal_<mode>_<timestamp>.log` (`claims/C004`'s own capture
  path). Header: `# sinkforge reveal-scene input recording -- mode=%s ticks=%d site=%s seed=%d`. Columns:
  `tick,move_dir,jump_pressed,jump_held,dig_pressed` (note: `dig_pressed`, not `mantle_hold` — same
  column COUNT as the other dialect, a different fifth column). Site/seed vary, so both are stored in the
  header — `tests/body/reveal_replay_driver.gd`'s `RevealReplayDriver.parse_log` reads them to rebuild
  the exact grid, and (as of queue #3's own fix) validates the column-header comment line by NAME, not
  just by field count, specifically so this dialect and `play_scene.gd`'s own can never be silently
  cross-read even if both formats one day carry a `site=`/`seed=` header.

Kept deliberately, not gitignored: per the director, these are "the seed of the golden corpus" once the
acceptance driver is eventually rebuilt onto `interface/` (`docs/ARCHITECTURE.md` §6's real `input.log`
output) — the only artifact from this stage with value beyond the controller itself. `*_agent_*.log`
files are a self-test byproduct, not a real session; delete them freely (`reveal_agent_2026-08-29T21-34-
03.log` is kept deliberately as a real, mechanically-verified example of `reveal_scene.gd`'s own pipeline
— see `docs/DECISIONS_LEDGER.md` for the entry proving it round-trips). `*play_*.log` files are real
recorded play and should not be deleted without checking with the director first (`CONTEXT.md`: never
delete user artifacts without confirmation).
