# CAPTURE MANIFEST

**Generated. Do not edit.** `bash tools/capture_manifest.sh` rewrites it;
`--check` fails if it is out of date.

Every tracked `_moment_*.png`, the commit that wrote it, and a signature of the drawing sources as
they stood in that commit's tree. **Two frames sharing a RENDERER signature are pictures of the same
renderer**, whatever day they were taken; two frames that differ are not comparable to each other and
a vision agent judging them together is judging two builds.

The RECIPE column is how the frame is produced. `UNRECORDED` means the command took an argument
nobody wrote down — an ore-nugget hex, a crop rectangle, a suffix variant's extra state — so the
frame cannot be re-shot faithfully and is an archival record rather than a reproducible baseline.
A recipe invented to fill that column would be worse than a blank one, because it would be run.

| capture | commit | date | renderer | recipe |
|---|---|---|---|---|
| `adit` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- adit` |
| `aim` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- aim` |
| `bench` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- bench` |
| `bench_fresh` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- bench_fresh` |
| `bench_full` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- bench_full` |
| `bench_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_bench.png <crop UNRECORDED>` |
| `bend` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- bend` |
| `boot` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- boot` |
| `boot_green` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `boot_rust` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `boot_silver` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `boot_z1` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- boot 1` |
| `boot_z2` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- boot 2` |
| `boot_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_boot.png <crop UNRECORDED>` |
| `chain` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- chain` |
| `counter` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- counter` |
| `delve` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- delve` |
| `delve_after` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `delve_z1` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- delve 1` |
| `delve_z3` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- delve 3` |
| `delve_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_delve.png <crop UNRECORDED>` |
| `drift` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- drift` |
| `haul` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- haul` |
| `haul_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_haul.png <crop UNRECORDED>` |
| `head` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- head` |
| `head_z1` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- head 1` |
| `land` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- land` |
| `line` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- line` |
| `lode` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- lode` |
| `map` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- map` |
| `mouth` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- mouth` |
| `pack` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- pack` |
| `pack_fresh` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- pack_fresh` |
| `pack_full` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- pack_full` |
| `plunge` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- plunge` |
| `refuse` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- refuse` |
| `room` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- room` |
| `room_after` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `room_before` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `UNRECORDED` |
| `room_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_room.png <crop UNRECORDED>` |
| `scarp` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- scarp` |
| `settings` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- settings` |
| `stain` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- stain` |
| `swing` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- swing` |
| `swing_zoom` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `zoom.gd -- _moment_swing.png <crop UNRECORDED>` |
| `works` | `3c46c8c` | 2026-08-17 14:03 | `9aa816436b` | `capture_moments.gd -- works` |
| `works_fresh` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- works_fresh` |
| `works_full` | `d0ac976` | 2026-08-18 03:12 | `9f26ff4788` | `capture_moments.gd -- works_full` |

## Cohorts

- `9aa816436b` — 41 frames
- `9f26ff4788` — 7 frames

One line here means the archive is one renderer. More than one means it is mixed, which is
permitted and described rather than forbidden: re-shooting is not available for every frame, so
a gate on uniformity would be a gate on a state nobody can reach.
