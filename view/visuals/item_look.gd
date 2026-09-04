class_name ItemLook
extends RefCounted

## THE ITEM VOCABULARY (A' step 6b, D0363): what a carried, falling or resting thing looks like and what it
## is for. Legacy `scenes/visuals.gd`'s `item_color`, `ITEM_PURPOSE`, `draw_item` and its drawers, for the
## population THIS build carries: every material a bore yields (D0349: the material id is the item id, so
## the ground's colours come from `data/materials` rather than a second table), every recipe input and
## output, the placeables, wood and coal. Legacy's tools, bits, scanner and the rig's materials are not
## carried. Each drawer's SILHOUETTE IS WHAT THE THING DOES, which is the argument legacy made twice: a
## shape survives being 16 px tall where a tint does not, and `check_item_reads` found the pairs that
## differed by tint alone indistinguishable.

const COLORS: Dictionary = {
	&"ore": Color(0.88, 0.52, 0.24),          # ore amber
	&"rich_ore": Color(1.0, 0.86, 0.46),      # white-gold: the high-grade vein's chunk
	&"iron": Color(0.72, 0.76, 0.85),         # pale steel, the second ore
	&"ingot": Color(0.97, 0.85, 0.42),        # ingot gold
	&"iron_ingot": Color(0.80, 0.84, 0.92),   # refined steel bar
	&"plate": Color(0.66, 0.71, 0.80),        # rolled sheet: the press's product
	&"gear": Color(0.82, 0.68, 0.34),         # bronze-toothed cog, the mill's product
	&"coal": Color(0.24, 0.25, 0.29),         # dark slate-black, the generator's fuel
	&"wood": Color(0.55, 0.38, 0.22),
	&"rope": Color(0.78, 0.66, 0.44),         # hemp, the placeable climb
	&"torch": Color(1.0, 0.76, 0.36),         # flame amber: placeable light
	&"conduit": Color(0.66, 0.47, 0.30),      # copper, the power tube
	&"sapling": Color(0.44, 0.66, 0.30),      # young leaf-green, the renewable-wood seed
}
## What a stack in the hand is FOR, one line each: machines answer "what does placing it buy", resources
## "what wants this". Re-authored against what exists; an absent id draws no purpose line.
const PURPOSE: Dictionary = {
	&"ore": "smeltable — the Forge turns it into ingots (drop it in)",
	&"rich_ore": "high-grade ore — a Blast Furnace pours 2 ingots from 1",
	&"iron": "the second ore — the Iron Forge smelts it into iron ingots",
	&"ingot": "the base metal — what the mill and the rig will want",
	&"iron_ingot": "the iron metal — plates and gears",
	&"plate": "pressed iron sheet",
	&"gear": "milled cog (iron ingot + ingot)",
	&"coal": "FUEL — generators and drills burn it (drop it on them)",
	&"wood": "placeable block — and what ropes and torches are made of",
	&"leaves": "the canopy — clears in a swing; the trunk under it is the wood",
	&"rope": "place it above a drop — it unrolls down; W/S climbs it",
	&"torch": "place it on a wall-backed cell — light that STAYS",
	&"conduit": "lays power tube — power flows down and sideways, never up",
	&"sapling": "plant it on soil — a new tree grows (renewable wood)",
	&"clay": "placeable block — the soft topsoil rock; a sapling roots in it",
	&"hardrock": "placeable block — the hard band's rock",
	&"deepstone": "placeable block — the deep rock",
	&"glimmer": "the glittering rock of the deep — a block, and a light of its own",
	&"ore_iron": "iron-bearing rock — smelts to iron",
	&"ore_copper": "copper-bearing rock — smelts to ore",
	&"processor": "the Forge — smelts what falls into it (ore → ingots)",
	&"iron_forge": "smelts iron ore into iron ingots",
	&"blast_furnace": "smelts RICH ore 1 → 2 ingots — the deep veins' payoff",
	&"plate_press": "presses iron ingots into plates",
	&"gear_mill": "mills iron ingots + ingots into gears (two inputs, one column)",
	&"drill": "bores straight down through an ore vein — burns coal",
	&"generator": "burns coal into POWER for the machines around it",
	&"hopper": "banks what falls in, meters it DOWN — keeps the first item it tastes",
	&"lift": "hauls goods — and YOU — up its column; power multiplies it",
	&"pump": "POWERED, it drains water from its own cell and the ones below — the way back out of a flood",
	&"winch_head": "POWERED — hauls what falls into it up to a linked Station (L links them)",
	&"winch_station": "the far end of a Winch route — what the Head hauls lands here",
}


## A material's base colour off its record, or white for a thing that is neither material nor tabled.
static func color(item: StringName) -> Color:
	if COLORS.has(item):
		return COLORS[item]
	var rec: Dictionary = MaterialsRecords.RECORDS.get(String(item), {})
	if rec.has("base_color"):
		return _rgb(rec["base_color"])
	return Color.WHITE


static func purpose(item: StringName) -> String:
	return String(PURPOSE.get(item, ""))


## Debris and dust colour for a mined material: roughly its rock tone, a shade under it.
static func terrain_dust(material: StringName) -> Color:
	return color(material).darkened(0.15)


static func _rgb(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))


## Draw an item icon centred at `center`, `size` px square. Sprite-ready: `item_<id>.png` replaces the
## procedural glyph the moment it exists; absent, a drawn glyph that reads as the thing. One helper so
## ground piles, the hotbar and anything else share the same look and the same sprite swap.
static func draw(canvas: CanvasItem, center: Vector2, size: float, item: StringName) -> void:
	var tex: Texture2D = Art.tex("item_" + String(item))
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		return
	match item:
		&"ore", &"ore_copper":
			_nugget(canvas, center, size, Color(0.44, 0.46, 0.52), Color(0.90, 0.56, 0.24), Color(1.0, 0.82, 0.5))
		&"ore_iron":
			_nugget(canvas, center, size, Color(0.40, 0.43, 0.50), Color(0.78, 0.82, 0.92), Color(0.95, 0.97, 1.0))
		&"iron":
			_iron(canvas, center, size)
		&"rich_ore":
			_rich_ore(canvas, center, size)
		&"ingot":
			_bar(canvas, center, size, Color(0.93, 0.78, 0.36))
		&"iron_ingot":
			_bar(canvas, center, size, Color(0.74, 0.79, 0.88))
		&"plate":
			_plate(canvas, center, size)
		&"gear":
			_gear(canvas, center, size)
		&"coal":
			_coal(canvas, center, size)
		&"wood":
			_wood(canvas, center, size)
		&"sapling":
			_sapling(canvas, center, size)
		&"rope":
			_rope(canvas, center, size)
		&"torch":
			_torch(canvas, center, size)
		&"conduit":
			_conduit(canvas, center, size)
		&"clay":
			_clod(canvas, center, size, color(item))
		&"deepstone":
			_shard(canvas, center, size, color(item))
		&"glimmer":
			_block(canvas, center, size, color(item))
			_seam(canvas, center, size, Color(0.87, 0.90, 1.0))
		_:
			_block(canvas, center, size, color(item))


## Polygon helper: points as size-fractions from the centre (y+ down), filled with a crisp darker outline
## so a glyph reads at hotbar scale.
static func _poly(canvas: CanvasItem, c: Vector2, size: float, frac: Array, fill: Color) -> void:
	var pts := PackedVector2Array()
	for f: Vector2 in frac:
		pts.append(c + f * size)
	canvas.draw_colored_polygon(pts, fill)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), fill.darkened(0.45), maxf(1.0, size * 0.03), true)


## A rough rock nugget with bright flecks embedded: "metal IN rock".
static func _nugget(canvas: CanvasItem, c: Vector2, size: float, host: Color, fleck: Color, glint: Color) -> void:
	_poly(canvas, c, size, [Vector2(-0.34, -0.06), Vector2(-0.10, -0.34), Vector2(0.28, -0.24),
		Vector2(0.36, 0.14), Vector2(0.06, 0.34), Vector2(-0.30, 0.22)], host)
	for f: Vector2 in [Vector2(-0.10, 0.02), Vector2(0.14, -0.10), Vector2(-0.02, 0.18)]:
		canvas.draw_circle(c + f * size, size * 0.06, fleck)
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, glint)


## IRON is a CLUSTER of two lumps on a diagonal: the one concave rock glyph, so it separates from every
## convex nugget by a cue that survives 16 px (legacy measured tint alone could not).
static func _iron(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var host := Color(0.50, 0.55, 0.66)
	_poly(canvas, c, size, [Vector2(0.02, 0.06), Vector2(0.24, -0.02), Vector2(0.40, 0.16),
		Vector2(0.28, 0.36), Vector2(0.02, 0.32)], host)
	_poly(canvas, c, size, [Vector2(-0.42, -0.12), Vector2(-0.18, -0.36), Vector2(0.06, -0.28),
		Vector2(0.10, 0.02), Vector2(-0.14, 0.20), Vector2(-0.40, 0.10)], host.lightened(0.06))
	for f: Vector2 in [Vector2(-0.20, -0.10), Vector2(-0.06, 0.06), Vector2(0.22, 0.16)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(0.78, 0.82, 0.92))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(0.95, 0.97, 1.0))


## RICH ORE: a nugget the ore has crystallised out of, spurs breaking the outline.
static func _rich_ore(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.34, 0.02), Vector2(-0.22, -0.16), Vector2(-0.30, -0.46),
		Vector2(-0.06, -0.22), Vector2(0.10, -0.48), Vector2(0.22, -0.18), Vector2(0.42, -0.04),
		Vector2(0.30, 0.16), Vector2(0.34, 0.36), Vector2(0.08, 0.26), Vector2(-0.18, 0.32)], Color(0.40, 0.40, 0.46))
	for f: Vector2 in [Vector2(-0.14, 0.00), Vector2(0.10, -0.14), Vector2(0.20, 0.10), Vector2(-0.02, 0.20), Vector2(-0.04, -0.20)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(1.0, 0.86, 0.46))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(1.0, 0.97, 0.80))


## The cast bar: a trapezoid with a lit top face, the classic ingot silhouette.
static func _bar(canvas: CanvasItem, c: Vector2, size: float, metal: Color) -> void:
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.40, 0.18), Vector2(-0.40, 0.18)], metal)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.20, -0.06), Vector2(-0.20, -0.06)], metal.lightened(0.28))


static func _plate(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var sheet := Color(0.62, 0.67, 0.77)
	_poly(canvas, c, size, [Vector2(-0.38, -0.10), Vector2(0.30, -0.24), Vector2(0.38, 0.10), Vector2(-0.30, 0.24)], sheet)
	canvas.draw_line(c + Vector2(-0.38, -0.10) * size, c + Vector2(0.30, -0.24) * size, sheet.lightened(0.30), maxf(1.0, size * 0.05))


static func _gear(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var bronze := Color(0.80, 0.64, 0.30)
	canvas.draw_circle(c, size * 0.26, bronze)
	for i: int in 7:
		var a: float = TAU * float(i) / 7.0
		canvas.draw_circle(c + Vector2(cos(a), sin(a)) * size * 0.30, size * 0.08, bronze)
	canvas.draw_circle(c, size * 0.24, bronze.darkened(0.12))
	canvas.draw_circle(c, size * 0.10, Color(0.16, 0.13, 0.08))


static func _coal(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.30, -0.10), Vector2(-0.06, -0.32), Vector2(0.30, -0.18),
		Vector2(0.34, 0.16), Vector2(0.02, 0.34), Vector2(-0.32, 0.16)], Color(0.20, 0.21, 0.25))
	_poly(canvas, c, size, [Vector2(-0.06, -0.32), Vector2(0.14, -0.06), Vector2(-0.10, 0.00)], Color(0.34, 0.36, 0.42))


static func _wood(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var bark := Color(0.52, 0.36, 0.20)
	canvas.draw_rect(Rect2(c - Vector2(size * 0.30, size * 0.16), Vector2(size * 0.60, size * 0.32)), bark)
	canvas.draw_circle(c + Vector2(size * 0.30, 0.0), size * 0.16, bark)
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.16, bark.lightened(0.10))
	canvas.draw_arc(c - Vector2(size * 0.30, 0.0), size * 0.10, 0.0, TAU, 12, bark.darkened(0.25), maxf(1.0, size * 0.03))
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.035, bark.darkened(0.30))


static func _sapling(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var stem := Color(0.48, 0.36, 0.22)
	var leaf := Color(0.44, 0.66, 0.30)
	canvas.draw_circle(c + Vector2(0.0, size * 0.24), size * 0.16, stem.darkened(0.25))
	canvas.draw_rect(Rect2(c + Vector2(-size * 0.03, -size * 0.10), Vector2(size * 0.06, size * 0.36)), stem)
	_poly(canvas, c, size, [Vector2(0.0, -0.08), Vector2(-0.26, -0.22), Vector2(-0.10, -0.34)], leaf)
	_poly(canvas, c, size, [Vector2(0.0, -0.14), Vector2(0.24, -0.30), Vector2(0.30, -0.12)], leaf.lightened(0.12))


## ROPE is a COIL, and a RING because nothing else here is one; wound (bars across the stroke) with the
## tail leaving tangentially at the coil's own width, which is what separates cord from a lens.
static func _rope(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var hemp: Color = COLORS[&"rope"]
	var r: float = size * 0.26
	var w: float = maxf(1.0, size * 0.15)
	canvas.draw_arc(c, r, 0.0, TAU, 28, hemp, w, true)
	for k: int in 6:
		var a: float = float(k) * TAU / 6.0 + 0.42
		var d := Vector2(cos(a), sin(a))
		canvas.draw_line(c + d * (r - w * 0.52), c + d * (r + w * 0.52), hemp.darkened(0.34), maxf(1.0, size * 0.035))
	canvas.draw_line(c + Vector2(0.18, 0.19) * size, c + Vector2(0.30, 0.42) * size, hemp.darkened(0.10), w)
	canvas.draw_line(c + Vector2(0.30, 0.42) * size, c + Vector2(0.40, 0.36) * size, hemp.darkened(0.22), maxf(1.0, size * 0.07))


## TORCH: a haft on the diagonal with a teardrop flame at its head (a disc at this size is a fleck).
static func _torch(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var flame: Color = COLORS[&"torch"]
	canvas.draw_line(c + Vector2(-0.26, 0.38) * size, c + Vector2(0.04, -0.04) * size, Color(0.46, 0.33, 0.20), maxf(1.0, size * 0.13))
	_poly(canvas, c, size, [Vector2(0.04, -0.04), Vector2(0.22, -0.18), Vector2(0.15, -0.44), Vector2(-0.05, -0.20)], flame)
	canvas.draw_circle(c + Vector2(0.09, -0.21) * size, size * 0.06, Color(1.0, 0.94, 0.70))


## CONDUIT: a short copper tube with its couplings, the channel dark because a carried tube carries no power.
static func _conduit(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var copper: Color = COLORS[&"conduit"]
	canvas.draw_rect(Rect2(c + Vector2(-0.12, -0.40) * size, Vector2(0.24, 0.80) * size), copper)
	canvas.draw_rect(Rect2(c + Vector2(-0.20, -0.40) * size, Vector2(0.40, 0.12) * size), copper.lightened(0.1))
	canvas.draw_rect(Rect2(c + Vector2(-0.20, 0.28) * size, Vector2(0.40, 0.12) * size), copper.lightened(0.1))
	canvas.draw_rect(Rect2(c + Vector2(-0.04, -0.34) * size, Vector2(0.08, 0.68) * size), Color(0.30, 0.26, 0.20, 0.7))


## The carried ground: stone keeps the cube and is the reference; clay is a clod, deepstone a shard,
## glimmer a block with a bright seam, so each separates by SHAPE at hotbar size.
static func _block(canvas: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var h: float = size * 0.40
	canvas.draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), col)
	canvas.draw_rect(Rect2(c - Vector2(h, h), Vector2(h * 2.0, h * 0.34)), col.lightened(0.24))
	canvas.draw_rect(Rect2(c + Vector2(-h, h * 0.62), Vector2(h * 2.0, h * 0.38)), col.darkened(0.34))
	for g: Vector2 in [Vector2(-0.42, 0.10), Vector2(0.22, -0.14), Vector2(0.06, 0.34)]:
		canvas.draw_rect(Rect2(c + g * size, Vector2(size * 0.10, size * 0.10)), col.darkened(0.22))


static func _seam(canvas: CanvasItem, c: Vector2, size: float, seam: Color) -> void:
	var h: float = size * 0.40
	canvas.draw_line(c + Vector2(-h, h * 0.20), c + Vector2(h, -h * 0.24), Color(seam, 0.85), maxf(1.0, size * 0.045))
	canvas.draw_line(c + Vector2(-h * 0.22, h * 0.64), c + Vector2(h * 0.44, h * 0.04), Color(seam, 0.48), maxf(1.0, size * 0.030))


static func _clod(canvas: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	_poly(canvas, c, size, [Vector2(-0.36, 0.04), Vector2(-0.24, -0.28), Vector2(0.10, -0.36),
		Vector2(0.34, -0.14), Vector2(0.32, 0.20), Vector2(0.02, 0.36), Vector2(-0.26, 0.28)], col)
	canvas.draw_circle(c + Vector2(-0.10, -0.16) * size, size * 0.070, col.lightened(0.22))
	for crumb: Vector2 in [Vector2(0.40, 0.30), Vector2(-0.42, 0.26)]:
		canvas.draw_circle(c + crumb * size, size * 0.045, col.darkened(0.18))


static func _shard(canvas: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	_poly(canvas, c, size, [Vector2(-0.12, -0.46), Vector2(0.20, -0.34), Vector2(0.30, 0.12),
		Vector2(0.10, 0.44), Vector2(-0.22, 0.34), Vector2(-0.30, -0.10)], col)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, -0.46) * size, c + Vector2(0.20, -0.34) * size,
		c + Vector2(0.04, 0.08) * size, c + Vector2(-0.16, -0.02) * size]), col.lightened(0.30))
