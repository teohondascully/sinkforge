# view/audio

## Purpose

Everything the game sounds like. Three subsystems, all representation only — nothing here reads or
writes sim state directly; levels and cues are derived from the `Frame`/`Observation` the coordinator
hands down.

- **The beds** (`beds.gd`, `bed_bank.gd`, `bed_levels.gd`, `bed_sequence.gd` lives in `visuals/` as
  paint data): ten looping ambiences under the game, synthesized at boot, whose levels follow what the
  world is doing near the body (`bed_levels.gd` is that derivation, as eight numbers).
- **The score** (`score.gd`): no track list and no cue system — the music is a pure function of
  depth.
- **The voices** (`sfx.gd` pool, `sfx_bank.gd` synthesis, `voice_bank.gd` one-shots,
  `voice_cues.gd` which-cue-as-data, `sfx_space.gd` the one reverb bus, `scene_audio.gd` the rig that
  wires the pool + beds to the play scene).

## Public API

`SceneAudio` (`scene_audio.gd`) is the rig the play scene owns; the other files are its parts —
`Sfx.play(...)`, `VoiceCues.for_frame(...)`, `Beds`/`BedLevels` driven per tick. Ported from
`legacy/scenes/sfx.gd` and A' step 6f (D0366, D0367).

## Must-not

- Read sim state. `bed_levels.gd` and `voice_cues.gd` take the observation they are given; they do not
  reach past it.
- Hold state the sim needs. If a sound matters to the game, the sim emits the event; audio only ever
  reacts.
