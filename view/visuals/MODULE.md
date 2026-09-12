# view/visuals

## Purpose

The world as it is drawn: terrain, light, machines, items, the miner, the sky. The largest directory
in `view/` — most files are one painter each, ported piece by piece out of legacy's monolithic
`world_renderer.gd` under the coordinator contract (`view/README.md`, D0240): a painter reads its
`Frame`, draws into its `PaintLayer`, and touches nothing else.

## What's here, by job

- **The palette and looks** — `material_look.gd` (material id -> `Color`; the `view -> data` edge P013
  granted and the layer lint enforces), `item_look.gd`, `machine_look.gd`, `status_look.gd`,
  `miner_look.gd`, `machine_glyphs.gd`, `machine_labels.gd`, `art.gd` (drop-in sprite loader).
- **The terrain pipeline** — `terrain_painter.gd` on the coordinator; `terrain_bake.gd` +
  `bake_window.gd` + `bake_chunk.gd` + `bake_lane.gd` + `bake_data.gd` + `bake_cost.gd` (the static
  terrain baked once instead of drawn every frame, lane-budgeted per tick, D0524/D0528);
  `rock_tone.gd` + `rock_neighborhood.gd` + `gram_map.gd` + `surface_tone.gd` + `bedding_tone.gd` +
  `bed_sequence.gd` (the molded-rock shading and its grammar map); `ore_painter.gd`,
  `seam_painter.gd`, `wall_painter.gd`, `crumble_painter.gd`, `glint_painter.gd`, `grass_painter.gd`,
  `haze_painter.gd`, `water_painter.gd`, `tooth_layer.gd` (the baked quad redrawn above the veil).
- **The veil** — `veil_painter.gd` + `veil_layer.gd` + `veil.gdshader` (mass occlusion and key light),
  `veil_map.gd` + `veil_field_cache.gd` (the lightmap and the openness field held between frames),
  `veil_light.gd`, `veil_sources.gd`, `veil_occlusion.gd` (lamps occluded by the rock they cross,
  D0427), `light_painter.gd` (the additive pass that punches back through), `sky_light.gd` (what the
  sky *delivers*, against `sky_painter.gd`'s what it *looks like*, D0589).
- **Things in the world** — `machine_painter.gd`, `miner_draw.gd`, `rope_painter.gd`,
  `mark_painter.gd` + `mark_layout.gd` (the cursor square and dig marks), `ambience_painter.gd`
  (the placed plane's clockwork), `bubble_rule.gd` (which need-bubble may shout, D0498),
  `backdrop_painter.gd`, `sky_painter.gd`, `post_fx_layer.gd` + `post_fx.gdshader` (the lens:
  vignette, grain, aberration).
- **Shaders:** `veil.gdshader`, `rock_tone.gdshader`, `rock_grit.gdshader`, `rock_tooth.gdshader`,
  `erase.gdshader`, `heat_haze.gdshader`, `post_fx.gdshader`.

## Must-not

- Read past the `Frame`. `obs.in_window(c)`, never `in_bounds` — the gotcha `view/README.md` names:
  `material_at`/`wall_at` return `&""` outside the window, so `in_bounds` draws the viewport's edge as
  the world's edge.
- Carry state the sim owns. Caches (`veil_field_cache`, the bake windows) hold *derived* pixels and
  fields — never game truth.
