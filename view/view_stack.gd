class_name ViewStack
extends RefCounted

## THE RENDER STACK'S COMPOSITION, lifted out of `tests/body/reveal_scene.gd` (D0276). The fourth seam
## taken out of that file after `RevealArgs`, `RevealRecording` (D0244) and `RevealTerrainDraw`, and
## taken for the same reason each time: the scene ORCHESTRATES -- argv, ticks, recording, quitting --
## while this decides which painters exist and in what order. The file was at exactly 400 of a 400-line
## cap, and `docs/QUALITY.md` §2 records what happens when that is met by trimming instead of splitting:
## `sim/body/body.gd` sat at exactly 400 for three commits running.
##
## THE ORDER HERE IS THE PICTURE, which is why it lives in one place rather than being spread across the
## scene's `_ready`. Painters are drawn in `z_index` order and, within a tie, in the order they were
## added -- so this list reads back-to-front:
##
##   -200  backdrop   (the band-tinted fill; `--sky` REPLACES it, see below)
##   -100  sky        (only under `--sky`)
##    -60  wall       (D0286) -- the plane BEHIND the play space, so it is behind everything solid
##    -50  terrain    (D0276)
##    -45  veil       (D0302) -- mass occlusion + key light, and the lamp that cuts it (D0306)
##    -40  glint      (D0300) -- the discovery twinkle, ABOVE the veil for a measured reason below
##    -35  seam       (D0308) -- the grain at the worked cell, above the veil so it stays readable
##      0  cracks     (D0275) -- over the terrain it cracks, under the body doing the cracking
##      0  crumble    (D0278) -- debris from a cell that has just gone, so it sits over the hole
##      0  the scene's own `_draw`: the body sprite and the mining overlay
##     10  the HUD    (a `CanvasLayer`, so the camera does not move it): the depth chip, then the
##                     stratum arrival plate over it (D0288)
##
## Driven through the REAL coordinator rather than a hand-built `Frame`, which is the whole point and was
## D0244's own argument for `--sky`: `SkyPainter` reads nothing from `observe()`, so a shortcut frame
## would have drawn the same picture while proving none of the contract. Every painter added here is
## evidence that observe() -> Frame -> painter -> canvas works end to end.

const BACKDROP_Z: int = -200
const SKY_Z: int = -100
const WALL_Z: int = -60
const TERRAIN_Z: int = -52  ## was -50; two rungs made for the factory under the veil (D0393)
## THE VEIL LANDED 2026-09-01 (D0302, lamp D0306); this paragraph used to say it had not, and said so
## twice in one block. The ordering it argued for is the ordering that shipped, so only the tense is
## corrected: the veil sits ABOVE the terrain and the wall and BELOW the glint. It is a light layer, so
## everything it dims has to already be on the canvas — and legacy draws the glint from `_paint_lights`
## POST-veil for a measured reason its own header records: drawn UNDER the veil, "every flare was scaled
## by `_dark`, the LightLayer with BLEND_MODE_MUL that makes rock dark", so the flare's own darkness
## compensation and the veil's attenuation were the same number and cancelled exactly.
const LODE_Z: int = -58   ## the lode's live metal over the wall bake that leaves its socket bare (6l, D0374)
const WATER_Z: int = -51  ## over the terrain, under the veil: deep water reads dark, daylit bright (6a, D0362)
const BODY_Z: int = -46  ## the miner, UNDER the veil: lit by his own lamp like everything else (D0391); legacy drew him at 60, over it, with a halo instead
const VEIL_Z: int = -45
const TOOTH_Z: int = -44  ## the rock tooth: absolute levels added over the veil so deep rock keeps its grain (6p, D0379)
const HAZE_Z: int = -43   ## the heat haze: bends the rock and the tooth, not the light (6p, D0379)
const LIGHT_Z: int = -42  ## the additive pools, over the veil they punch through, under the glint (6k, D0373)
const GLINT_Z: int = -40
## THE GRAIN SITS ABOVE THE VEIL, for the same reason the glint does and one more (D0308). It is an AIM
## READOUT, not scenery: it answers "which way will this rock part" at the moment of the blow, and a
## readout the veil can dim is a readout that stops working in the exact place the game is played. Below
## the cracks and the body, which are the things doing the parting.
const SEAM_Z: int = -35
## THE FACTORY IS UNDER THE VEIL (D0393, reversing D0364's placement over it). Legacy drew its machines
## below the light layers and lit them by their own pools (`LightPainter`'s machine pools, torches and
## conduit glows are that half, ported in 6k); with the miner under the veil since D0391 a full-bright
## forge beside a lamp-lit miner was the last unlit thing in the frame. What stays above: the marks and
## the seam grain (aim readouts), the falling items (their motes cut the veil), the rope, the glint.
const DROP_PATH_Z: int = -50  ## the guides under the machines to where their output falls (6n, D0377)
const MACHINE_Z: int = -49  ## the factory: over the terrain and water, under the veil, the body and the marks (6c, D0364; D0393)
const AMBIENCE_Z: int = -48   ## the placed plane's clockwork over them: tubes and beads, torches, saplings, piles, updrafts, streaks (6n, D0377)
const MARKS_Z: int = -20    ## the cursor, the dig plan, the ghosts and previews: over the factory, under the rope and the body (6m, D0376)
const FALLING_Z: int = -25  ## the cosmetic drops: over the machines they leave, under the rope and the body (6e, D0365)
const ROPE_Z: int = -10   ## the line and the placed ropes, under the body the scene draws at 0 (5d, D0361)
const PAYOUT_Z: int = 30  ## the "+N" ticks: over the body they rise from and over the scene's own particles (6d, D0365)


## THE HANDLES A SHELL NEEDS (6q, D0380): the HUD chips that keep state or take input. A debug scene keeps
## only the view; a real session feeds the settings page its snapshot, toggles the map, and saves the
## lessons the hints have taught. Filled by `build_stack`; empty on a bare `ViewStack.new()`.
var view: WorldView = null
var settings: SettingsPage = null
var minimap: Minimap = null
var hints: Hints = null
var objectives: Objectives = null
var legend: KeyLegend = null


## Builds the coordinator, attaches it to `scene`, and hangs every painter and the HUD off it.
##
## Returns the `WorldView` rather than storing it: the scene owns the reference, because the scene is
## what calls `refresh()` on the tick it decides to render.
static func build(scene: Node2D, iface: Interface, look: MaterialLook, camera: Camera2D,
		sky: bool, falling: FallingItems = null, payouts: Payouts = null) -> WorldView:
	return build_stack(scene, iface, look, camera, sky, falling, payouts).view


## The same build, returning the stack with its handles.
static func build_stack(scene: Node2D, iface: Interface, look: MaterialLook, camera: Camera2D,
		sky: bool, falling: FallingItems = null, payouts: Payouts = null) -> ViewStack:
	var stack: ViewStack = ViewStack.new()
	var view: WorldView = WorldView.new()
	stack.view = view
	scene.add_child(view)
	view.setup(iface, look, camera)
	# `--sky` REPLACES the backdrop rather than layering over it (D0244): the fill is opaque and would
	# cover the starfield completely.
	if sky:
		view.add_painter(SkyPainter.paint).z_index = SKY_Z
	else:
		view.add_painter(BackdropPainter.paint).z_index = BACKDROP_Z
	# THE TWO STATIC PAINTERS GO INTO THE BAKE, not onto a per-frame layer (D0326, `docs/PORT_ORDER.md` V1).
	# They are the only two on this stack whose picture cannot change unless the terrain does, and they are
	# the expensive ones: legacy measured the terrain pass at ~72% of all frame draw calls. Registered in
	# draw order — wall behind terrain — and baked into ONE quad at `WALL_Z`, which preserves that order
	# inside the target while collapsing both layers to a single draw call per frame.
	#
	# `bake_static` falls back to mounting both as ordinary layers when no render target is available
	# (headless), so this call site is correct on both paths and the picture is the same either way.
	_mount_ground(view)
	# One glint painter and one ore painter, shared: the veil's seam cuts, the seam glow and the glint all
	# read the same population (6l, D0374/D0375).
	var glint: GlintPainter = GlintPainter.new()
	var ore: OrePainter = OrePainter.new(glint)
	_mount_body(view)
	_mount_veil(view, ore, falling)
	_mount_haze(view)
	_mount_over_veil(view, glint)
	_mount_scene_layers(view, falling, payouts)
	_mount_light(view, falling, ore)
	view.add_painter(RopePainter.paint).z_index = ROPE_Z
	# CrumblePainter keeps state (a crumble outlives the tick that spawned it), so it goes in as an OBJECT
	# rather than as a bound Callable. D0289: `add_painter(CrumblePainter.new().paint)` freed the painter
	# at the end of that expression -- a Callable does not keep a RefCounted alive -- and this layer drew
	# nothing for four commits while every suite passed.
	view.add_stateful_painter(CrumblePainter.new(), &"paint")
	# The plate keeps state too: an arrival is one event and the ceremony is two hundred frames. Added
	# after the depth chip so the ceremony draws over the readout it is announcing, not under it.
	# THE LENS, between the world and the HUD (D0328). Added after every world painter and before the HUD
	# so the world is graded and the readouts stay crisp -- ordering enforced by the CanvasLayer indices,
	# which `tests/test_post_fx.gd` asserts against each other rather than trusting this call order.
	view.add_post_fx()
	_mount_hud(view, stack)
	return stack


## The HUD, in draw order: the depth readout, the hotbar and the PACK FULL chip (6g, D0368), the
## objective banner, the minimap and the inspector under it (6h/6i), the lesson bubble, the arrival plate
## over them, the legend, and the settings page (closed) over all of it so a ceremony never draws under it. The legend keeps state --
## which verbs the player has demonstrated -- and removes itself from the picture once it is done.
static func _mount_hud(view: WorldView, stack: ViewStack) -> void:
	var plate: ArrivalPlate = ArrivalPlate.new()
	view.add_hud().add_chip(DepthChip.paint)
	view.add_hud().add_chip(Hotbar.paint)
	view.add_hud().add_chip(Hotbar.paint_pack_full)
	var line: ObjectiveLine = ObjectiveLine.new()
	view.add_hud().add_stateful_chip(TargetGuide.new(line.objectives), &"paint")   # the ring on the rung's target (D0411)
	view.add_hud().add_stateful_chip(line, &"paint")
	var minimap: Minimap = Minimap.new()
	view.add_hud().add_stateful_chip(minimap, &"paint")
	# The inspector and the bubble consult the plate: both stand down while it is on screen (D0369, D0370);
	# the inspector also stacks under the corner map (6i, D0371).
	view.add_hud().add_stateful_chip(Inspector.new(plate, minimap), &"paint")
	var bubble: HintBubble = HintBubble.new(plate)
	view.add_hud().add_stateful_chip(bubble, &"paint")
	view.add_hud().add_stateful_chip(plate, &"paint")
	var legend: KeyLegend = KeyLegend.new()
	view.add_hud().add_stateful_chip(legend, &"paint")
	# The settings page is a modal over everything, the legend included, mounted CLOSED: opening it and
	# feeding it the shell's snapshot is the shell's work (6j, D0372; the shell does it since 6q, D0380).
	var settings: SettingsPage = SettingsPage.new()
	view.add_hud().add_stateful_chip(settings, &"paint")
	stack.settings = settings
	stack.minimap = minimap
	stack.hints = bubble.hints
	stack.objectives = line.objectives
	stack.legend = legend


## THE VEIL IS A MULTIPLY PASS OVER A STRETCHED LIGHTMAP (D0336), which is two properties on its layer and
## neither is optional. Split out of `build()` because that function reached 57 lines against
## `docs/QUALITY.md` §2's 50 cap, and split rather than trimmed for the reason that section records.
##
## Legacy keeps a whole class for this — `legacy/scenes/light_layer.gd`, whose header states the reason:
##
##   > "each pass can carry its own blend mode, which a single CanvasItem cannot switch mid-`_draw`:
##   > terrain passes are MIX, the darkness pass multiplies, so shadow scales the light already there,
##   > and the light pass is ADD."
##
## Set here rather than inside the painter because the blend belongs to the CANVAS: a painter that reached
## out to configure its own layer would be the coordinator contract (`docs/COORDINATOR_CONTRACT.md` §2a)
## inverted, and the painter would stop being a pure function of `(Frame, CanvasItem)`.
## The ground: the two baked painters as one quad, the tooth over it, the lode's live metal, the water.
static func _mount_ground(view: WorldView) -> void:
	view.add_baked_painter(WallPainter.paint)
	view.add_baked_painter(TerrainPainter.paint)
	view.bake_static(WALL_Z)
	ToothLayer.mount(view, TOOTH_Z)
	view.add_painter(OrePainter.paint_lode).z_index = LODE_Z
	view.add_painter(WaterPainter.paint).z_index = WATER_Z


## The miner, as a painter on the frame like every other thing in the world; `MinerDraw` reads the pose
## off the observation and the clock off the frame.
static func _mount_body(view: WorldView) -> void:
	var body: PaintLayer = view.add_painter(MinerDraw.paint)
	body.z_index = BODY_Z


static func _mount_veil(view: WorldView, ore: OrePainter = null, falling: FallingItems = null) -> void:
	# THE GPU VEIL (D0390): `VeilLayer` feeds `veil.gdshader`, which multiplies (`render_mode blend_mul`)
	# and evaluates `VeilPainter`'s expression per pixel; the layer sets its own material on first draw.
	# `VeilPainter.paint_frame`, the CPU lightmap, is the reference it is checked against, not a fallback
	# mounted here: two veils on one stack would darken the world twice.
	var veil: PaintLayer = view.add_stateful_painter(VeilLayer.new(ore, falling), &"paint_frame")
	veil.z_index = VEIL_Z


## THE HEAT HAZE (6p, D0379): a screen-space distortion whose strength is the plume quads' vertex alpha,
## on its own canvas between the veil and the additive pools -- "so hot air bends the rock but not the
## light". The shader is the layer's material; the painter feeds it the deterministic clock.
static func _mount_haze(view: WorldView) -> void:
	var haze: PaintLayer = view.add_painter(HazePainter.paint)
	haze.z_index = HAZE_Z
	var shader: Shader = load("res://view/visuals/heat_haze.gdshader") as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		haze.material = mat


## THE LIGHT PASS IS AN ADD OVER THE VEIL (6k, D0373): legacy's third blend, "the light pass is ADD". The
## blend belongs to the canvas, as the veil's does; the painter stays a function of (Frame, CanvasItem).
## It takes the scene's falling items for the motes, so it is mounted after the scene layers exist.
static func _mount_light(view: WorldView, falling: FallingItems, ore: OrePainter) -> void:
	_mount_additive(view, LightPainter.new(falling))
	# The ore seams glow on the same canvas, drawn after the pools (6l, D0374).
	_mount_additive(view, ore)


## One ADD-blended, LINEAR-filtered canvas at LIGHT_Z for a stateful painter. Two painters get two
## canvases at one z, drawn in mount order.
static func _mount_additive(view: WorldView, painter: RefCounted) -> void:
	var layer: PaintLayer = view.add_stateful_painter(painter, &"paint_frame")
	layer.z_index = LIGHT_Z
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	layer.material = mat
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## The readouts that sit over the veil because the veil must not dim them: the glint (STATEFUL for its
## sparse cache, D0337: the per-frame scan of every visible cell was 11.83 ms), the rock's grain, the
## cracks, the machines.
static func _mount_over_veil(view: WorldView, glint: GlintPainter) -> void:
	view.add_stateful_painter(glint, &"paint_frame").z_index = GLINT_Z
	view.add_painter(SeamPainter.paint).z_index = SEAM_Z
	view.add_painter(CrackPainter.paint_frame)
	view.add_painter(AmbiencePainter.paint_under).z_index = DROP_PATH_Z
	view.add_stateful_painter(MachinePainter.new(), &"paint_frame").z_index = MACHINE_Z
	view.add_painter(AmbiencePainter.paint).z_index = AMBIENCE_Z
	view.add_painter(MarkPainter.paint).z_index = MARKS_Z


## The scene OWNS the falling-item layer (6e, D0365): it consumes the landings for its particle pops, so
## the same instance has to be both painted here and read there. The payout layer rides along.
static func _mount_scene_layers(view: WorldView, falling: FallingItems, payouts: Payouts) -> void:
	if falling != null:
		view.add_stateful_painter(falling, &"paint_frame").z_index = FALLING_Z
	if payouts != null:
		view.add_stateful_painter(payouts, &"paint_frame").z_index = PAYOUT_Z
