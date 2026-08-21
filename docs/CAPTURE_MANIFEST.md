# CAPTURE MANIFEST

**Generated. Do not edit.** `bash tools/capture_manifest.sh` rewrites it;
`--check` fails if it is out of date.

Every tracked `_moment_*.png`, the date it was written, and a signature of the drawing sources as
they stood in the tree that wrote it. **Two frames sharing a RENDERER signature are pictures of the same
renderer**, whatever day they were taken; two frames that differ are not comparable to each other and
anyone judging them together is judging two builds.

The RECIPE column is how the frame is produced. `UNRECORDED` means the command took an argument
nobody wrote down — an ore-nugget hex, a crop rectangle, a suffix variant's extra state — so the
frame cannot be re-shot faithfully and is an archival record rather than a reproducible baseline.
A recipe invented to fill that column would be worse than a blank one, because it would be run.

| capture | date | renderer | recipe |
|---|---|---|---|
| `adit` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- adit` |
| `aim` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- aim` |
| `bench` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- bench` |
| `bench_fresh` | 2026-08-18 03:12 | `8ba28b06f4` | `capture_moments.gd -- bench_fresh` |
| `bench_full` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- bench_full` |
| `bench_next` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- bench_next` |
| `bench_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_bench.png <crop UNRECORDED>` |
| `bend` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- bend` |
| `boot` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- boot` |
| `boot_green` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `boot_rust` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `boot_silver` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `boot_z1` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- boot 1` |
| `boot_z2` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- boot 2` |
| `boot_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_boot.png <crop UNRECORDED>` |
| `chain` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- chain` |
| `counter` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- counter` |
| `dashboard` | 2026-08-18 04:58 | `03bd8f57df` | `capture_moments.gd -- dashboard` |
| `delve` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- delve` |
| `delve_after` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `delve_z1` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- delve 1` |
| `delve_z3` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- delve 3` |
| `delve_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_delve.png <crop UNRECORDED>` |
| `drift` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- drift` |
| `haul` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- haul` |
| `haul_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_haul.png <crop UNRECORDED>` |
| `head` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- head` |
| `head_z1` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- head 1` |
| `land` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- land` |
| `line` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- line` |
| `lode` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- lode` |
| `map` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- map` |
| `mouth` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- mouth` |
| `pack` | 2026-08-20 18:32 | `b87bae9a44` | `capture_moments.gd -- pack` |
| `pack_fresh` | 2026-08-18 03:12 | `8ba28b06f4` | `capture_moments.gd -- pack_fresh` |
| `pack_full` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- pack_full` |
| `plunge` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- plunge` |
| `quiet` | 2026-08-18 04:58 | `03bd8f57df` | `capture_moments.gd -- quiet` |
| `refuse` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- refuse` |
| `room` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- room` |
| `room_after` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `room_before` | 2026-08-17 14:03 | `4ad3509248` | `UNRECORDED` |
| `room_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_room.png <crop UNRECORDED>` |
| `scarp` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- scarp` |
| `settings` | 2026-08-18 03:12 | `8ba28b06f4` | `capture_moments.gd -- settings` |
| `stain` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- stain` |
| `swing` | 2026-08-17 14:03 | `4ad3509248` | `capture_moments.gd -- swing` |
| `swing_zoom` | 2026-08-17 14:03 | `4ad3509248` | `zoom.gd -- _moment_swing.png <crop UNRECORDED>` |
| `works` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- works` |
| `works_fresh` | 2026-08-18 03:12 | `8ba28b06f4` | `capture_moments.gd -- works_fresh` |
| `works_full` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- works_full` |
| `works_short` | 2026-08-18 04:33 | `47992d44ab` | `capture_moments.gd -- works_short` |

## Cohorts

- `4ad3509248` — 37 frames
- `47992d44ab` — 8 frames
- `8ba28b06f4` — 4 frames
- `03bd8f57df` — 2 frames
- `b87bae9a44` — 1 frames

One line here means the archive is one renderer. More than one means it is mixed, which is
permitted and described rather than forbidden: re-shooting is not available for every frame, so
a gate on uniformity would be a gate on a state nobody can reach.
