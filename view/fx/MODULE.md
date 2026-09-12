# view/fx

## Purpose

The cosmetic motion layers — things that move on screen because something happened, and carry no
state back. Each is a painter-style pass fed by the `Frame`, the observation, or the consumed
`flow_events`/`events` channels.

- `falling_items.gd` — the visual half of the hybrid item model: products in flight drawn as cosmetics
  while the sim's packed arrays own the truth (A' step 6e, D0365).
- `particles.gd` — bursts on world verbs and the body's landing.
- `light_layer.gd` — one lighting pass painted in world space, so a pass can carry its own blend mode.
- `payouts.gd` — the "+3 ore" tick that rises off the body when the pack gains (D0365).
- `water_drips.gd` — the water-motion cue; representation only (D0362).

## Public API

No module facade; each file is wired by its consumer (`MainView`, the play scene) directly. The
coordinator migration (`view/README.md`, D0240) lists the lifted pieces not yet moved to the `Frame`
contract — `particles.gd` and `light_layer.gd` among them.

## Must-not

- Own truth. A burst, drip or payout is a reading of an event; if the event didn't fire, the effect
  must not pretend it did. The channels these read are consumed-on-observe (`interface/MODULE.md`), so
  an effect can never replay yesterday's tick.
