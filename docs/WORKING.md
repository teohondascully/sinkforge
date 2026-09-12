# Working state

**Last updated: 2026-09-12 (the "catch the game up to the process" batch landed: economy wiring
`add2a5ad` — iron + rich_ore materials, wood-as-fuel, d3–d7 ladder, gate 37 genuinely blocking;
P044 bedding dip `3db2f6c0`; P031 closed-as-shipped `b41f35dd`; P036 palette ×2 `6c7d05b9`;
P035 lip mantle `450aeb51`. Settings page is now a real Control tree (D0632, Hybrid) — pending
commit. Earlier: CI green on `abef1778` (run 34706318299); all-37 gate verdicts in
`docs/audits/2026-09-11-gate-reconciliation.md` (30 ENFORCED / 3 ADVISORY / 4 NO-CODE / 0 CANNOT-FAIL).
The 931-line predecessor is archived at `docs/archive/working/WORKING-2026-09-11.md`.)**

**THE DIRECTOR'S INSTRUCTIONS, VERBATIM, because they are the whole shape of the run:**
- *"Your goal is to complete all items in the queue overnight without stopping, and if you ever reach a
  blocker, move to the next item and document."*
- *"I'm more concerned about just the entire Tiny Glade / Noita north star for design feel and
  uniqueness. This game doesn't pass as 2026, it passes as 2016."*

## Overnight queue — open items

The full 49-item queue with phase detail lives in the archive snapshot. Open:

- [ ] 21 Provenance plane — RULED do-not-build (Astra D8); scoped, kept open as a marker.
- [x] 30 Falling/drifting leaves — `b6a258cd` (D0622): `LeafDrift` off `sky_floor`, sway field, mutation-witnessed.
- [x] 39 Diegetic depth/band — `6f9abfb3` (D0623): the minimap rules itself (10 m nubs + band seams). Provisional; in-world ticks left for the director.
- [x] 44 Route-driven playthrough — D0625: `ColdStartBot.decide()` is one policy for headless AND the real seat (`--route=cold_start`, legs 60/71/122/149/388/417, captures per boundary). Found: seat-path obs-sharing contract + anchor row bug.
- [ ] 45 Stranger batch started at rung 4, six seats.
- [ ] 51 The lamp's real lever (P038/D0599): `LAMP_TINT` nearly inert.
- [x] 52 Layer contacts dead flat (P044) — `3db2f6c0` (D0629): shared `BeddingDip` in core/, contacts + tone agree, mutation-witnessed both ways.
- [~] 49/Phase 10 THE MATCH LOOP — perpetual; all 4 conditions now have instruments. Moving camera: `--pan` strip lands `e8e68941` (D0624) — holds on both axes; honest residual is sub-tick judder (strips sample ticks, not presented frames).

## Current stage

The A′ legacy port has implemented the playable systems through presentation and generation.
The rig-as-consumer economy is wired end to end (`add2a5ad`, D0628): iron and rich_ore veins feed
forge → mill/press → blast furnace → pump/lift across d3–d7; wood burns at half a coal; gate 37 now
fails rather than reports. The settings modal is a retained Control tree (`SettingsControl` +
`PageTokens`, two skins under `--skin=`); `SettingsPage` remains the model.
[The backlog](BACKLOG.md) owns task routing; [the plan](A_PRIME_REFACTOR_PLAN.md) retains port detail.

## This session — gate arming, readability, scenario driver (2026-09-11)

Landed: gate 24's instrument now mutation-witnessed; gate 5 gained a real `[autoload]` scan in
`check_project_settings.py`; gate 10 scoped to two authored geometries and armed
(`tests/test_softlock_ascent.gd`, dig-climb 2583 ticks, adit 3045); gate 6's `check_module_docs.py`
enforces MODULE.md/README presence over every `.gd`-bearing policed dir; `tools/gate_status.py` matches
glob-run test citations and `--report-only` advisory steps (gates 11, 14, 19, 37 now resolve honestly).

Game side: `demand_satisfied` flows through `observe()` (e3caae87) and C003 is executable —
`tests/test_cold_start_d1.gd` drives a scripted bot through apply/observe to d1 in 414 ticks
(bf662a85), mutation-tested. The scenario layer is real: `scenarios/cold_start_to_d1.yaml` is the run's
single source, schema-validated (gate 13 now covers `scenarios/`), code-generated into
`scenarios/generated.gd`, consumed by `harness/driver/scenario_driver.gd` which selects the bot by the
`agent` field and reports the envelope it actually used (`oracle`, not the requested `constrained`).
T037 dips the starter vein below the pad so mining opens the descent. T001 gave copper a copper mark;
T030 names the dig plan on the first dash; T026 made the ten hotbar wells real remappable actions.
T022/T023/T028 ruled provisional keeps. P042/D0588 SUPERSEDED (D0628): the director ordered the
corrections executed; the iron chain is wired d3-d7 in the mandated order (source → forge → press/mill
→ plate demand), gate 37 exits 0 bare and is blocking again; `pump`/`lift` arrive at d7 rather than
through the reclamation beat the earlier ruling recommended.

## Where the opening stands

Over the last four stranger batches (24 seats, rungs-by-funnel): four ore 24/24; coal 21/24; two ingots
8/24; delivered 4/24; drill placed 2/24; fuel rung 2/24. Last batch alone (D0521): smelt 3/6,
delivered 3/6, drill 2/6. The remaining walls: the world's east edge, the ceremony card read as the
end, a self-dug pit. Reports under [playtests](playtests/).

## Director-pending

P008 (public module interfaces / reach-in), P014 (MODULE.md headroom), P038/P044 (queue items 51/52),
the C003 pacing threshold, the `history/` image cull (168 vs cap 12 — the director's own call per
`history/README.md`), P046 (tree density knob). CI ran on HEAD `abef1778` 2026-09-12 (run
34706318299): all 160 suites, structural gates, headed boot, authorship — green.

## Standing items

Gate 7 has a live WARN; gate 33's margin has recovered (65.4% vs the 61.8% ratchet floor as of
2026-09-12 — QUALITY.md's "three untested functions turns it red" note predates the recovery); the
full fuzz sweep is schedule-only (nightly); headed_boot is unverifiable on this macOS seat. See
`docs/QUALITY.md` audited-status lines per gate.

## Performance programme

D0538's audit corrections govern: the fixture rejects failed processes and empty repetitions,
suppresses withheld comparisons, reports actual maxima separately. D0533 shared per-region CPU shading
landed with exact picture parity; shader seam/appearance correction next, then prefetch and
interpolation. No 360 fps acceptance claim. Detail: [PERF_PLAN.md](PERF_PLAN.md) and
`docs/audits/2026-09-09-*`.

## Repository cleanup (director-approved)

Batches 1–2 (docs authority, backlog routing) complete; batch 3 (harness/test/tool organization)
pending. Evidence: `docs/superpowers/plans/2026-09-07-iteration-efficiency.md`.

## Durable history

The full prior working state — overnight queue detail, the performance programme's dated notes, the
match-loop pass table — is preserved in
[the dated snapshot](archive/working/WORKING-2026-09-11.md) and the earlier
[cleanup snapshot](archive/cleanup-2026-09-07/WORKING.md). [The ledger](DECISIONS_LEDGER.md),
[playtests](playtests/), and [visual records](VISUAL_QUEUE.md) retain source evidence. Do not execute
completed instructions from a snapshot.
