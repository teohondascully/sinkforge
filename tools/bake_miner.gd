extends SceneTree

## THE MINER, AUTHORED. Lifted from `legacy/tools/bake_miner.gd` (D0399, 2026-09-05) and extended: the dig
## is three beats (wind-up, mid-swing, struck -- the body drops a pixel on the blow), the idle breathes on
## two frames with the lamp core flickering a step, and the rope poses legacy authored are baked again
## for a build that has the rope. The palette, the base and every block legacy wrote are verbatim.
##
##   godot --headless --path . --script res://tools/bake_miner.gd
##   godot --headless --path . --import        # regenerates the .import sidecars so the game can load them
##
## Legacy's own header follows.
##
## What was here: one 32x48 PNG with 877 distinct colours in 1111 opaque pixels, very nearly a unique
## colour per pixel. That is a soft image at pixel-art size, not pixel art, and it loses twice over. It
## fights a world whose terrain, ore and machines are all code-drawn from a tight palette, and it wrecks
## the sticker rim: Player._draw builds that rim by stamping the sprite eight times behind itself, so a
## silhouette with soft alpha edges smears into a halo instead of cutting a crisp outline. Every other
## animation key fell back to that same still frame: walk, jump, climb, dig. So the body was a decal
## while the rope did all the moving.
##
## So the miner is authored the way everything else in this game is authored: from source, in a tool, with
## a palette you can read. Frames are ASCII over a named palette. That is not a gimmick: at 32x48 the art
## IS the data, and having it in the repo as text means a limb can be moved by editing a line, the whole
## set stays consistent because every frame shares one BASE, and a diff shows what changed.
##
## Four deliberate art decisions, each of them a fix for something blind playtesters flagged:
##
##   INTERIOR VALUE.  The old sprite was one mid-brown mass. Under the veil, at 32px, that reads as a blob.
##                    Every limb here is lit on its FRONT edge and shadowed on its back, so the figure has
##                    form before any lighting touches it, and the leading edge is what the eye finds first.
##   A COLOUR NOTHING ELSE WEARS. The world is warm, all dirt, brass, forge glow and amber UI, and the miner
##                    was warm too, which is why testers kept reading him as one of the machines. Lamp
##                    housing, goggles, a bandolier down the chest, the glove cuffs and the belt buckle are
##                    TEAL. Same reasoning that made the outer rim cool, carried inside the silhouette
##                    where the rim cannot go.
##   A SILHOUETTE WITH A TOOL IN IT. A bare torso-and-legs is a person; a person with a pick head over one
##                    shoulder is a MINER, and it reads before any interior detail does. The pick is its own
##                    layer stamped BEHIND the body, so the pack hides its haft the way a strap would, and
##                    it lifts off the back entirely on the two frames where it is in his hands.
##   POSES THE ROPE CAN USE. Grapple states now differ from each other, not just from standing: swinging
##                    streams the legs back, hauling folds the arm in, hanging drops them straight.
##
## Writes assets/sprites/miner_*.png plus a labelled contact sheet for eyeballing. It does NOT overwrite
## assets/sprites/miner.png; the hand-made original and its .aseprite stay exactly where they are, and
## the new idle lands as miner_idle.png until someone decides to promote it.
##
##   godot --headless --path . --script res://tools/bake_miner.gd
##   godot --headless --path . --import        # regenerates the .import sidecars so the game can load them

## The art lives in two data scripts beside this one (split at the file cap, D0399): the palette, the base,
## the slung gear and the frame table in `miner_body.gd`; the arm and leg blocks in `miner_limbs.gd`.
const MinerBody := preload("res://tools/miner_body.gd")
const MinerLimbs := preload("res://tools/miner_limbs.gd")
const PALETTE: Dictionary = MinerBody.PALETTE
const BASE: Array[String] = MinerBody.BASE
const GEAR: Dictionary = MinerBody.GEAR
const ARMS: Dictionary = MinerLimbs.ARMS
const LEGS: Dictionary = MinerLimbs.LEGS
const FRAMES: Array[Dictionary] = MinerBody.FRAMES

const OUT: String = "res://assets/sprites/"
const SHEET: String = "res://_miner_sheet.png"
const W: int = 32
const H: int = 48
const ZOOM: int = 8                  ## contact-sheet magnification
const COLS: int = 5                  ## contact-sheet columns


const LEG_TOP: int = 34
const ARM_TOP: int = 12


func _initialize() -> void:
	print("== baking the miner ==")
	var made: Array[Image] = []
	var names: Array[String] = []
	for f: Dictionary in FRAMES:
		var img: Image = _compose(str(f["gear"]), str(f["arms"]), str(f["legs"]), int(f["bob"]))
		if bool(f.get("flicker", false)):
			_flicker(img)
		var path: String = OUT + str(f["key"]) + ".png"
		var err: int = img.save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			printerr("  could not write %s (%d)" % [path, err])
		made.append(img)
		names.append(str(f["key"]))
		print("  %-16s %4d opaque px" % [f["key"], _opaque(img)])
	_audit(made)
	_contact_sheet(made)
	print("baked %d frames + a contact sheet at %s" % [made.size(), SHEET])
	quit(0)


## One frame: the slung tool first (so the body can cover it), then the shared base, then legs, then the
## near arm over everything.
func _compose(gear: String, arms: String, legs: String, bob: int) -> Image:
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if gear != "":
		_stamp(img, GEAR[gear] as Array, 0, bob)
	_stamp(img, BASE, 0, bob)
	_stamp(img, LEGS[legs] as Array, LEG_TOP, bob)
	_stamp(img, ARMS[arms] as Array, ARM_TOP, bob)
	return img


## The lamp core steps down to the glass colour: the one-pixel flicker the breathing idle carries.
func _flicker(img: Image) -> void:
	for y: int in H:
		for x: int in W:
			if img.get_pixel(x, y) == PALETTE["W"]:
				img.set_pixel(x, y, PALETTE["w"])


## Write one ASCII block into the image at a row offset. '.' means "leave whatever is already there",
## which is what lets an arm sit over a torso without carrying a copy of the torso around with it.
func _stamp(img: Image, rows: Array, top: int, bob: int) -> void:
	for r: int in rows.size():
		var y: int = top + r + bob
		var line: String = str(rows[r])
		if line.length() > W:
			printerr("  row %d of a %d-row block is %d chars — the tail is being dropped" % [r, rows.size(), line.length()])
		if y < 0 or y >= H:
			continue
		for x: int in mini(line.length(), W):
			var ch: String = line[x]
			if ch == ".":
				continue
			if not PALETTE.has(ch):
				printerr("  unknown palette char '%s' at row %d" % [ch, top + r])
				continue
			img.set_pixel(x, y, PALETTE[ch])


func _opaque(img: Image) -> int:
	var n: int = 0
	for y: int in H:
		for x: int in W:
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


## The two properties the rest of the pipeline actually depends on, asserted out loud rather than assumed:
## alpha must be strictly 0 or 255 (Player._draw's eight-stamp sticker rim smears into a halo otherwise),
## and the whole set must stay inside a palette small enough to read as one character.
func _audit(imgs: Array[Image]) -> void:
	var seen: Dictionary = {}
	var soft: int = 0
	for img: Image in imgs:
		for y: int in H:
			for x: int in W:
				var c: Color = img.get_pixel(x, y)
				var a: int = int(round(c.a * 255.0))
				if a != 0 and a != 255:
					soft += 1
				elif a == 255:
					seen[c.to_rgba32()] = true
	print("  audit: %d partial-alpha px (must be 0), %d distinct opaque colours across the set" % [soft, seen.size()])


## Every frame in a grid at ZOOM, on a mid grey that flatters neither the light nor the dark end, with a
## floor tick under each so a walk cycle can be read as a cycle rather than as a row of stills.
func _contact_sheet(imgs: Array[Image]) -> void:
	var pad: int = 6
	var cw: int = W * ZOOM + pad
	var chh: int = H * ZOOM + pad
	var rows: int = 1
	while rows * COLS < imgs.size():
		rows += 1
	var sheet: Image = Image.create(COLS * cw + pad, rows * chh + pad, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.28, 0.28, 0.32, 1.0))
	var col: int = 0
	var row: int = 0
	for i: int in imgs.size():
		var ox: int = col * cw + pad
		var oy: int = row * chh + pad
		var src: Image = imgs[i]
		for y: int in H:
			for x: int in W:
				var c: Color = src.get_pixel(x, y)
				if c.a <= 0.5:
					continue
				for zy: int in ZOOM:
					for zx: int in ZOOM:
						sheet.set_pixel(ox + x * ZOOM + zx, oy + y * ZOOM + zy, c)
		for x: int in (W * ZOOM):
			sheet.set_pixel(ox + x, oy + H * ZOOM, Color(0.12, 0.12, 0.15))
		col += 1
		if col >= COLS:
			col = 0
			row += 1
	sheet.save_png(ProjectSettings.globalize_path(SHEET))
