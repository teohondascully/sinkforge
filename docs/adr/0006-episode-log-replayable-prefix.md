# ADR 0006: the episode log records a replayable input prefix, not an observation trace

**Status:** accepted, 2026-08-29. Normative for the episode-log format when it is built. **No episode log
is built by this ADR** — this is a constraint written before the format sets, which is the only time it is
cheap to write.

## Context

`docs/DECISIONS_LEDGER.md` D0134 built THE CONTROL PLANE's canonical observation/action types on `tests/`
ground, simulating Boundary A. An external Codex audit read those types against `docs/ARCHITECTURE.md`
and was asked, among other things, which later capabilities the contract forecloses. Its answer on
forking was `UNCLEAR`: "No tick, state snapshot/hash, or episode-log type exists in this slice. Nothing in
the two types prevents a separate log, but nothing enables a fork either."

The director's ruling turned that into a design constraint rather than a type change:

> The observation records what was visible, not the derivation of why — sufficient for replay-then-diverge,
> insufficient for true snapshot-forking later, because a fork would need to reconstruct decision context
> the observation does not carry. The types are fine. The constraint is: when the episode log is designed,
> it must carry enough to reconstruct fork context that the observation alone does not — the full
> replayable state prefix, not just the observation trace.

This ADR records that constraint, and records what investigating it found already in the tree.

## Decision

**The episode log's primary record is the input prefix that reproduces a run, not the observations the
policy saw.** Concretely, an episode log must carry, at minimum:

1. **World identity** — enough to rebuild the identical starting world. Today that is `(site_id, seed)`.
2. **The complete per-tick raw input sequence** — every field of `InputFrame`, not a subset (see Finding 2).
3. **Tick indices**, so a fork point is nameable.

Observations, if logged at all, are a **derived, regenerable projection** of that prefix, and are recorded
for inspection and scoring convenience — never as the authoritative record. Anything reconstructible by
replaying the prefix must not become the thing the format depends on, because a projection cannot
reconstruct what its own filter discarded, and the CONSTRAINED envelope's whole job is to discard.

This is what makes fork-from-any-step possible later without a format change: forking at tick N is
replaying the prefix's first N frames and then diverging. The log does not need snapshots to permit that;
it needs to not have thrown the prefix away.

**Do not build forking.** This ADR's only requirement is that the format not preclude it.

## Finding 1: the required format already exists, and the episode log must be its descendant

`docs/ARCHITECTURE.md` §5 already forbids the obvious mistake, and it is worth quoting because it decides
this on its own:

> That early validation driver is not a throwaway harness: it is a sequence of raw input frames replayed
> against `sim/body` with acceptance metrics read from telemetry, and it is built as the raw action level
> described above from the start. When `interface` lands, this driver becomes `observe`/`apply`'s raw path
> rather than being discarded. **A second, incompatible input-replay format built for pre-interface testing
> would be a design leak; if one starts to look necessary, that is a sign to stop and reconsider rather
> than proceed.**

That driver exists. `tests/body/reveal_replay_driver.gd` (D0129) parses a `tests/body/reveal_scene.gd`
recording — header `mode=<play|agent> ticks=<n> site=<id> seed=<n>`, then one row per tick — rebuilds the
grid through `RevealSessionSetup.build(site_id, seed_value)`, and replays the frames through the real
`Body.tick()`. That is already a replayable state prefix in the sense this ADR requires, and its own
docstring already states the reason in the same terms:

> `(site, seed)` must be recoverable from the log to rebuild the identical grid the recording was played
> against (D0129 added them to `reveal_scene.gd`'s own header) — older logs missing either field cannot be
> replayed and `parse_log` reports why rather than guessing a default that would silently replay against
> the WRONG grid.

So the constraint the director asked to be written down is not a new invention to be designed from
scratch. **The episode log is this format, extended — not a new sibling format beside it.** A new
observation-trace format built alongside would be exactly the "second, incompatible input-replay format"
§5 names as a design leak.

## Finding 2: the existing format is already not a complete prefix, and its two dialects collide

This is the part that would have been discovered after the format set, and is the concrete payoff of
writing the constraint down now.

`InputFrame` has **five** input fields (`sim/body/input_frame.gd`):

```
move_dir, jump_pressed, jump_held, mantle_hold, dig_pressed
```

Neither existing recording dialect records all five. Each records four of them plus the tick index, in
five positionally identical comma-separated columns:

| Writer | Header | 5th column |
|---|---|---|
| `tests/body/play_scene.gd:181` | `# tick,move_dir,jump_pressed,jump_held,mantle_hold` | `mantle_hold` |
| `tests/body/reveal_scene.gd:219` | `# tick,move_dir,jump_pressed,jump_held,dig_pressed` | `dig_pressed` |

`reveal_scene.gd`'s own comment states the substitution outright: "Same format as play_scene.gd's own
recording, plus dig_pressed **in place of** mantle_hold (this scene has no mantle content to test)."

The shared writer encodes the ambiguity by construction. `tests/body/debug_scene_common.gd:13`:

```gdscript
static func record_row(tick: int, move_dir: int, jump_pressed: bool, jump_held: bool, last_field: bool)
```

The fifth parameter is named `last_field`. The one helper both scenes write through is deliberately
agnostic about which semantic field column five holds.

**What currently prevents a misparse, and why that is not reassuring.** `RevealReplayDriver.parse_log`
validates arity only — `if fields.size() != 5` — which **both dialects satisfy**. A `play_scene.gd`
recording is rejected today, but not because the parser noticed the column-meaning mismatch: it is
rejected because `play_scene.gd`'s header pins its world with `chamber=hostile_chamber` and carries no
`site=`/`seed=`, so `found_site`/`found_seed` stay false. The column-five collision is guarded by an
unrelated field's absence. `site=`/`seed=` is the more general world identification and was already
retrofitted onto one scene once (D0129); the day it is retrofitted onto `play_scene.gd`, a `mantle_hold`
column starts replaying as `dig_pressed` silently, and the failure is a diverged replay with no error.

This is the house failure class (`docs/DECISIONS_LEDGER.md`, passim): a validation that cannot register the
thing it is nominally protecting. Arity is not schema.

**Consequence for the episode log, stated as a requirement rather than fixed here:** the episode-log format
must record every `InputFrame` field, and must identify its own column schema in a way a parser checks —
not by position, and not by a `mode=` tag the parser reads but never validates against the columns. A
dropped field is not a smaller log, it is an unreplayable one, and two dialects that differ in meaning
while agreeing in shape are worse than two dialects that fail to parse.

**Not fixed in this ADR, deliberately.** Repairing the two live dialects touches `tests/body/play_scene.gd`,
`tests/body/reveal_scene.gd`, `tests/body/debug_scene_common.gd`, and `tests/body/reveal_replay_driver.gd`,
and would invalidate any recording already on disk — including whatever `claims/C004` is still waiting on a
hands-on-keyboard session to produce. That is a real decision with a real blast radius, and it is not this
ADR's, which was scoped to "do not preclude forking."

## What this ADR does not claim

- **Nothing about determinism is demonstrated here.** `tests/test_replay_determinism.gd` proves the
  replay-and-hash *mechanism* against a `TrivialStub` its own docstring is explicit is "NOT `sim/` and
  never will be." There is no test asserting that the real `Body` + `TileGrid` replay bit-identically from
  a prefix. `RevealReplayDriver` replays against the real sim and `TileGrid.state_signature()` exists to
  hash it, but no gate currently ties those together. Replay-then-diverge rests on real-sim determinism,
  and real-sim determinism is at present an **assumption with good scaffolding**, not a measured property.
  Establishing it is a prerequisite for trusting any fork, and is not done.
- **No claim that forking works.** Nothing forks. This ADR permits it; it does not demonstrate it.
- **No claim that the canonical types are complete for this purpose.** They were audited as sound for the
  raw-input boundary they cover (D0134, and the Codex audit above). `CanonicalObservation` carries no tick
  index and no state signature; whether the episode log needs those on the observation side, or only on the
  prefix side, is open and does not have to be answered to honor this ADR.

## Consequences

- The episode log, when built, extends `reveal_scene.gd`'s recording lineage rather than starting a new
  format. `docs/ARCHITECTURE.md` §5's design-leak warning is the governing text.
- Finding 2 is now on the record as a known defect in the existing dialects, with a named trigger for when
  it stops being latent (`site=`/`seed=` reaching `play_scene.gd`).
- Real-sim replay determinism is named as an unproven prerequisite rather than assumed, so a future fork
  implementation inherits the gap instead of discovering it.
