class_name FrameGate
extends RefCounted

## THE TICK'S FRAME, AND WHETHER A STATIC PAINTER STILL HOLDS THE PICTURE IT DREW (D0531). Split out of
## `view/world_view.gd` when that file stood at exactly 400 lines against `docs/QUALITY.md` §2's cap --
## SPLIT rather than trimmed, which is the rule that exists because `sim/body/body.gd` sat at exactly 400
## for three commits running.
##
## ONE OBJECT FOR THE TWO HALVES, and the pairing is a drift argument rather than line arithmetic: the
## key below is a claim about the observation this same call has just built. Computed anywhere else it
## would be free to read a different tick's fields than the painters were handed, and the failure would
## be a layer FROZEN at an old picture -- silent, exactly as `WorldView.add_baked_painter`'s header says
## a wrongly-registered static painter fails.
##
## **WHY THE KEY IS VERSIONS AND SCALARS AND NEVER A HASH OF THE PLANES.** `interface/window_cache.gd`
## settled this one rung down and the argument is unchanged here: "hashing is O(window) and would
## reintroduce a per-cell pass to avoid a per-cell pass. A tick number would be wrong in the other
## direction -- it changes every frame whether or not anything moved, which is the defect being fixed."
##
## **AND WHY IT IS NOT THE OBSERVATION'S OWN IDENTITY.** `Interface.observe` constructs a fresh
## `Observation` on every call (`interface/interface.gd`:142), so "a different object than last tick" is
## TRUE ON EVERY TICK. A gate written that way would queue every layer every tick and pass every test
## that only asserts the picture is right -- a rule that is a no-op by construction, green for the same
## reason a suite over a removed subject is green.

## Cost of the last `Interface.observe()` call, in microseconds. TIMED SEPARATELY because it was the
## suspect for the ~13 ms that D0337 measured OUTSIDE the painters and deliberately did not attribute:
## `observe` builds a dictionary over the whole window, so it is the one per-tick cost that still scales
## with visible area after the painters stopped doing so. `WorldView.last_observe_usec` republishes it.
var last_observe_usec: int = 0

## THE MOLDED-ROCK SHADING, built once and held for the session. It cannot exist before an observation
## does -- `RockTone` is seeded from `Observation.world_seed` -- and a per-frame rebuild would be both
## wasteful and, worse, a different world every frame. The bake asks for it before the first `refresh()`
## (a chunk painted with a null tone would burn the flat fill into a retained target permanently), so the
## one instance lives here rather than at either call site.
var tone: RockTone = null

## What the last queued static redraw was drawn from. `_drew` is false until the first frame, so a
## painter that has never drawn is never skipped -- "empty means valid" is the trap a bare rect and an
## empty key would otherwise be.
var _rect: Rect2 = Rect2()
var _key: Array = []
var _lodes: Dictionary = {}
var _drew: bool = false


func tone_for(world_seed: int) -> RockTone:
	if tone == null:
		tone = RockTone.new(world_seed)
	return tone


## One tick's frame: the observation over `rect`, the cosmetic clock, the palette, the shading and the
## marks the sky steps around. `needs_walls` is the caller's, because only the caller knows whether a
## per-frame painter still reads the wall plane (D0338).
func build(iface: Interface, look: MaterialLook, camera: Camera2D, rect: Rect2, margin: int,
		needs_walls: bool, anim: float) -> Frame:
	var f: Frame = Frame.new()
	var began: int = Time.get_ticks_usec()
	f.obs = iface.observe(Interface.Envelope.covering(rect, margin, needs_walls, true))
	last_observe_usec = Time.get_ticks_usec() - began
	f.anim_time = anim
	f.view_world_rect = rect
	f.zoom = camera.zoom.x if camera != null else 1.0
	f.look = look
	f.tone = tone_for(f.obs.world_seed)
	f.marks = MarkPainter.sky_marks(f.obs)  ## where a build ghost stands, so the stars step aside (6m, D0376)
	return f


## THE STATIC PAINTERS' INPUT KEY: every observation field a painter registered `animated: false` on this
## stack reads, and nothing else. Each entry earns its place from a painter, and a painter added to that
## set without its inputs added here would FREEZE rather than fail:
##
##   * `window` -- the extent every plane below is indexed over, and the one `WindowCache` keys on too.
##   * `terrain_version` -- `TileGrid`'s change token, bumped in the one `_xor_term` every terrain and
##     wall write passes through, so it covers `materials`, `walls` and both legends. It is what
##     `WindowCache` uses to decide those planes cannot have changed; using anything else here would put
##     a second, weaker answer to the same question in the tree.
##   * `cell` -- the body's own cell, which is the band `BackdropPainter` tints its fill toward.
##   * `cell_px`, `world_seed` -- `SeamPainter`'s grain is `Seams.at(cell, world_seed)` in pixels.
##   * `mining_is_charging`, `mining_charging_cell` -- the cell that grain is drawn ON.
##
## The lode plane is NOT here: it is a `Dictionary` and comparing it by value would be O(visible lodes),
## which is the pass `OrePainter.paint_lode` already makes. `statics_dirty` takes its IDENTITY instead.
static func key_of(o: Interface.Observation) -> Array:
	return [o.window, o.terrain_version, o.cell, o.cell_px, o.world_seed,
		o.mining_is_charging, o.mining_charging_cell]


## True when a layer registered `animated: false` must redraw, and records what it will then have drawn
## from -- so this answers YES exactly once per change and NO for every tick that repeats one.
##
## THE LODE PLANE TRAVELS AS A REFERENCE, on purpose. `interface/hub_planes.gd` rebuilds `cache.lodes`
## into a NEW dictionary only when `[deposits.version, terrain_version, window]` moves and hands the same
## instance over on every other tick, so `is_same` is a change token the observation already carries and
## costs a pointer comparison. A rebuild that happened to produce identical content redraws once for
## nothing, which is the safe direction; the unsafe direction -- a change that does not rebuild -- cannot
## happen, because the rebuild IS the change.
func statics_dirty(frame: Frame) -> bool:
	if frame == null or frame.obs == null:
		return true
	var key: Array = key_of(frame.obs)
	if _drew and frame.view_world_rect == _rect and key == _key and is_same(frame.obs.lodes, _lodes):
		return false
	_drew = true
	_rect = frame.view_world_rect
	_key = key
	_lodes = frame.obs.lodes
	return true
