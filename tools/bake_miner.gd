extends SceneTree

## THE MINER, AUTHORED.
##
## What was here: one 32x48 PNG with 877 distinct colours in 1111 opaque pixels — very nearly a unique
## colour per pixel. That is a soft image at pixel-art size, not pixel art, and it loses twice over. It
## fights a world whose terrain, ore and machines are all code-drawn from a tight palette, and it wrecks
## the sticker rim: Player._draw builds that rim by stamping the sprite eight times behind itself, so a
## silhouette with soft alpha edges smears into a halo instead of cutting a crisp outline. Every other
## animation key — walk, jump, climb, dig — fell back to that same still frame, so the body was a decal
## while the rope did all the moving.
##
## So the miner is authored the way everything else in this game is authored: from source, in a tool, with
## a palette you can read. Frames are ASCII over a named palette. That is not a gimmick — at 32x48 the art
## IS the data, and having it in the repo as text means a limb can be moved by editing a line, the whole
## set stays consistent because every frame shares one BASE, and a diff shows what changed.
##
## Four deliberate art decisions, each of them a fix for something blind playtesters flagged:
##
##   INTERIOR VALUE.  The old sprite was one mid-brown mass. Under the veil, at 32px, that reads as a blob.
##                    Every limb here is lit on its FRONT edge and shadowed on its back, so the figure has
##                    form before any lighting touches it, and the leading edge is what the eye finds first.
##   A COLOUR NOTHING ELSE WEARS. The world is warm — dirt, brass, forge glow, amber UI — and the miner
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
## assets/sprites/miner.png — the hand-made original and its .aseprite stay exactly where they are, and
## the new idle lands as miner_idle.png until someone decides to promote it.
##
##   godot --headless --path . --script res://tools/bake_miner.gd
##   godot --headless --path . --import        # regenerates the .import sidecars so the game can load them

const OUT: String = "res://assets/sprites/"
const SHEET: String = "res://_miner_sheet.png"
const W: int = 32
const H: int = 48
const ZOOM: int = 8                  ## contact-sheet magnification
const COLS: int = 5                  ## contact-sheet columns

## The whole miner, in nineteen colours. Three families and nothing else: warm leather, brass for the hat,
## cool steel for the tool, and teal for him alone.
const PALETTE: Dictionary = {
	"k": Color8(11, 10, 13),         # outline / darkest — the shape's own edge
	"d": Color8(36, 26, 22),         # deep leather shadow
	"b": Color8(61, 43, 32),         # leather mid — most of him
	"l": Color8(92, 66, 46),         # leather lit — the front edge of every limb
	"h": Color8(129, 95, 62),        # leather highlight — shoulders and the top of things
	"a": Color8(133, 88, 30),        # brass shadow
	"A": Color8(192, 139, 46),       # brass mid — the helmet
	"G": Color8(246, 205, 96),       # brass highlight
	"n": Color8(88, 97, 112),        # steel shadow — the pick, kept COOL so it is not more helmet
	"N": Color8(150, 163, 182),      # steel lit
	"c": Color8(18, 58, 68),         # teal shadow
	"C": Color8(46, 142, 160),       # teal mid — the accent nothing else in the world wears
	"E": Color8(118, 220, 235),      # teal bright — used sparingly, or it stops being an accent
	"w": Color8(255, 217, 138),      # lamp glass
	"W": Color8(255, 246, 214),      # lamp core
	"s": Color8(44, 44, 56),         # boots / gloves / belt — near-black but NOT the outline black
	"S": Color8(80, 82, 100),        # ...and their lit front edge, so a boot is not a hole
	"f": Color8(132, 102, 74),       # what little face shows
	"F": Color8(178, 142, 104),      # ...and its lit side, so the head is not a flat patch
}

## THE BASE: helmet, lamp, face, torso, pack and belt — everything that does not move. Authored facing
## LEFT, because Player._draw flips for a body facing right. Rows are y, characters are x; a row may stop
## early and the rest is treated as transparent, which keeps the leading-dot count the only thing to get
## right. Rows 0-33; the legs take over at 34.
const BASE: Array[String] = [
	"",
	"",
	"...........kkkkkkkk",
	"..........kAAAAAAAAk",
	".........kGGAAAAAAAAk",
	".........kGAAAAAAAAAk",
	"...kkkkkkAAAAAAAAAAAAk",
	"...kWwECkAAAAAAAAAAAAk",
	"...kWwECkAAAAAAAAAAAAk",
	"...kccCCkAAAAAAAAaaaak",
	"....kkkkkAAAAAAAAAAAAkk",
	"....kGGGGAAAAAAAAAAAAak",
	"....kkkkkkkkkkkkkkkkkkk",
	".........kddddddddddk",
	".........kdCEECsssssk",
	".........kdcCCcsssssk",
	".........kFffffddssdk",
	"..........kFfffddddk",
	"..........kkkkkkkkkk",
	"........khhhllbbbbddk",
	".......khhlECbbbbbdddkkkkkkk",
	".......kllbECbbbbbdddkhhbbbk",
	".......klbbbCcbbbbdddkbbbddk",
	".......klbbbCcbbbbdddkkkkkkk",
	".......klbbbbCcbbbdddkdAAddk",
	".......klbbbbCcbbbdddkdddddk",
	".......klbbbbbCcbbdddkdddddk",
	".......klbbbbbCcbbdddkdddddk",
	".......klbbbbbbCcbdddkdddddk",
	".......kssssssssssssskddddk",
	".......ksECsssssssssskkkkkk",
	"......klbbbbbbbbbbdddk",
	"......klbbbbbbbbbbdddk",
	"......kddddddddddddddk",
]

## GEAR: stamped BEFORE the base, so the body occludes it. That is the whole trick — the haft can run
## straight into the pack and simply stop being drawn, which is what a strapped-on tool looks like.
## Rows are absolute y, same as BASE.
const GEAR: Dictionary = {
	# A pick head is a BAR, not a hook: straight edges, a squared adze at the back and a taper to a point
	# at the front, sitting square on a straight haft. Curve any part of it and the whole thing stops
	# reading as a tool and starts reading as a tail.
	"pick": [
		"", "", "", "", "", "", "", "",
		"..........................kkkkkk",
		"........................kkNNNNNk",
		".......................kNNnnnnNk",
		".......................kknnnnkkk",
		"..........................knnk",
		"..........................khbk",
		"..........................khbk",
		".........................khbk",
		".........................khbk",
		".........................khbk",
		"........................khbk",
		"........................khbk",
	],
}

## ARMS: rows start at y=12 (ARM_TOP) so a raised arm can reach face height, and a block may run as long
## as it likes — dig_down's pick keeps going down past the hips. Stamped LAST, over everything, because
## the near arm is the nearest thing to the camera. Only non-'.' cells are written, so the torso shows
## through everywhere an arm is not.
const ARMS: Dictionary = {
	# At rest, hanging down the front of the coat. Every arm carries 'h' on its leading edge — a full step
	# lighter than the torso it hangs over, which is the only thing that stops it disappearing into the coat.
	"rest": [
		"", "", "", "", "", "", "",
		".......khhk",
		"......khlbk",
		"......khlbk",
		"......khlbk",
		"......khlbk",
		"......klbdk",
		"......klbdk",
		"......klbdk",
		"......klbdk",
		"......kCCCk",
		"......kSssk",
		"......kSssk",
		".......kkk",
	],
	# Swung forward, ahead of the body.
	"fore": [
		"", "", "", "", "", "", "",
		".......khhk",
		"......khlbk",
		".....khlbk",
		".....khlbk",
		"....klbdk",
		"....klbdk",
		"...klbdk",
		"...kCCCk",
		"...kSssk",
		"...kSssk",
		"....kkk",
	],
	# Swung back, across the chest.
	"back": [
		"", "", "", "", "", "", "",
		".......khhk",
		".......khlbk",
		"........khlbk",
		"........khlbk",
		".........klbdk",
		".........klbdk",
		"..........klbdk",
		"..........kCCCk",
		"..........kSssk",
		"..........kSssk",
		"...........kkk",
	],
	# Up and forward — reaching for a line that is above and ahead of him.
	"reach": [
		"", "",
		"..kSssk",
		"..kSssk",
		"..kCCCk",
		"...khbk",
		"....khbk",
		".....klbk",
		"......khhk",
	],
	# Straight up — a fist closed on a rope directly overhead.
	"grip": [
		"",
		".....kSsk",
		".....kSsk",
		".....kCCk",
		".....khbk",
		".....khbk",
		".....klbk",
		".....klbk",
		"......khhk",
	],
	# Folded in hard, fist up at the chin: the frame right after a pull, which is what reeling looks like.
	"haul": [
		"", "", "",
		"....kSssk",
		"....kSssk",
		"....kCCCk",
		"...khbk",
		"...khbk",
		"....klbk",
		".....klbk",
		"......khhk",
	],
	# Pick cocked up and forward, both hands on the haft.
	"dig_up": [
		"",
		".kkkkkk",
		"kNNnnnnk",
		"kNnnnnnk",
		".kknnnkk",
		"...khbbk",
		"...kSssk",
		"...kCCCk",
		"....klbk",
		".....khhk",
	],
	# ...and driven down through the swing, head buried below the knee.
	"dig_down": [
		"", "", "", "", "", "", "",
		"......khhk",
		".....klbk",
		"....klbk",
		"....kCCk",
		"...kSssk",
		"...kSssk",
		"...khbbk",
		"..khbbk",
		"..khbbk",
		".khbbk",
		".khbbk",
		".khbbk",
		".kkkkkk",
		"kNNnnnnk",
		"kNnnnnnk",
		".kknnnkk",
	],
}

## LEGS: rows start at y=34 (LEG_TOP). The near leg carries the lit edge 'l' on its front, the far leg
## carries 'd' on its back, so even when the two overlap you can tell which is which. Every grounded pose
## puts a sole on row 47 — the bottom of the sprite, which is the bottom of the collider.
const LEGS: Dictionary = {
	"stand": [
		".........kbbbbkbbddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		".........kdbbbkbdddk",
		".........kdbbbkbdddk",
		".........kSssskSsssk",
		".........kSssskSsssk",
		"........kSsssskSsssk",
		".......kSssssskSsssk",
		".......kSssssskSsssk",
		".......kkkkkkkkkkkkk",
	],
	# Contact pose A: near leg planted forward, far leg planted back. Both soles down.
	"stride_a": [
		".........kbbbbkbbddk",
		"........klbbbkkbbddk",
		"........klbbbk.kbbddk",
		".......klbbbk..kbbddk",
		".......klbbbk...kbdddk",
		"......klbbbk....kbdddk",
		"......kdbbbk....kbdddk",
		".....kdbbbk.....kbdddk",
		".....kSsssk.....kSsssk",
		".....kSsssk.....kSsssk",
		"....kSssssk....kSssssk",
		"...kSsssssk....kSssssk",
		"...kSsssssk....kSssssk",
		"...kkkkkkkk....kkkkkkk",
	],
	# Contact pose B: the same stride with the roles swapped — far leg leads, so the lit edge moves.
	"stride_b": [
		".........kbbbbkbbddk",
		"........kdbbbkklbbbk",
		"........kdbbbk.klbbbk",
		".......kdbbbk..klbbbk",
		".......kdbbbk...klbbbk",
		"......kdbbbk....klbbbk",
		"......kdbbbk....klbbbk",
		".....kdbbbk.....klbbbk",
		".....kSsssk.....kSsssk",
		".....kSsssk.....kSsssk",
		"....kSssssk....kSssssk",
		"...kSsssssk....kSssssk",
		"...kSsssssk....kSssssk",
		"...kkkkkkkk....kkkkkkk",
	],
	# Pass A: near leg swinging through, lifted clear of the floor; far leg holds the weight.
	"pass_a": [
		".........kbbbbkbbddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		"........klbbbkkbdddk",
		"........klbbbkkbdddk",
		".......kdbbbk.kbdddk",
		".......kdbbbk.kbdddk",
		".......kSsssk.kbdddk",
		".......kSsssk.kSsssk",
		"......kSssssk.kSsssk",
		"......kkkkkkk.kSsssk",
		"..............kSsssk",
		"..............kSsssk",
		"..............kkkkkk",
	],
	# Pass B: the mirror — far leg swings through behind him, near leg holds the weight. Having two
	# different pass frames is what stops walk_1 and walk_3 from being the same picture twice.
	"pass_b": [
		".........kbbbbkbbddk",
		".........klbbbkbdddk",
		".........klbbbkbdddk",
		".........klbbbkkbdddk",
		".........klbbbkkbdddk",
		".........klbbbk.kbdddk",
		".........klbbbk.kbdddk",
		".........klbbbk.kbdddk",
		".........kSsssk.kSsssk",
		"........kSssssk.kSsssk",
		".......kSsssssk.kSsssk",
		".......kSsssssk.kkkkkk",
		".......kSsssssk",
		".......kkkkkkkk",
	],
	# Tucked: knees up and forward. Rising.
	"tuck": [
		".........kbbbbkbbddk",
		"........klbbbkkbbddk",
		".......klbbbk.kbbddk",
		"......klbbbk..kbbddk",
		".....kdbbbk...kbdddk",
		".....kSsssk...kbdddk",
		"....kSsssk....kbdddk",
		"....kkkkkk....kSsssk",
		"..............kSsssk",
		".............kSssssk",
		".............kkkkkkk",
	],
	# Braced wide and bent, absorbing a landing.
	"brace": [
		".........kbbbbkbbddk",
		"........klbbbkkbbddk",
		".......klbbbk..kbbddk",
		"......klbbbk...kbbddk",
		".....kdbbbk....kbbddk",
		"....kdbbbk......kbdddk",
		"...kdbbbk.......kbdddk",
		"...kSsssk.......kbdddk",
		"..kSsssk........kSsssk",
		"..kSsssk........kSsssk",
		".kSssssk........kSssssk",
		".kSssssk........kSssssk",
		".kSssssk........kSssssk",
		".kkkkkkk........kkkkkkk",
	],
	# Streaming back: nothing under him, everything trailing. Falling, or swung out on a taut line.
	"trail": [
		".........kbbbbkbbddk",
		".........klbbbkbdddk",
		"..........klbbbkbdddk",
		"..........klbbbkbdddk",
		"...........klbbbkbdddk",
		"...........klbbbkbdddk",
		"............klbbbkbdddk",
		"............klbbbkbdddk",
		"............kSssskSsssk",
		"............kSssskSsssk",
		"...........kSsssskSsssk",
		"...........kSsssskSsssk",
		"...........kkkkkkkkkkkk",
	],
	# Straight down and closed up — dead weight on a line.
	"hang": [
		".........kbbbbkbbddk",
		"..........klbbkbddk",
		"..........klbbkbddk",
		"..........klbbkbddk",
		"..........klbbkbddk",
		"..........kdbbkbddk",
		"..........kdbbkbddk",
		"..........kdbbkbddk",
		"..........kSsskSssk",
		"..........kSsskSssk",
		".........kSssskSssk",
		".........kSssskSssk",
		".........kkkkkkkkkk",
	],
	# One knee driven up, the other hanging: the shape of going UP a rope rather than dangling on it.
	"climb": [
		".........kbbbbkbbddk",
		"........klbbbkkbdddk",
		".......klbbbk.kbdddk",
		"......klbbbk..kbdddk",
		"......kSsssk..kbdddk",
		"......kSsssk..kbdddk",
		"......kkkkkk..kbdddk",
		"..............kbdddk",
		"..............kSsssk",
		"..............kSsssk",
		".............kSssssk",
		".............kSssssk",
		".............kkkkkkk",
	],
}

## THE FRAME SET: logical sprite key -> (gear, arms, legs, vertical bob). Keys match Player._sprite_key()
## and its SPRITE_FALLBACKS chain exactly. `bob` shifts the WHOLE figure, which is why the pass frames get
## -1: the body lifts a pixel between footfalls and the shadow underneath does not follow it.
const FRAMES: Array[Dictionary] = [
	{"key": "miner_idle",    "gear": "pick", "arms": "rest",     "legs": "stand",    "bob": 0},
	{"key": "miner_walk_0",  "gear": "pick", "arms": "fore",     "legs": "stride_a", "bob": 0},
	{"key": "miner_walk_1",  "gear": "pick", "arms": "rest",     "legs": "pass_a",   "bob": -1},
	{"key": "miner_walk_2",  "gear": "pick", "arms": "back",     "legs": "stride_b", "bob": 0},
	{"key": "miner_walk_3",  "gear": "pick", "arms": "rest",     "legs": "pass_b",   "bob": -1},
	{"key": "miner_jump",    "gear": "pick", "arms": "reach",    "legs": "tuck",     "bob": 0},
	{"key": "miner_fall",    "gear": "pick", "arms": "back",     "legs": "trail",    "bob": 0},
	{"key": "miner_land",    "gear": "pick", "arms": "fore",     "legs": "brace",    "bob": 0},
	{"key": "miner_climb_0", "gear": "pick", "arms": "grip",     "legs": "climb",    "bob": 0},
	{"key": "miner_climb_1", "gear": "pick", "arms": "haul",     "legs": "hang",     "bob": -1},
	{"key": "miner_hang",    "gear": "pick", "arms": "grip",     "legs": "hang",     "bob": 0},
	{"key": "miner_swing",   "gear": "pick", "arms": "reach",    "legs": "trail",    "bob": 0},
	{"key": "miner_haul",    "gear": "pick", "arms": "haul",     "legs": "climb",    "bob": 0},
	{"key": "miner_dig_0",   "gear": "",     "arms": "dig_up",   "legs": "stand",    "bob": -1},
	{"key": "miner_dig_1",   "gear": "",     "arms": "dig_down", "legs": "stand",    "bob": 0},
]

const LEG_TOP: int = 34
const ARM_TOP: int = 12


func _initialize() -> void:
	print("== baking the miner ==")
	var made: Array[Image] = []
	var names: Array[String] = []
	for f: Dictionary in FRAMES:
		var img: Image = _compose(str(f["gear"]), str(f["arms"]), str(f["legs"]), int(f["bob"]))
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
