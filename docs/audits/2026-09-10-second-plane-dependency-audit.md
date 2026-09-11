# The second plane: what it actually touches

**Status:** read-only measurement, 2026-09-10, against `a1957804`. No code changed.

Astra's D1 ruling approved **a bounded prototype, not a migration**, and rejected two things the decision
brief had leaned on: that `WallPainter` shows a second plane would read (it does not — it deliberately
skips cells behind solid foreground, so it can never reveal a body behind an opaque mass), and that six
weeks was an established estimate. It also said the brief's four-system fragility list — rendering,
observation, map, saves — was "substantially incomplete", and named six more.

This is that list, measured rather than enumerated.

## The surface, counted

Every function signature that takes or returns a `Vector2i`, by system:

| system | folder | files | fn sigs w/ a cell | `Vector2i` mentions |
|---|---|---|---:|---:|
| the grid itself | `sim/world` | 8 | 91 | 185 |
| rendering | `view/visuals` | 49 | 61 | 256 |
| mining + slump | `sim/mining` | 9 | 37 | 148 |
| collision + grapple | `sim/body` | 12 | 32 | 147 |
| the door + observation | `interface` | 10 | 31 | 127 |
| items | `sim/items` | 5 | 26 | 70 |
| machines | `sim/machines` | 9 | 25 | 79 |
| generation | `sim/terrain_gen` | 11 | 21 | 132 |
| hud + map | `view/hud` | 23 | 9 | 58 |
| commands + replay | `sim/commands` | 1 | 5 | 12 |
| water | `sim/fluid` | 1 | 4 | 31 |
| shell + saves | `shell` | 12 | 4 | 48 |
| transport | `sim/transport` | 1 | 1 | 6 |
| progression | `sim/economy` | 2 | 0 | 0 |
| **total** | | | **347** | **1,299** |

**242 of the 347 are in `sim/`** — 70%. That is the number that matters, because it says this is not a
rendering change with sim consequences. It is a sim change with rendering consequences, and `sim/` is the
half that has to be deterministic, replayable and byte-identical across a save.

## The three that cannot be re-derived, and they are very different sizes

Everything in `view/` can be recomputed from the sim, so it is work but not risk. Three things cannot:

**1. The command log — one field.** `sim/commands` is a single file. A `Command` carries exactly one
coordinate: `var cell: Vector2i`, documented as "MINE: a terrain cell; BUILD/CONFIGURE/LINK_WINCH: a
metre (logic) cell". The entire replay surface for a plane axis is that one field plus whatever writes
it. **This is the cheapest part of the whole change and the brief never mentioned it** — it was assumed
to be expensive by association with determinism.

**2. The save envelope — every plane at once.** `shell/save_game.gd` writes `Vector2i` keys directly
through Godot's binary Variant serializer, across `blocks`, `walls`, `logic.placed`, `dig_extent`,
`winch_routes` and each machine's own `cell`. A plane axis means either `Vector3i` keys throughout or a
per-plane sub-dictionary, and either way every existing save is a different format. Astra's "keep
save/load continuation exact" applies here and nowhere else.

**3. The rope — and this is the one nobody had asked about.** `Grapple` does not hold cells. Its `tip`,
its anchor and up to `MAX_PIVOTS` = 6 pivots are **Fx world pixels** (`Vector2i` at `Fx.SCALE`), each a
point the line has caught on. So "switching planes while attached" is not a rendering question: it asks
what happens to a taut line whose anchor is on a plane the body just left, and what a pivot caught on a
corner means when the corner is one plane back. There is no answer in the code today because the question
cannot currently be posed.

## The ambiguity this repeats, and the one gate already fighting it

`tools/layer_lint/check_coordinate_naming.py` exists because of D0020: *"the 4px terrain grid and the
16px logic grid share one GDScript type, `Vector2i` — nothing at the type level stops a caller from
passing one where the other is expected."* The accepted mitigation was naming discipline (`terrain_cell`
/ `logic_cell`), made mechanical by that gate after the discipline lapsed once and was caught only by a
human sampling three functions at random.

**A second plane adds a third ambiguity to the same type, and the existing mitigation reaches about a
third of the surface.** The gate covers public functions in `sim/world` and `sim/terrain_gen` only —
at most 112 of the 347 signatures. The other 235 have no mechanical guard that a coordinate means what
its caller thinks it means, and the failure mode is the one D0027 already found once: silent, and
discovered by sampling.

That is not an argument against the spike. It is an argument that **the spike's honest first question is
whether the plane travels in the type or in the name**, because the answer decides whether the other 235
sites are a rename or a rewrite — and the director's D0019/D0020 ruling against real wrapper types was
made on an allocation-cost argument about `sim/world`'s hottest paths, which a third axis may or may not
change.

## What the prototype should NOT touch

Following Astra: no save migration, no repository-wide coordinate refactor. A spike that starts by
changing `Vector2i` everywhere has already become the migration the ruling declined.

The prototype can be built entirely inside a scratch scene with its own two grids, its own draw, and a
hand-fed body — enough to answer the four questions Astra actually posed (can someone switch, aim and
build without repeated wrong-plane actions; does the extra plane produce a layout they prefer rather than
merely more room; can they still read material flow; what happens to attached ropes and flowing goods)
without touching `sim/` at all.

## What this audit does not answer

- **Water and slump connectivity between planes.** `sim/fluid` is one file with 4 cell-taking signatures,
  which understates it: connectivity and pressure are properties of the neighbourhood, and a second plane
  changes what "neighbour" means. Unmeasured here.
- **Whether plane-switching bypasses a progression gate.** `sim/economy` has zero cell-taking signatures,
  so nothing in progression is coordinate-aware today — which is exactly why a plane could route around a
  gate without any code noticing.
- **Sound.** Not surveyed.
- **Anything about whether it is fun.** Astra's point, kept: reachability is not desirability, and no
  count here speaks to whether two planes make a better factory or merely a roomier one.
