# view/hud

## Purpose

The fixed-frame UI: readouts, teaching surfaces, and the pages. Everything drawn here is a function of
the `Observation` plus local UI state — the HUD never asks the sim a question the envelope didn't
already answer.

## What's here

- **Readouts:** `inspector.gd` (what the aim is over), `depth_chip.gd`, `hotbar.gd` (the carried pack
  as slots), `minimap.gd`, `key_legend.gd` (the line that teaches itself out of existence),
  `binding_labels.gd` (the HUD speaks the *current* bindings, D0411).
- **Teaching:** `objectives.gd` + `objective_line.gd` (the guided step ladder and its banner),
  `hints.gd` + `hint_texts.gd` + `lesson_dock.gd` (just-in-time lessons and their dock),
  `drop_lessons.gd`, `refusals.gd` (what the held verb is refusing, read off the observation, D0488),
  `target_guide.gd` + `ring_painter.gd` + `ring_word.gd` + `shaft_mouth.gd` (the target ring: what is
  ringed, the ring's draw pass, the word under it, the BUILD rung's mouth), `arrival_plate.gd` (the
  stratum ceremony), `wanted_rule.gd` (which pack item a machine in sight is asking for, D0592).
- **Pages:** `page_draw.gd` (the primitives every modal page shares), `settings_page.gd` +
  `settings_draw.gd` (what the settings page *shows*, which is not the same question as what the
  settings are), `ui_theme.gd` (the ink and the plates, owned in one place).
- **The host:** `hud_layer.gd` — the prerequisite every Lane H row hung off (`docs/LEGACY_GAP.md`
  H-01).

## Must-not

- Draw from sim state. The observation is the only read; a HUD element that wants a new number asks
  for an observation field, not a sim reference.
- Teach more than one thing at once. The lesson surfaces are deliberately serialized (the dock shows
  ONE active hint) — a pile-up of concurrent teaching is a regression, not a feature.
