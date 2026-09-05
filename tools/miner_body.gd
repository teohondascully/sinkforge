extends RefCounted

## THE MINER'S BODY, AS DATA (split from `tools/bake_miner.gd` at the file cap, D0399): the palette, the
## shared base, the slung gear and the frame table. Legacy `legacy/tools/bake_miner.gd` verbatim, plus the
## breathing idle and the third dig beat. Read by the baker alone; nothing in the game loads this file.

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

## THE BASE: helmet, lamp, face, torso, pack and belt; everything that does not move. Authored facing
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

## GEAR: stamped BEFORE the base, so the body occludes it. That is the whole trick: the haft can run
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

## THE FRAME SET: logical sprite key -> (gear, arms, legs, vertical bob). Keys match Player._sprite_key()
## and its SPRITE_FALLBACKS chain exactly. `bob` shifts the WHOLE figure, which is why the pass frames get
## -1: the body lifts a pixel between footfalls and the shadow underneath does not follow it.
const FRAMES: Array[Dictionary] = [
	{"key": "miner_idle",    "gear": "pick", "arms": "rest",     "legs": "stand",    "bob": 0},
	{"key": "miner_idle_1",  "gear": "pick", "arms": "rest",     "legs": "stand",    "bob": -1, "flicker": true},
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
	{"key": "miner_dig_1",   "gear": "",     "arms": "dig_mid",  "legs": "stand",    "bob": 0},
	{"key": "miner_dig_2",   "gear": "",     "arms": "dig_down", "legs": "brace",    "bob": 1},
]
