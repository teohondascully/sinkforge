class_name LayeredWorldGen
extends HeightmapWorldGen

## The RICHER generator. Builds on HeightmapWorldGen's surface + earth/stone fill,
## then layers in the two things that most change how EXPLORING feels:
##   1. CAVES — organic carved pockets (open block, wall KEPT → Terraria carved room, not void) whose
##      openness GROWS with depth. The near-surface base stays solid by construction (caves only below
##      CAVE_MIN_DEPTH), so danger stays located/opt-in — you dig DOWN to find the open dark.
##   2. DEPTH-BANDED ORE — veins (grown blobs, not single specks) that get MORE FREQUENT and BIGGER
##      the deeper you go: the core pull (deeper = richer). Replaces the old uniform scatter.
##
## Emits only existing material ids (&"earth"/&"stone"/&"ore" + their walls) → the renderer needs ZERO
## change; this is the seam working. Deterministic in (cols, rows, seed): one seeded RNG for veins, a
## seeded FastNoiseLite for caves. Improve generation here without sim or viz knowing.

## HOW MANY OF A THING A WORLD GETS. Every "N per column" density below was tuned against the 80-row
## world it was written in, and a count derived from WIDTH alone silently HALVES in density the moment
## the world gets deeper — which is exactly how a bigger world becomes an emptier one. The features that
## are per-CELL rolls (the cave noise, spires, rubble) scale with area for free; these counted ones did
## not, so they are scaled against the reference the numbers actually mean.
const DENSITY_ROWS: int = 80         ## the world height every *_PER_COL figure below was tuned against


func _density_count(world: WorldData, per_col: float) -> int:
	return int(round(float(world.cols) * per_col * float(world.rows) / float(DENSITY_ROWS)))


# --- caves ---
## Caves never breach this many tiles below a column's surface (keeps the spawn base safe/solid).
const CAVE_MIN_DEPTH: int = 6
## Noise scale — smaller = larger, smoother pockets. ~0.10 gives room-sized caverns.
const CAVE_FREQ: float = 0.11
## Carve where noise exceeds this. EASES toward CAVE_THRESHOLD_DEEP with depth → more open down low.
## RAISED (#107, dig-your-factory identity): the old 0.40/0.12 opened ~31% of the underground into air —
## structurally "follow-the-cave." These higher thresholds keep the underground SOLID by construction
## (~15% cave), so you CARVE your factory INTO ore-rich rock and caves are the rarer opt-in punctuation
## (the located-danger pockets), not the medium you traverse. See PROGRESSION §10 / DESIGN_REVIEW F2.
const CAVE_THRESHOLD_TOP: float = 0.47
const CAVE_THRESHOLD_DEEP: float = 0.31
## ANISOTROPY (shelves + overhangs, #93): the cave noise is sampled with the X axis COMPRESSED by this
## factor, so a noise feature spans more columns than rows → caverns come out WIDE-AND-FLAT (ledges,
## overhanging ceilings) instead of round blobs. >1 = stretched horizontally. See _carve_caves.
const CAVE_XSTRETCH: float = 2.1
## OVERHANG bias: the carve threshold is nudged this much EASIER just under a strata shelf and HARDER
## just above one, so cave roofs hang from the hard bands and floors rest on them (asymmetric = overhangs).
const CAVE_SHELF_BIAS: float = 0.10

# --- strata (horizontal rock banding, #93) ---
## Rock is organised into stacked BANDS this many rows tall. Every few bands is a HARD SHELF (shale) that
## resists caving and reads as a distinct layer, so descending crosses visible strata (not uniform blob rock).
const STRATA_BAND_H: int = 4
## 1-in-N bands is a hard shelf. Deterministic per band index (a seeded hash), so the layering is stable.
const STRATA_SHELF_EVERY: int = 3
## A hard shelf band adds this to the local carve threshold (harder to open) → the shelf survives as a
## continuous ledge/bridge across most of the width, only breached where noise is strongest.
const STRATA_SHELF_RESIST: float = 0.34
## Below this ABSOLUTE row the strata banding stops (deepslate/seal/Stonereach own the deep look already).
const STRATA_MAX_ROW: int = DEEPSLATE_ROW

# --- big caverns (a few large cohesive chambers, #93) ---
## Count of large seeded chambers ≈ this × columns (a handful across the width). Each is a wide flat-floored
## ellipse deep in the rock, the "rooms" the tunnel worms then thread together.
## LOWERED (#107): fewer big chambers so they read as rare landmark HALLS (punctuation), not the norm.
const CAVERN_PER_COL: float = 0.035
## Chamber half-extents (cells). Wide + shallow → a roomy hall with a flat floor + overhanging roof, not a ball.
const CAVERN_RX_MIN: int = 6
const CAVERN_RX_MAX: int = 9
const CAVERN_RY_MIN: int = 3
const CAVERN_RY_MAX: int = 5

# --- tunnels (winding caverns that connect the noise pockets into an explorable system) ---
## Worm count ≈ this × columns — a handful of long tunnels threading the rock. Trimmed (#107): enough to
## connect the pockets into an explorable system, not so many the rock reads as a tunnel maze.
const TUNNEL_PER_COL: float = 0.07
const TUNNEL_MIN_LEN: int = 18
const TUNNEL_MAX_LEN: int = 46
## Carve radius around the worm path (1 → ~3-wide walkable caverns).
const TUNNEL_RADIUS: int = 1

## --- VERTICAL STRUCTURE (#S5) -------------------------------------------------------------------------
## Everything above this line carves HORIZONTALLY. Noise pockets are round, big caverns are wide ellipses
## with flat floors, and tunnel worms are explicitly biased flat. That is a coherent set of choices for a
## game you walk through, and it produced an underground with no vertical dimension at all: at full
## zoom-out the whole world reads as one grey mass with a few dark lens shapes floating in it, and every
## screen looks like every other screen. It is also, bluntly, why the game reads as flat — the terrain
## genuinely is.
##
## A RIFT is the opposite carve: a narrow chasm that falls THROUGH the layer stack, wandering a little as
## it goes, slicing whatever it meets. It does three jobs at once. It is a landmark (you recognise a rift
## and you remember where it was). It is a shortcut down and a problem coming up, which is exactly the
## tension the grapple was built to resolve. And it puts a hard vertical edge into a world made entirely
## of soft horizontal ones, so the eye finally has something to hang scale on.
## Budgeted against the DIG-YOUR-FACTORY guard in tests/test_worldgen.gd, which holds open space under a
## quarter of everything below the surface: this world is solid ore-rich rock you carve INTO, and caves
## are punctuation rather than the medium you travel through. The first cut of these numbers pushed it to
## 26.5% and tripped it, correctly. Narrow and long is the better shape anyway — a chasm that pinches to
## two cells and opens to five is far more dramatic than a uniform six-wide slot, and costs less.
## Re-cut for the 128-row world: RARER and LONGER for the same open-space budget. A rift's whole job is
## to fall THROUGH the layer stack, and 26 rows stopped being that when the stack got sixty rows taller —
## it became a pothole. Four long chasms beat six medium ones at the same cost in carved air.
const RIFT_PER_COL: float = 0.018        ## ~4 rifts on this world — landmarks, not a feature grid
const RIFT_MIN_LEN: int = 34             ## rows; short of this it reads as a hole rather than a chasm
const RIFT_MAX_LEN: int = 80
const RIFT_HALF_W_MIN: float = 0.8       ## half-width in cells at the narrowest — a squeeze
const RIFT_HALF_W_MAX: float = 2.1       ## ...and at the widest — a rift PINCHES and OPENS as it falls
const RIFT_WANDER: float = 0.34          ## cells of horizontal drift per row (kept low: a rift is a fall line)
## A rift has to be worth WALKING TO, or it is scenery. Real fissures are where hydrothermal veins form —
## mineral-rich fluid rises through the fracture and deposits in its walls — so the geology and the game
## design want the same thing: the chasm pays. Ore already in a rift wall upgrades to RICH ore; plain rock
## in a rift wall sometimes becomes ore outright. Rifts are also kept clear of the spawn window, which is
## the same rule the frontier pull follows: the good stuff is somewhere you travel to.
const RIFT_SPAWN_KEEPOUT: int = 10       ## columns either side of spawn no rift may start in
const RIFT_WALL_ORE_CHANCE: float = 0.11 ## plain rock in a rift wall that becomes ore
const RIFT_WALL_RICH_CHANCE: float = 0.55## ore already in a rift wall that upgrades to rich ore

## A cavern with smooth walls is a bubble, and a bubble is not a place. LEDGES jut back into open space
## from its sides so there is somewhere to land, somewhere to stand a machine, and something for the eye
## to measure the room against. They are placed on the OPEN side of a solid wall, so they read as rock
## that resisted rather than as debris that floats.
const LEDGE_PER_COL: float = 0.22
const LEDGE_LEN_MIN: int = 2
const LEDGE_LEN_MAX: int = 4
const LEDGE_HEADROOM: int = 2            ## cells of clear air a shelf needs above it, or it is just fill

## SPIRES: stalactites down from ceilings, stalagmites up from floors. One cell wide, tapering to nothing.
## Cheaper than any other cue on this list and worth more than most — nothing else says "you are inside
## rock" so immediately, and a 4-cell spire gives a 40-cell view a sense of scale it cannot get from flat
## surfaces. Kept sparse; a forest of them reads as decoration rather than as geology.
## Ceilings and floors get different teeth, for the same reason real caves do and for one better one:
## a five-cell stalagmite in a tunnel is not decoration, it is a wall, and the play-tests caught exactly
## that — two scripted rungs started failing because the route down had grown floor spikes taller than the
## body could step over. Stalactites hang long from ceilings where nothing walks; stalagmites stay stubby.
const SPIRE_CHANCE: float = 0.075        ## per eligible ceiling cell
const SPIRE_FLOOR_BIAS: float = 0.34     ## × that chance for a floor cell — teeth belong on the roof
const SPIRE_HANG_MIN: int = 2            ## stalactite, growing DOWN from a ceiling
const SPIRE_HANG_MAX: int = 5
const SPIRE_RISE_MIN: int = 1            ## stalagmite, growing UP from a floor — steppable by construction
const SPIRE_RISE_MAX: int = 2

## RUBBLE: single loose blocks resting on cave floors. The detail that makes a floor read as a floor that
## things have fallen onto, rather than as the bottom edge of a shape.
const RUBBLE_CHANCE: float = 0.060

# --- ore ---
## Vein-seed attempts ≈ this × columns. Each is accepted by a depth-weighted roll, so most surviving
## veins land deep — the band. Nudged up (#107): with the rock now solid-dominant (fewer caves), more
## veins land in solid rock, so carving into the mass frequently reveals a vein (the dig-your-factory
## pull) — but kept MODEST so ore stays a reward for carving, not wallpaper (~20% of solid, not a quarter).
const ORE_ATTEMPTS_PER_COL: float = 1.0
## A vein seed at the very bottom is accepted this often; at the surface, ~0. Linear in depth.
const ORE_CHANCE_DEEP: float = 0.85

## ...except that a ramp starting at ZERO does not mean "the shallow rock is poorer", it means "the shallow
## rock is EMPTY", and the shallow rock is the entire first session. Measured by tools/check_richness before
## this floor existed: TOPSOIL ran 1.2 encounters per hundred rows — a new player's whole world, and
## essentially nothing in it. So the ramp now runs from a FLOOR to full instead of from nothing to full.
## Deep acceptance is untouched (at depth_frac 1 the floor drops out of the expression entirely), so the
## core pull — deeper is richer — survives exactly as designed; what changes is that "poorer" stops meaning
## "barren". Coal floors higher than ore: it is the drill's fuel and the tutorial asks for it early.
const ORE_SHALLOW_FLOOR: float = 0.34
const COAL_SHALLOW_FLOOR: float = 0.42
## Vein BODY size (cells in the accretion blob) grows from this (shallow) toward +BONUS (deep) — deeper =
## fatter bodies you can array more drills across. Big enough to be a real patch, not a fleck.
const ORE_SIZE_MIN: int = 8
const ORE_SIZE_DEPTH_BONUS: int = 44
## COAL veins — the drill's FUEL. Mined the same cavity way as ore; a touch more common
## and a bit shallower-reaching than ore (you need a steady coal supply once you automate), still depth-banded.
const COAL_ATTEMPTS_PER_COL: float = 0.8
const COAL_CHANCE_DEEP: float = 0.95
const COAL_SIZE_MIN: int = 6
const COAL_SIZE_DEPTH_BONUS: int = 30
const COAL_AMOUNT_BASE: int = 30         # modest PER-CELL (the drill bores cell by cell); big BODIES give the
const COAL_AMOUNT_DEPTH_BONUS: int = 170 # long-lasting TOTAL (hundreds shallow → thousands deep per body)
## Per-CELL ore deposit. MODEST now (the boring Drill drains a cell then sinks to the next,
## so a huge per-cell number would pin the drill on one cell forever); the LONG-LASTING supply comes from the
## fat multi-cell BODY (ORE_SIZE_*): body total = cells × per-cell ≈ hundreds shallow → thousands deep, the
## Factorio patch that feeds a drill ARRAY for a long time (deeper = richer = the automation pull). Same
## depth_frac as body size/chance.
const ORE_AMOUNT_BASE: int = 30
const ORE_AMOUNT_DEPTH_BONUS: int = 170
## ORE QUALITY (#48): vein seeds landing in/below the deepslate band roll this often into RICH ORE
## (the high-grade variant — Blast Furnace smelts 1 → 2 ingots), carrying more per-cell deposit too.
const RICH_CHANCE: float = 0.45
const RICH_AMOUNT_MULT: float = 1.5

# --- HORIZONTAL richness (the FRONTIER pull) ---
## The bug this fixes: ore used to scale with DEPTH ONLY, so at a fixed depth every column was
## statistically identical and the cheapest fresh vein was always straight DOWN — "you must leave
## spawn" was never true. This term makes richness vary across X at a fixed depth so richer FRONTIER
## zones fan out AWAY from spawn, pulling the extraction frontier outward-and-down instead of straight down.
##
## The field is a deterministic multiplier centred on 1.0, per column, combining two seeded pieces:
##   (a) a smooth low-frequency FastNoiseLite band (organic pockets of rich/lean rock across the width), and
##   (b) a gentle distance-from-spawn ramp (the RICHEST bands live away from the spawn plateau).
## It multiplies into the vein ACCEPTANCE chance, blob SIZE, and per-cell RICHNESS — so a rich x-band is
## more likely to spawn a vein, and that vein is fatter and denser. SUBTLE by construction: the multiplier
## is clamped to [1 - HORIZONTAL_STRENGTH, 1 + HORIZONTAL_STRENGTH], so near-spawn ore is thinned, never
## nuked, and the deep core pull is untouched (it stacks multiplicatively on the depth term).
##
## TUNE via HORIZONTAL_STRENGTH: 0.0 = the old depth-only world (no horizontal variation); higher = a
## sharper contrast between lean and rich x-bands (0.55 = the frontier is meaningfully richer, spawn still
## productive). HORIZONTAL_FREQ sets how WIDE the bands are (smaller = broader zones you commit to walking to);
## FRONTIER_BIAS sets how much the field tilts toward distance-from-spawn vs pure noise (1.0 = all distance,
## 0.0 = all noise). The field is seeded off the world seed (+ an offset so it doesn't correlate with caves).
const HORIZONTAL_STRENGTH: float = 0.55
const HORIZONTAL_FREQ: float = 0.045
const FRONTIER_BIAS: float = 0.5
## The spawn column the distance-ramp measures from (centre of the flat plateau) — near here the ramp
## contributes ~0; the map edges contribute ~+1 (the richest frontier).
const SPAWN_COL: int = (FLAT_START + FLAT_END) / 2


## Earth → stone happens in the heightmap base; below this ABSOLUTE row a third band turns to deepslate,
## so descending crosses distinct material zones (the "deeper = different place" read).
const DEEPSLATE_ROW: int = 76

## THE SEAL — the L1→L2 gate (docs/PROGRESSION.md §2/§9): an UNBROKEN band of unmineable sealrock across
## the world's full width, stamped LAST so no cave/tunnel/vein can hole it. It sits a few rows INTO the
## deepslate zone, leaving a mineable deepslate SHELF above it (rows DEEPSLATE_ROW..SEAL_TOP-1, the
## stone-pick tier gate) — the shelf is where you sample deepslate for the Descent research. Below the
## seal is STONEREACH (L2): richer veins + IRON, reachable only by feeding a Descent Engine its
## throughput quota (the wall that makes the factory mandatory — no pick opens it).
const SEAL_TOP: int = 84
const SEAL_ROWS: int = 2

## IRON — L2's signature material (the analyze-sample for the next tech tier), seeded ONLY below the
## seal. Rich fat bodies (it's the reward), same accretion machinery as ore/coal.
const IRON_ATTEMPTS_PER_COL: float = 0.5
const IRON_SIZE_MIN: int = 10
const IRON_SIZE_DEPTH_BONUS: int = 30
const IRON_AMOUNT: int = 220

# --- LODES: ore born in the WALL, which is where the extraction machines have always been looking ---
## Terrain is what you CARVE, the lode is what you EXTRACT (`docs/LODE.md`). Every pass above stamps ore
## as a SOLID BLOCK — the thing you destroy to get at. These bodies go into the background plane behind
## rock that stays solid, so the vein is something you UNCOVER and then keep working, and the Head, the
## Spur, the Borer and the Drift Rig finally have something generated to draw from.
##
## THIS IS ADDITIVE, DELIBERATELY. The full cutover converts the ore blocks themselves and deletes the
## solid-ore path in one commit (`docs/LODE_PLAN.md` phase 3); that also rewrites the tutorial ladder and
## every ore fixture, and it is not what this is. Nothing above is touched, so the existing economy, every
## richness assertion and every fixture keep their current meaning — and "a generated world contains
## usable extraction sites" stops being false by construction, which was the blocking half.
##
## No new render work: `WorldRenderer` already stains a buried lode through rock (LODE §10, phase 4) and
## already draws an exposed one, both keyed off `sim.lode` without asking whether the cell is solid. So
## these are visible as a tell the moment they exist, and prospecting starts meaning something.
const LODE_ATTEMPTS_PER_COL: float = 0.35
const LODE_SIZE_MIN: int = 6
const LODE_SIZE_DEPTH_BONUS: int = 12
const LODE_AMOUNT_BASE: int = 40
const LODE_AMOUNT_DEPTH_BONUS: int = 170
## A lode never sits in the near-surface shell. Same reasoning as CAVE_MIN_DEPTH: the spawn base has to
## stay legible rock, and a vein you can reach by scuffing the topsoil is not an extraction SITE — the
## whole point is that reaching it is a trip. Measured off the column's generated ground, so it follows
## the relief instead of cutting a flat line through the hills.
const LODE_MIN_DEPTH: int = 14

# --- aquifers (L3 water pockets you BREACH) ---
## Sealed pressurised water pockets carved deep into SOLID rock (block erased, wall KEPT — a flooded carved
## room), filled to WATER_MAX so digging in RELEASES them. DEEP + BASE-SAFE by construction: a pocket never
## rises within CAVE_MIN_DEPTH of a column's surface (base stays dry) and its centre lives at/below
## AQUIFER_MIN_ROW — the deep deepslate approach and the Stonereach band below the seal (rows ~54..bottom),
## the "watery deep" of the depth spine. Carved ENTIRELY within solid rock (not connected to the cave/tunnel
## system) so each reads as pressurised, not a drained cavern. Stamped LAST (after the seal) so nothing
## re-carves or overwrites the water; a blob cell that would land in the seal band or any non-solid cell is skipped.
const AQUIFER_PER_COL: float = 0.045       # pocket count ≈ this × cols (a handful, like the big caverns)
const AQUIFER_MIN_ROW: int = DEEPSLATE_ROW + 2   # centres live in/below the deep deepslate + Stonereach band
const AQUIFER_RX_MIN: int = 2
const AQUIFER_RX_MAX: int = 4
const AQUIFER_RY_MIN: int = 2
const AQUIFER_RY_MAX: int = 3

# --- aquifer TREASURE (L3 risk/REWARD): the flood GUARDS a rich vein ---
## The flooded pocket is pure hazard on its own (you wade it, you pump it). This makes it worth
## breaching: a modest &"rich_ore" vein grows in the SOLID rock lining each pocket's walls/floor, so a
## player who breaches the flood, pumps it dry, and mines the drained walls is paid in high-grade ore —
## risk (flood) guarding reward (treasure). Reuses the EXISTING rich_ore variant (Blast Furnace: 1→2
## ingots) — no new content. Seeded from a solid RIM cell so _grow_vein bores INTO the surrounding rock
## (it only replaces solid earth/stone/deepslate/shale, never the water/air the pocket carved).
## Vein BODY size (cells) — modest so it reads as a treasure vein, not wallpaper (a few drills' worth).
const AQUIFER_ORE_SIZE_MIN: int = 5
const AQUIFER_ORE_SIZE_MAX: int = 9
## Per-cell deposit: the deep-band ore baseline (ORE_AMOUNT_BASE + full-depth bonus) × the rich multiplier,
## mirroring _scatter_veins' rich_ore richness math (aquifers live deep, so the deep baseline is right).
const AQUIFER_ORE_RICHNESS: int = int((ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS) * RICH_AMOUNT_MULT)

# --- surface trees (wood source — the bazaar's gathering foundation) ---
## A tree is planted in an eligible column this often; min columns between trunks (spacing so the
## 3-wide canopies mostly read as separate trees). Sparse — the surface reads as wooded, not a wall.
const TREE_CHANCE: float = 0.20
const TREE_GAP: int = 3

## The abandoned Bazaar RUIN: an almost-complete wood frame stamped on flat ground near spawn. Finishing
## it (placing the one missing block) activates it — the onboarding for "build a Bazaar", the first lore
## ("someone was here"), and a worked example of the pattern. It is the LEFT endpoint of
## the centred plateau (cols 40-43); its missing post is the bottom-RIGHT one, so it's claimed from the
## SPAWN side (col 44) and completing it never walls the body off from the hand-work + shaft to its right.
const RUIN_X: int = 40


func generate(cols: int, rows: int, seed: int) -> WorldData:
	# Start from the heightmap base (surface + earth/stone blocks + matching walls), then enrich.
	var world: WorldData = super.generate(cols, rows, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Per-column horizontal richness multiplier (the frontier pull) — built once, reused by ore + coal.
	var hfield: PackedFloat32Array = _horizontal_field(cols, seed)
	_band_strata(world)          # STRATA: stack hard shelf bands (shale) through the mid rock (#93)
	_band_deepslate(world)
	_carve_caves(world, seed)    # anisotropic + shelf-aware → wide flat caverns, overhangs, ledges (#93)
	_carve_big_caverns(world, rng)   # a few large cohesive chambers the tunnels thread together (#93)
	_carve_tunnels(world, rng)
	_scatter_veins(world, rng, hfield)
	_scatter_coal(world, rng, hfield)
	_scatter_iron(world, rng)
	# THE VERTICAL PASSES (#S5) run AFTER the ore, and the order is load-bearing in two directions. A rift
	# cut through finished rock SLICES VEINS, so its walls show exposed ore — the chasm is a landmark that
	# is also a reward, which is the whole reason to walk to one. And the ore field's horizontal balance
	# (the frontier pull) is computed on unperturbed rock, so a rift that happens to land on a frontier
	# band can't quietly eat that band's richness — which it did, and the harness said so.
	var rift_cells: Array[Vector2i] = _carve_rifts(world, rng)
	_mineralize(world, rng, rift_cells)                # RIFTS: vertical space — and the reason to go to one
	_open_sinkholes(world, rng, rift_cells)            # ...and the reason it is not sealed under a lid
	_stud_ledges(world, rng)     # then put rock BACK: shelves, spires and rubble, so open space has form
	_stud_spires(world, rng)
	_scatter_rubble(world, rng)
	# LAST pass over the rock, so it judges the world every earlier pass actually left behind: no column
	# may run dry, however the veins, caves, rifts and rubble happened to fall.
	_seed_droughts(world, rng)
	_plant_trees(world, rng)
	_stamp_bazaar_ruin(world)
	_stamp_seal(world)          # LAST solid pass: the gate band overwrites everything, so nothing can hole it
	_seed_aquifers(world, rng)  # AFTER the seal — carves + fills water into solid rock; no later pass touches it
	# DEAD LAST, and for a reason the other passes do not have: every lode guard tests the FINAL world
	# (host rock, no water, nothing already there), and the seal overwrites blocks wholesale while the
	# aquifers carve rock away and flood it. Anywhere earlier and a later pass could falsify a guard after
	# it had been checked — burying a vein inside the unmineable seal, or leaving one hanging in a flooded
	# void. Nothing runs after this, so nothing can.
	_seed_lodes(world, rng, hfield)
	return world


## Build the per-column HORIZONTAL richness multiplier (the frontier pull, see HORIZONTAL_STRENGTH).
## Deterministic in (cols, seed): a seeded low-frequency noise band mixed with a distance-from-spawn ramp,
## normalised to [0,1] then mapped to a multiplier in [1 - STRENGTH, 1 + STRENGTH]. Some x-bands come out
## rich (>1), some lean (<1), and the ramp tilts the richest ones AWAY from spawn — so the cheapest fat
## fresh vein at a given depth is out on the frontier, not straight down the spawn column.
func _horizontal_field(cols: int, seed: int) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed + 91_331               # offset so the richness band doesn't correlate with the caves
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = HORIZONTAL_FREQ
	# Farthest any column sits from spawn — normalises the distance ramp so an edge column reaches ~1.
	var max_dist: float = float(maxi(1, maxi(SPAWN_COL, cols - 1 - SPAWN_COL)))
	var field := PackedFloat32Array()
	field.resize(cols)
	for col: int in cols:
		# (a) organic noise band in [0,1]; (b) distance-from-spawn ramp in [0,1] (0 at spawn, 1 at the edge).
		var band: float = (noise.get_noise_2d(float(col), 0.0) + 1.0) * 0.5
		var ramp: float = float(abs(col - SPAWN_COL)) / max_dist
		var mix: float = lerpf(band, ramp, FRONTIER_BIAS)   # tilt toward the frontier ramp per FRONTIER_BIAS
		# Map the [0,1] mix onto a symmetric multiplier around 1.0, bounded by STRENGTH (keeps it subtle).
		field[col] = 1.0 + (mix * 2.0 - 1.0) * HORIZONTAL_STRENGTH
	return field


## Convert the deep band (rows ≥ DEEPSLATE_ROW) of stone to deepslate, in both grids, so a dug-out deep
## cell reveals a deepslate wall. A new material id dropped into generation — renderer just needs it
## registered. Veins still overlay afterwards.
func _band_deepslate(world: WorldData) -> void:
	for cell: Vector2i in world.blocks:
		if cell.y >= DEEPSLATE_ROW and world.blocks[cell] == &"stone":
			world.blocks[cell] = &"deepslate"
	for cell: Vector2i in world.walls:
		if cell.y >= DEEPSLATE_ROW and world.walls[cell] == &"stone_wall":
			world.walls[cell] = &"deepslate_wall"


## STRATA — is the band containing `row` a HARD SHELF band? Deterministic per band index (a cheap hash),
## so shelf layers stack at stable depths (every STRATA_SHELF_EVERY-th band). Only within the mid-rock
## strata zone (surface fill .. STRATA_MAX_ROW); above/below returns false (soft rock / deepslate own the look).
func _is_shelf_band(row: int) -> bool:
	if row >= STRATA_MAX_ROW:
		return false
	var band: int = row / STRATA_BAND_H
	# A tiny deterministic scramble so the shelves aren't a rigid "every 3rd" metronome but still stable.
	return ((band * 2654435761) >> 3) % STRATA_SHELF_EVERY == 0


## STRATA banding: turn the HARD SHELF bands of the mid rock into &"shale" (a distinct, cave-resistant rock),
## in BOTH grids, so descending crosses stacked layers of different rock. Only converts existing solid
## earth/stone (never fills a cave or overwrites ore — this runs BEFORE veins/caves). The cave carver then
## resists these bands (STRATA_SHELF_RESIST), so a shale band survives as a continuous ledge/bridge — the
## fine renderer molds it into a shelf with an overhanging rock lip. Reads as layered rock, not blob rock.
func _band_strata(world: WorldData) -> void:
	for cell: Vector2i in world.blocks:
		if cell.y >= STRATA_MAX_ROW:
			continue
		if not _is_shelf_band(cell.y):
			continue
		# Only band the STONE zone — leave the earth surface layer (grass cap + tree roots) alone, so the
		# strata read starts below ground where the rock does.
		if world.blocks[cell] == &"stone":
			world.blocks[cell] = &"shale"
			if world.walls.get(cell, &"") == &"stone_wall":
				world.walls[cell] = &"shale_wall"


## Carve organic caves with seeded noise, now ANISOTROPIC + STRATA-AWARE (#93) so caverns read as wide
## flat-floored halls with overhanging ceilings and shelves — not round blobs:
##   • X is COMPRESSED (CAVE_XSTRETCH) before sampling → noise features span more columns than rows, so the
##     open space stretches HORIZONTALLY (ledges + overhangs, the reference's shape).
##   • HARD SHELF bands (shale) resist carving (STRATA_SHELF_RESIST added to their threshold) → a shelf band
##     survives as a continuous ledge/bridge that a cavern's floor rests on and its ceiling hangs from.
##   • an asymmetric SHELF BIAS makes the cell just UNDER a shelf easier to open and just ABOVE one harder →
##     caves undercut the hard band (overhang) and pool below it (flat floor).
## A cell opens (block erased, WALL kept) when noise clears the (depth-eased + strata-adjusted) threshold —
## still rarer/smaller near the surface, wider deep, and never breaching the base-safe band.
func _carve_caves(world: WorldData, seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = CAVE_FREQ
	for col: int in world.cols:
		var top: int = ground_row(col)
		var cave_start: int = top + CAVE_MIN_DEPTH
		for row: int in range(cave_start, world.rows):
			var cell: Vector2i = Vector2i(col, row)
			if not world.blocks.has(cell):
				continue
			var depth_frac: float = float(row - cave_start) / float(maxi(1, world.rows - cave_start))
			var threshold: float = lerpf(CAVE_THRESHOLD_TOP, CAVE_THRESHOLD_DEEP, depth_frac)
			# STRATA resistance: a hard shelf band is much harder to open (survives as a ledge/bridge).
			if _is_shelf_band(row):
				threshold += STRATA_SHELF_RESIST
			# OVERHANG bias: easier just under a shelf (undercut → overhang), harder just above one (roof pools).
			elif _is_shelf_band(row - 1):
				threshold -= CAVE_SHELF_BIAS
			elif _is_shelf_band(row + 1):
				threshold += CAVE_SHELF_BIAS
			# Anisotropy: compress X so features span more columns than rows → wide, flat caverns.
			if noise.get_noise_2d(float(col) / CAVE_XSTRETCH, float(row)) > threshold:
				world.blocks.erase(cell)        # open air; the wall behind it stays (carved room)


## BIGGER CAVERNS (#93): stamp a few large cohesive chambers deep in the rock — wide, flat-floored ellipses
## (a hard vertical squash + a solid floor shelf kept below the centre) whose union with the tunnel worms
## gives the world real ROOMS to explore, not just noise pockets. Each keeps its wall (carved room), never
## breaches the base-safe band, and only opens solid rock. Deterministic via the shared rng.
func _carve_big_caverns(world: WorldData, rng: RandomNumberGenerator) -> void:
	var count: int = maxi(2, _density_count(world, CAVERN_PER_COL))
	# Chambers live in the deep-but-above-seal band so they read as big open halls in Stonereach's approach.
	var lo_row: int = DEEPSLATE_ROW - 18
	var hi_row: int = SEAL_TOP - 3
	if hi_row <= lo_row:
		return
	for _c: int in count:
		var cx: int = rng.randi_range(4, world.cols - 5)
		var cy: int = rng.randi_range(lo_row, hi_row)
		var rx: int = rng.randi_range(CAVERN_RX_MIN, CAVERN_RX_MAX)
		var ry: int = rng.randi_range(CAVERN_RY_MIN, CAVERN_RY_MAX)
		# Keep the bottom ~third of the ellipse SOLID → a flat floor shelf to stand on (not a floating ball).
		var floor_cut: int = maxi(1, ry - 1)
		for dy: int in range(-ry, ry + 1):
			for dx: int in range(-rx, rx + 1):
				if dy > floor_cut:
					continue                                  # leave a flat floor below the centre
				var ex: float = float(dx) / float(rx)
				var ey: float = float(dy) / float(ry)
				if ex * ex + ey * ey > 1.0:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				if not world.in_bounds(cell):
					continue
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue                                  # protect the near-surface base
				if world.blocks.has(cell):
					world.blocks.erase(cell)                  # open; wall kept (carved room)


## Winding TUNNELS: a few worms random-walk through the rock with a horizontal bias, carving walkable
## caverns that thread the isolated noise pockets into one connected, explorable system (the noise alone
## gives blobs; these give you somewhere to GO). Each worm keeps its wall (carved room) and never rises
## into the base-safe band. Deterministic via the shared rng.
func _carve_tunnels(world: WorldData, rng: RandomNumberGenerator) -> void:
	var worms: int = maxi(3, _density_count(world, TUNNEL_PER_COL))
	for _w: int in worms:
		var x: float = float(rng.randi_range(2, world.cols - 3))
		var min_row: int = ground_row(int(x)) + CAVE_MIN_DEPTH + 2
		if min_row >= world.rows - 2:
			continue
		var y: float = float(rng.randi_range(min_row, world.rows - 2))
		var angle: float = rng.randf_range(-PI, PI)
		var length: int = rng.randi_range(TUNNEL_MIN_LEN, TUNNEL_MAX_LEN)
		for _s: int in length:
			_carve_disc(world, Vector2i(int(round(x)), int(round(y))), TUNNEL_RADIUS)
			angle += rng.randf_range(-0.5, 0.5)         # gentle wander
			x += cos(angle)
			y += sin(angle) * 0.55                       # bias horizontal (flatten vertical drift)
			if x < 1.0 or x >= float(world.cols - 1) or y >= float(world.rows - 1):
				break


## Carve a small disc of OPEN air (block erased, wall kept), refusing any cell in a column's base-safe
## band so tunnels never undermine the spawn surface.
func _carve_disc(world: WorldData, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + 1:
				continue
			var cell: Vector2i = center + Vector2i(dx, dy)
			if not world.in_bounds(cell):
				continue
			if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
				continue                                 # protect the near-surface base
			if world.blocks.has(cell):
				world.blocks.erase(cell)


## RIFTS. A chasm walks DOWN from a start row, wandering slightly, carving a column of open air whose
## half-width breathes along the way (so it pinches to a squeeze and opens into a shaft rather than being
## a uniform slot). Like every other carve it keeps the wall behind it — a rift is a room, not a hole in
## the world — and it refuses the base-safe band under the spawn surface, so one can never open a chimney
## straight into the tutorial.
func _carve_rifts(world: WorldData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var carved: Array[Vector2i] = []
	var count: int = maxi(2, _density_count(world, RIFT_PER_COL))
	for _r: int in count:
		var x: float = float(rng.randi_range(5, world.cols - 6))
		# Push a rift that rolled too near spawn out to whichever side it was already leaning toward.
		if absf(x - float(SPAWN_COL)) < float(RIFT_SPAWN_KEEPOUT):
			var away: float = 1.0 if x >= float(SPAWN_COL) else -1.0
			x = clampf(float(SPAWN_COL) + away * float(RIFT_SPAWN_KEEPOUT), 5.0, float(world.cols - 6))
		var top: int = ground_row(int(x)) + CAVE_MIN_DEPTH + rng.randi_range(2, 10)
		var length: int = rng.randi_range(RIFT_MIN_LEN, RIFT_MAX_LEN)
		var drift: float = rng.randf_range(-RIFT_WANDER, RIFT_WANDER)
		var phase: float = rng.randf_range(0.0, TAU)
		var pinch: float = rng.randf_range(0.16, 0.30)      # how fast the width breathes down the fall
		for i: int in length:
			var row: int = top + i
			if row >= world.rows - 2:
				break
			# Width breathes on a sine so the chasm reads as carved by something that varied, not extruded.
			var t: float = 0.5 + 0.5 * sin(phase + float(i) * pinch)
			var half: float = lerpf(RIFT_HALF_W_MIN, RIFT_HALF_W_MAX, t)
			var lo: int = int(floor(x - half))
			var hi: int = int(ceil(x + half))
			for col: int in range(lo, hi + 1):
				var cell := Vector2i(col, row)
				if not world.in_bounds(cell):
					continue
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue
				world.blocks.erase(cell)
				world.routes[cell] = true          # deliberate vertical structure, not undirected cave
				carved.append(cell)
			x += drift
			drift = clampf(drift + rng.randf_range(-0.10, 0.10), -RIFT_WANDER, RIFT_WANDER)
			if x < 3.0 or x > float(world.cols - 4):
				break
	return carved


## SINKHOLES — the mouths, without which none of the vertical structure above exists as far as the player
## is concerned.
##
## Every carve in this generator refuses to touch the CAVE_MIN_DEPTH rows under a column's surface, which
## is a good rule: it keeps the near-surface solid by construction, so the open dark is something you go
## DOWN to rather than something that opens under your feet. Applied without exception, though, it seals
## the entire underground under an unbroken lid — and tools/check_descent measured exactly that. The whole
## connected open space of this world reached ONE row below the surface. Forty rows of chasm sat at column
## 24, beautifully carved, mineralised walls and all, in a sealed bottle. The rifts, the halls, the caverns
## and the grapple built to fall through them were, for a player, geometry nobody could ever arrive at.
##
## A handful of mouths does not undo that rule, it completes it. "Opt-in danger" is only a choice if you
## can SEE the thing you are opting into and walk to it. A sinkhole is a landmark on the skyline, a route
## down that costs no pickaxe and some nerve, and — because the daylight soak follows a column's surface —
## a shaft of daylight falling into the dark, which is the single most valuable thing a mouth can be.
##
## Cut UP from the top of a rift rather than down from the sky, so a mouth always opens onto somewhere
## worth arriving at, and flared toward the surface so it reads as a collapse rather than as a drilled pipe.
##
## WHERE they open matters as much as that they do. The first version took the leftmost rift column that
## cleared the keepout, which meant a mouth could open over the thin tapering END of a chasm: tools/
## check_plunge played that descent and the body dropped twelve rows onto a shelf and stood there for the
## rest of the budget. A hole that lands you on a floor is a pit. So the columns are ranked by the FALL
## underneath them — the tallest unbroken open run below the rift ceiling — and the mouths go over the
## deepest ones. Stepping in is then a commitment to a real drop, which is the only version of this that
## is worth walking across a world to find.
const SINKHOLE_COUNT: int = 3            ## mouths in a world — landmarks, and rare enough to stay landmarks
const SINKHOLE_MOUTH_HALF: float = 3.0   ## half-width where it meets the sky: wide enough to see from away
const SINKHOLE_THROAT_HALF: float = 1.1  ## ...and where it joins the rift below
const SINKHOLE_FLARE: float = 2.2        ## >1 keeps the throat narrow and opens the cone late (a collapse)
const SINKHOLE_KEEPOUT: int = 20         ## columns either side of spawn that stay sealed (the tutorial's ground)
const SINKHOLE_SPACING: int = 15         ## columns between mouths, so no two read as one broken region
const SINKHOLE_WANDER: float = 0.22      ## cells of drift per row — a throat, not a drainpipe
const SINKHOLE_MIN_DROP: int = 14        ## rows of fall under a mouth, below which it is a pit not a route

func _open_sinkholes(world: WorldData, rng: RandomNumberGenerator, rift_cells: Array[Vector2i]) -> void:
	# The highest open cell in each column the rifts carved — the ceiling that has to be broken through.
	var tops: Dictionary = {}
	for c: Vector2i in rift_cells:
		if not tops.has(c.x) or c.y < int(tops[c.x]):
			tops[c.x] = c.y
	var cols: Array = tops.keys()
	cols.sort()

	# Rank by the fall underneath, deepest first, ties to the leftmost column so the pick stays deterministic.
	var ranked: Array[Vector2i] = []
	for col: Variant in cols:
		var cx: int = col
		if absi(cx - SPAWN_COL) < SINKHOLE_KEEPOUT:
			continue                                        # the tutorial's ground stays solid
		ranked.append(Vector2i(cx, _drop_below(world, cx, int(tops[cx]))))
	ranked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y if a.y != b.y else a.x < b.x)

	var opened: Array[int] = []
	for cand: Vector2i in ranked:
		if opened.size() >= SINKHOLE_COUNT or cand.y < SINKHOLE_MIN_DROP:
			break                                           # nothing left worth opening onto
		var clear: bool = true
		for prev: int in opened:
			if absi(cand.x - prev) < SINKHOLE_SPACING:
				clear = false
		if not clear:
			continue
		opened.append(cand.x)
		_cut_throat(world, rng, cand.x, int(tops[cand.x]))


## How far a body that stepped into a mouth at this column would actually FALL: the unbroken open run
## below the rift's ceiling. This is the number that separates a route from a pit.
func _drop_below(world: WorldData, col: int, ceiling: int) -> int:
	var run: int = 0
	for row: int in range(ceiling, world.rows):
		if world.blocks.has(Vector2i(col, row)):
			break
		run += 1
	return run


## Carve one flaring shaft from a rift's ceiling up through the lid to daylight.
func _cut_throat(world: WorldData, rng: RandomNumberGenerator, col: int, rift_top: int) -> void:
	var sky: int = ground_row(col)
	if rift_top <= sky + 2:
		return                                          # already open enough to be its own mouth
	var x: float = float(col)
	var drift: float = rng.randf_range(-SINKHOLE_WANDER, SINKHOLE_WANDER)
	for row: int in range(rift_top, sky - 1, -1):
		var up: float = 1.0 - float(row - sky) / float(maxi(1, rift_top - sky))   # 0 at the rift, 1 at the sky
		var half: float = lerpf(SINKHOLE_THROAT_HALF, SINKHOLE_MOUTH_HALF, pow(up, SINKHOLE_FLARE))
		for c: int in range(int(floor(x - half)), int(ceil(x + half)) + 1):
			var cell := Vector2i(c, row)
			if world.in_bounds(cell):
				world.blocks.erase(cell)                # deliberately past CAVE_MIN_DEPTH: this IS the mouth
				world.routes[cell] = true
		# THE FALL LINE stays plumb. The wander is decoration — it stops the shaft reading as a drilled pipe —
		# but a cone that drifts away from the column the drop is under puts the mouth in one place and the
		# fall in another, and a body that steps in slides down the SIDE of its own sinkhole, catching every
		# shelf on the way. So the source column is opened at every row regardless: one clean line from the
		# sky to the chasm, with a collapse shaped around it.
		var plumb := Vector2i(col, row)
		if world.in_bounds(plumb):
			world.blocks.erase(plumb)
			world.routes[plumb] = true
		x += drift
		drift = clampf(drift + rng.randf_range(-0.08, 0.08), -SINKHOLE_WANDER, SINKHOLE_WANDER)


## THE CHASM PAYS. Walk the rift's own carved cells, look at the solid rock touching each one, and enrich
## it: ore already there upgrades to RICH ore, plain rock sometimes becomes ore. Runs on the carve's own
## cell list rather than rescanning the grid, so it can only ever touch rift walls — a cave that happens
## to sit next to one is untouched, and the enrichment stays a property of rifts specifically.
func _mineralize(world: WorldData, rng: RandomNumberGenerator, carved: Array[Vector2i]) -> void:
	var rich: int = int(round(float(ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS) * RICH_AMOUNT_MULT))
	var touched: Dictionary = {}
	for c: Vector2i in carved:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cell: Vector2i = c + d
			if touched.has(cell) or not world.in_bounds(cell):
				continue
			touched[cell] = true
			var here: StringName = world.blocks.get(cell, &"")
			if here == &"ore":
				# RICH ore stays a DEEP find, rift or no rift. The chasm makes the deep band richer; it
				# does not move the band up. A fissure that handed out rich ore at twenty rows would let
				# a player skip the whole tier gate by walking sideways.
				if cell.y >= DEEPSLATE_ROW and rng.randf() < RIFT_WALL_RICH_CHANCE:
					world.blocks[cell] = &"rich_ore"
					world.amounts[cell] = rich
			elif here == &"stone" or here == &"shale" or here == &"deepslate":
				if rng.randf() < RIFT_WALL_ORE_CHANCE:
					world.blocks[cell] = &"ore"
					world.amounts[cell] = ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS


## LEDGES. Walk the open cells; where an open cell sits against a solid side wall and has open air above
## it (so the shelf is something you could stand ON), grow a short tongue of rock out into the space.
## Sampled from a snapshot of the open set so a ledge placed this pass can't seed another one next to it.
func _stud_ledges(world: WorldData, rng: RandomNumberGenerator) -> void:
	var sites: Array[Vector2i] = _open_cells(world)
	var wanted: int = _density_count(world, LEDGE_PER_COL)
	for _i: int in wanted:
		if sites.is_empty():
			return
		var c: Vector2i = sites[rng.randi_range(0, sites.size() - 1)]
		var dir: int = 0
		if world.blocks.has(c + Vector2i(-1, 0)):
			dir = 1                                   # wall on the left → the shelf grows right
		elif world.blocks.has(c + Vector2i(1, 0)):
			dir = -1
		if dir == 0:
			continue                                  # needs a wall to spring from
		var clear: bool = true
		for h: int in range(1, LEDGE_HEADROOM + 1):
			if world.blocks.has(c + Vector2i(0, -h)):
				clear = false
				break
		if not clear:
			continue                                  # a shelf you cannot stand on is just fill
		var mat: StringName = _structural_rock(world.blocks.get(c + Vector2i(-dir, 0), &"stone"))
		var run: int = rng.randi_range(LEDGE_LEN_MIN, LEDGE_LEN_MAX)
		for k: int in run:
			var cell: Vector2i = c + Vector2i(dir * k, 0)
			if not world.in_bounds(cell) or world.blocks.has(cell):
				break
			world.blocks[cell] = mat


## SPIRES. Hang teeth from ceilings and raise them from floors, tapering to a point so the silhouette is
## a spike rather than a post. A ceiling cell is open with solid directly above; a floor cell is open with
## solid directly below. Both take the material of the rock they grow out of, so a spire in the deepslate
## band is deepslate and reads as part of the same stone.
func _stud_spires(world: WorldData, rng: RandomNumberGenerator) -> void:
	for c: Vector2i in _open_cells(world):
		var down: bool = world.blocks.has(c + Vector2i(0, -1))
		var up: bool = world.blocks.has(c + Vector2i(0, 1))
		if down == up:
			continue                                  # a 1-cell gap between two solids grows nothing
		var hang: bool = down                         # solid above → this tooth hangs from a ceiling
		if rng.randf() > SPIRE_CHANCE * (1.0 if hang else SPIRE_FLOOR_BIAS):
			continue
		var step: int = 1 if hang else -1
		var mat: StringName = _structural_rock(world.blocks.get(c + Vector2i(0, -step), &"stone"))
		var run: int = rng.randi_range(SPIRE_HANG_MIN, SPIRE_HANG_MAX) if hang \
			else rng.randi_range(SPIRE_RISE_MIN, SPIRE_RISE_MAX)
		for k: int in run:
			var cell: Vector2i = c + Vector2i(0, step * k)
			if not world.in_bounds(cell) or world.blocks.has(cell):
				break
			world.blocks[cell] = mat


## RUBBLE: a single loose block resting on a cave floor. One cell, no cleverness — but a floor with a few
## stones on it reads as a place where things have come to rest, and a bare one reads as an edge.
func _scatter_rubble(world: WorldData, rng: RandomNumberGenerator) -> void:
	for c: Vector2i in _open_cells(world):
		if not world.blocks.has(c + Vector2i(0, 1)):
			continue                                  # must be resting on something
		if world.blocks.has(c + Vector2i(0, -1)):
			continue                                  # ...with air above it, or it is just fill
		if rng.randf() > RUBBLE_CHANCE:
			continue
		world.blocks[c] = _structural_rock(world.blocks.get(c + Vector2i(0, 1), &"stone"))


## The material a structural block should be built from, given the rock it grows out of. Ore, coal and
## iron are REWARDS — a stalagmite or a loose stone made of them would be free ore lying on a cave floor,
## which is not what a cave floor is for. Structure is always plain rock.
const _REWARD_ROCK: Array[StringName] = [&"ore", &"rich_ore", &"coal", &"iron"]


func _structural_rock(source: StringName) -> StringName:
	return &"stone" if source == &"" or _REWARD_ROCK.has(source) else source


## Every underground cell that is currently OPEN, in a deterministic order. Built by scanning the grid
## rather than by tracking carves, so it sees the union of every carve pass that ran before it — and the
## fixed scan order is what keeps the studding passes byte-identical across runs at a given seed.
func _open_cells(world: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in world.cols:
		var top: int = ground_row(col) + CAVE_MIN_DEPTH
		for row: int in range(top, world.rows - 1):
			var cell := Vector2i(col, row)
			if not world.blocks.has(cell):
				out.append(cell)
	return out


## The depth band, floored: `floor` at the surface rising to 1.0 at the bottom of the world. Ore and coal
## both weight their acceptance rolls through this, which is what keeps "deeper is richer" a GRADIENT
## rather than a cliff with nothing on the near side of it.
static func _banded(depth_frac: float, floor_frac: float) -> float:
	return floor_frac + (1.0 - floor_frac) * clampf(depth_frac, 0.0, 1.0)


## THE DROUGHT PASS — the guarantee that random placement cannot give you.
##
## Flooring the depth ramp raised the AVERAGE, and an average is not what tedium is made of: a world can
## measure a fine 7.5 encounters per hundred rows and still contain the one shaft that ran thirty-five
## rows of identical rock, and that shaft is the one the player was in. Randomness produces such runs
## constantly — that is what randomness IS — so no amount of density buys the property. It has to be
## enforced, so this walks every column and, wherever the rock has gone quiet for too long, plants
## something back in the middle of the silence.
##
## What it plants is varied on purpose, because a rule that always yields the same thing reads as a rule.
## Mostly a small vein — deliberately small, these are make-up pockets and not bonanzas — and sometimes a
## VUG, a little cavity in solid rock. The vug is the better half of the deal: strike 11 gave the pick a
## hollow ring that rises as you approach a void, so a vug is a thing you HEAR before you reach it, and a
## drought broken by one is a drought that ended with a question rather than with a lump of ore.
##
## Blobs span several columns, so a column fixed here fixes its neighbours too — the pass reads the world
## it is writing, and quietly does less work the richer the surrounding rock already is.
const DROUGHT_LIMIT: int = 18            ## rows of unbroken plain rock before the generator owes you something
const DROUGHT_VUG_CHANCE: float = 0.28   ## ...and how often what it owes you is a cavity rather than a vein
const DROUGHT_VEIN_SIZE: int = 5
const DROUGHT_COAL_BIAS: float = 0.38    ## share of planted veins that are coal rather than ore
const PLAIN_ROCK: Array[StringName] = [&"earth", &"stone", &"shale", &"deepslate"]

func _seed_droughts(world: WorldData, rng: RandomNumberGenerator) -> void:
	for col: int in world.cols:
		var top: int = ground_row(col) + CAVE_MIN_DEPTH
		var run: int = 0
		for row: int in range(top, world.rows):
			if not _is_plain(world, Vector2i(col, row)):
				run = 0
				continue
			run += 1
			if run < DROUGHT_LIMIT:
				continue
			# Plant back INTO the run we just walked, not at its far end, so the break lands in the middle
			# of the quiet rather than at the moment it was noticed.
			var at := Vector2i(col, row - rng.randi_range(3, DROUGHT_LIMIT - 4))
			if rng.randf() < DROUGHT_VUG_CHANCE:
				_carve_disc(world, at, 1)
			else:
				var span: int = maxi(1, world.rows - ground_row(col))
				var depth_frac: float = float(at.y - ground_row(col)) / float(span)
				var coal: bool = rng.randf() < DROUGHT_COAL_BIAS
				var base: int = COAL_AMOUNT_BASE if coal else ORE_AMOUNT_BASE
				var bonus: int = COAL_AMOUNT_DEPTH_BONUS if coal else ORE_AMOUNT_DEPTH_BONUS
				_grow_vein(world, rng, at, DROUGHT_VEIN_SIZE,
					base + int(round(depth_frac * float(bonus))), &"coal" if coal else &"ore")
			run = row - at.y


## Whether this cell is just "the rock here" — solid, and made of nothing worth stopping for.
func _is_plain(world: WorldData, cell: Vector2i) -> bool:
	return world.blocks.has(cell) and world.blocks[cell] in PLAIN_ROCK


## Depth-banded ore: many vein-seed attempts, each kept by a depth-weighted roll (deep seeds survive,
## shallow ones rarely do), then grown into a blob whose size also scales with depth. Ore only replaces
## SOLID rock (earth/stone) — never fills a carved cave, though a vein can sit exposed in a cave wall.
func _scatter_veins(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var attempts: int = _density_count(world, ORE_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = ground_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		# HORIZONTAL richness (the frontier pull): a rich x-band lifts acceptance/size/deposit above the
		# depth baseline, a lean band drops them below — so at a fixed depth the fat fresh veins fan OUT.
		var hmul: float = hfield[cx]
		if rng.randf() > _banded(depth_frac, ORE_SHALLOW_FLOOR) * ORE_CHANCE_DEEP * hmul:
			continue                            # rejected — shallow seeds still mostly die here (the band)
		var size: int = ORE_SIZE_MIN + int(round(depth_frac * float(ORE_SIZE_DEPTH_BONUS) * hmul))
		var richness: int = ORE_AMOUNT_BASE + int(round(depth_frac * float(ORE_AMOUNT_DEPTH_BONUS) * hmul))
		# ORE QUALITY: a vein seeded in/below the deepslate band may come up RICH — a
		# visibly denser high-grade variant (1 rich ore smelts 2 ingots in the Blast Furnace). Deeper =
		# richer gains a second axis: down there veins aren't just bigger, they're better.
		var material: StringName = &"ore"
		if cy >= DEEPSLATE_ROW and rng.randf() < RICH_CHANCE:
			material = &"rich_ore"
			richness = int(round(float(richness) * RICH_AMOUNT_MULT))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness, material)


## A depth-banded COAL pass — the drill's fuel. Same machinery as ore veins (cavity model), its own
## depth-weighted commonness/size/richness, stamping &"coal" blocks the player mines for coal.
func _scatter_coal(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var attempts: int = _density_count(world, COAL_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = ground_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		var hmul: float = hfield[cx]            # same frontier pull as ore (coal fans out too)
		if rng.randf() > _banded(depth_frac, COAL_SHALLOW_FLOOR) * COAL_CHANCE_DEEP * hmul:
			continue
		var size: int = COAL_SIZE_MIN + int(round(depth_frac * float(COAL_SIZE_DEPTH_BONUS) * hmul))
		var richness: int = COAL_AMOUNT_BASE + int(round(depth_frac * float(COAL_AMOUNT_DEPTH_BONUS) * hmul))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness, &"coal")


## Grow one vein as a compact ACCRETION BLOB (not a thin random walk): repeatedly fill a random frontier
## cell and add its rock neighbours, so the body comes out fat + contiguous — a real ore BODY you can line
## the top of with a row of drills, each boring its own column down through it (the scaling supply loop).
## Every converted cell carries the vein's depth-scaled `richness` (its finite per-cell deposit).
## `min_row` floors the blob: a frontier cell above it is refused — IRON must never crest through the
## seal rows onto the pre-breach shelf (a latent leak surfaced when #48's rich roll shifted the RNG
## sequence: a blob seeded just under the seal could climb through rows the seal stamp later re-fills
## and leave its crest ABOVE them, handing out L2's signature ore before the breach).
func _grow_vein(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int, richness: int, material: StringName = &"ore", min_row: int = 0) -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var cell: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if filled.has(cell) or not world.in_bounds(cell) or cell.y < min_row:
			continue
		var here: StringName = world.blocks.get(cell, &"")
		if here != &"earth" and here != &"stone" and here != &"deepslate" and here != &"shale":
			continue                                # only replace SOLID rock (never fill a carved cave)
		world.blocks[cell] = material
		world.amounts[cell] = richness
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## LODE BODIES — the same accretion machinery as every vein above, writing to the BACKGROUND plane and
## leaving the host rock exactly where it was. That single difference is the whole design: an ore block is
## something you destroy, a lode is something you uncover.
##
## Runs DEAD LAST in `generate`, after the seal and after the aquifers, and that is load-bearing rather
## than tidy. Every guard below tests the world as it will finally be — host rock, wall behind it, no water
## in the cell — and a later pass could invalidate any of them: the seal overwrites blocks wholesale, and
## the aquifers carve solid rock away and flood it. Seeding lodes earlier would let the seal bury a vein
## inside an unmineable band and let an aquifer leave one hanging in a flooded void. Being last means no
## pass can falsify a guard after it has been checked.
##
## The material follows the tier the depth already means, rather than inventing a third convention: ore
## above the seal, iron below it, exactly as `_scatter_veins` and `_scatter_iron` divide the world.
func _seed_lodes(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var l2_top: int = SEAL_TOP + SEAL_ROWS
	for _i: int in _density_count(world, LODE_ATTEMPTS_PER_COL):
		var cx: int = rng.randi_range(0, world.cols - 1)
		var floor_row: int = ground_row(cx) + LODE_MIN_DEPTH
		if floor_row >= world.rows - 1:
			continue
		var cy: int = rng.randi_range(floor_row, world.rows - 1)
		# Depth sets size and richness, and the horizontal field tilts the fat ones AWAY from spawn — the
		# same frontier pull the ore uses, so a lode obeys the economic geography the rest of the world
		# already has instead of scattering flat through it.
		var depth_frac: float = float(cy) / float(maxi(1, world.rows - 1))
		var hmul: float = hfield[cx] if cx < hfield.size() else 1.0
		var size: int = LODE_SIZE_MIN + int(round(depth_frac * float(LODE_SIZE_DEPTH_BONUS)))
		var richness: int = LODE_AMOUNT_BASE \
			+ int(round(depth_frac * float(LODE_AMOUNT_DEPTH_BONUS) * hmul))
		_grow_lode(world, rng, Vector2i(cx, cy), size, maxi(1, richness),
			&"iron" if cy >= l2_top else &"ore", floor_row)


## Grow one lode body. Identical accretion to `_grow_vein` — random-frontier blob, deterministic in the
## rng sequence — with the one difference that it writes `world.lodes` and NEVER touches `world.blocks`.
##
## THE FOUR GUARDS, each of which is a way this could be silently wrong rather than a style preference:
##
##   HOST ROCK ONLY.       Plain earth/stone/deepslate/shale. Never sealrock (the one band worldgen
##                         promises is solid and unmineable — a vein nobody can ever reach), never
##                         foliage or bazaar structure, and never a carved-open cell, which would leave
##                         ore hanging in mid-air in a cave instead of behind a face you clear.
##   NEVER ON ORE-LIKE.    The double-source guard. Mining an ore block WRITES a lode into its own cell
##                         (`factory_sim.gd`, the blow that opens a vein), so a lode already there would be
##                         overwritten along with its richness. One vein per cell, from one source.
##   NEVER TWICE.          Two bodies overlapping would fight over `amounts`, and the second one's number
##                         would win for cells that belong to both — a vein whose richness depends on
##                         iteration order is not deterministic in any useful sense.
##   NEVER IN WATER.       An aquifer cell is carved open and flooded; a lode there is both exposed and
##                         underwater before anyone has touched it.
##
## A wall behind it is not guarded because the base pass fills a wall under every rock cell in the world,
## and `WorldRenderer` draws a vein whether or not there is a wall behind it. It is asserted in the test
## rather than defended here, so if that ever stops being true it fails loudly instead of silently.
func _grow_lode(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int,
		richness: int, material: StringName, min_row: int) -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var cell: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if filled.has(cell) or not world.in_bounds(cell) or cell.y < min_row:
			continue
		var here: StringName = world.blocks.get(cell, &"")
		if here != &"earth" and here != &"stone" and here != &"deepslate" and here != &"shale":
			continue                                # host rock only — never ore-like, sealrock, wood, air
		if world.lodes.has(cell) or world.water.has(cell):
			continue                                # one vein per cell, and never inside an aquifer
		world.lodes[cell] = material
		world.amounts[cell] = richness              # a lode's richness IS its deposit; the sim reads both
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## IRON bodies — L2's reward, seeded ONLY below the seal (depth position within L2 sets size richness).
## Replaces solid rock exactly like ore/coal veins; the drill bores it the same way.
func _scatter_iron(world: WorldData, rng: RandomNumberGenerator) -> void:
	var l2_top: int = SEAL_TOP + SEAL_ROWS
	if l2_top >= world.rows - 1:
		return
	var attempts: int = _density_count(world, IRON_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var cy: int = rng.randi_range(l2_top, world.rows - 1)
		var depth_frac: float = float(cy - l2_top) / float(maxi(1, world.rows - l2_top))
		var size: int = IRON_SIZE_MIN + int(round(depth_frac * float(IRON_SIZE_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, IRON_AMOUNT, &"iron", l2_top)


## Stamp THE SEAL: an unbroken full-width sealrock band (rows SEAL_TOP..+SEAL_ROWS-1), filling even
## carved cells — the one thing worldgen guarantees solid. Backed by deepslate wall so the breach shaft
## reads as carved rock, not void.
func _stamp_seal(world: WorldData) -> void:
	for row: int in range(SEAL_TOP, mini(SEAL_TOP + SEAL_ROWS, world.rows)):
		for col: int in world.cols:
			var cell := Vector2i(col, row)
			world.blocks[cell] = &"sealrock"
			world.amounts.erase(cell)                 # a vein cell overwritten by the seal keeps no deposit
			if not world.walls.has(cell):
				world.walls[cell] = &"deepslate_wall"


## Seed AQUIFERS (L3): a handful of small SEALED water pockets carved deep into solid rock,
## filled to WATER_MAX, that you BREACH by digging in. Runs LAST (after the seal) so no later solid pass
## overwrites the water. Each pocket:
##   • is a small ellipse blob whose CENTRE sits at/below AQUIFER_MIN_ROW (the deep deepslate + Stonereach
##     band) — DEEP by construction, so the near-surface base stays dry;
##   • only ERASES SOLID rock (KEEPING the wall → a flooded carved room), and refuses any cell within the
##     column's base-safe band, the seal band, or already-open air — so the pocket is pressurised (sealed by
##     rock on all sides, not spliced into the cave/tunnel system), and never floods the base or holes the seal;
##   • fills exactly the cells it erased with WATER_MAX (water only lands in cells guaranteed carved-open).
## RISK/REWARD (L3 treasure): after carving each pocket, a modest &"rich_ore" vein is grown into the SOLID
## rock lining it (see _seed_aquifer_treasure) — the flood guards the reward.
## Deterministic via the shared rng.
func _seed_aquifers(world: WorldData, rng: RandomNumberGenerator) -> void:
	var count: int = maxi(2, _density_count(world, AQUIFER_PER_COL))
	var seal_lo: int = SEAL_TOP
	var seal_hi: int = SEAL_TOP + SEAL_ROWS - 1
	# Centres span the deep band: from AQUIFER_MIN_ROW down to near the world bottom (leave room for the blob).
	var lo_row: int = AQUIFER_MIN_ROW
	var hi_row: int = world.rows - 2
	if hi_row <= lo_row:
		return
	for _a: int in count:
		var cx: int = rng.randi_range(3, world.cols - 4)
		var cy: int = rng.randi_range(lo_row, hi_row)
		var rx: int = rng.randi_range(AQUIFER_RX_MIN, AQUIFER_RX_MAX)
		var ry: int = rng.randi_range(AQUIFER_RY_MIN, AQUIFER_RY_MAX)
		var carved: Array[Vector2i] = []            # the cells THIS pocket flooded — its rim is our vein seed
		for dy: int in range(-ry, ry + 1):
			for dx: int in range(-rx, rx + 1):
				var ex: float = float(dx) / float(rx)
				var ey: float = float(dy) / float(ry)
				if ex * ex + ey * ey > 1.0:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				if not world.in_bounds(cell):
					continue
				# BASE-SAFE: never within CAVE_MIN_DEPTH of the column's surface (base stays dry).
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue
				# Never in the seal band (the seal is inviolate solid) and never above the deep aquifer band.
				if cell.y < AQUIFER_MIN_ROW or (cell.y >= seal_lo and cell.y <= seal_hi):
					continue
				# Only carve SOLID rock (keep the wall → flooded carved room). Skip already-open air so the
				# pocket is sealed by rock, not spliced into the cave/tunnel system.
				if not world.blocks.has(cell):
					continue
				world.blocks.erase(cell)                  # open the cell (wall kept behind it)
				world.amounts.erase(cell)                 # a vein cell we flooded keeps no deposit
				world.water[cell] = FactorySim.WATER_MAX  # fill the carved cell (guaranteed not solid now)
				carved.append(cell)
		# REWARD: line the drained pocket's walls with a rich vein (only grows into the solid rim rock).
		_seed_aquifer_treasure(world, rng, carved)


## Grow the aquifer's REWARD vein: a modest &"rich_ore" body in the SOLID rock immediately lining the
## flooded pocket (its walls/floor), so breaching + draining + mining the walls pays out high-grade ore.
## Seeds from a SOLID rim cell — a 4-neighbour of a carved (now-water) cell that is still solid rock — so
## _grow_vein bores INTO the surrounding rock. _grow_vein only replaces solid earth/stone/deepslate/shale,
## so it can never fill the water/air the pocket carved; passing SEAL_TOP+SEAL_ROWS as min_row floors the
## blob at the top of Stonereach (belt-and-braces — the pocket already lives below the seal). Deterministic
## via the shared rng. `carved` is this pocket's flooded cells (empty on a fully-blocked pocket → no vein).
func _seed_aquifer_treasure(world: WorldData, rng: RandomNumberGenerator, carved: Array[Vector2i]) -> void:
	if carved.is_empty():
		return
	# Collect the SOLID rim: cells adjacent to a flooded cell that are still solid rock _grow_vein accepts.
	var rim: Array[Vector2i] = []
	var seen: Dictionary = {}
	for wc: Vector2i in carved:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = wc + d
			if seen.has(nb) or not world.in_bounds(nb):
				continue
			seen[nb] = true
			var here: StringName = world.blocks.get(nb, &"")
			if here == &"earth" or here == &"stone" or here == &"deepslate" or here == &"shale":
				rim.append(nb)
	if rim.is_empty():
		return                                         # pocket fully rimmed by seal/other water/air — no vein
	var seed_cell: Vector2i = rim[rng.randi_range(0, rim.size() - 1)]
	var size: int = rng.randi_range(AQUIFER_ORE_SIZE_MIN, AQUIFER_ORE_SIZE_MAX)
	_grow_vein(world, rng, seed_cell, size, AQUIFER_ORE_RICHNESS, &"rich_ore", SEAL_TOP + SEAL_ROWS)


## Plant sparse trees on the grass surface — the source of WOOD (the bazaar's gathering foundation).
## A tree is a 1-wide trunk of &"wood" under a 3-wide rounded &"leaves" canopy,
## stamped in the AIR above a column's ground cell. The centred flat plateau (the spawn cluster) is left clear
## so a tree never traps the player or buries the forge. Foliage is solid + choppable but excluded from
## the walkable silhouette (FactorySim.surface_row), so trees don't ramp; chopping one fells it (→wood).
func _plant_trees(world: WorldData, rng: RandomNumberGenerator) -> void:
	var last: int = -99
	# Keep the spawn → bazaar band clear of worldgen trees (a tree just past the 3-tall bazaar frame would be
	# the "nearest" tree but unreachable behind the wall). The tutorial tree (seeded left of spawn) is the
	# early wood source; natural trees start past the ruin + a buffer.
	var start: int = maxi(FLAT_END + 2, RUIN_X + FactorySim.BAZAAR_W + 3)
	for col: int in range(start, world.cols):
		if col - last < TREE_GAP or rng.randf() > TREE_CHANCE:
			continue
		var ground: int = ground_row(col)
		if not world.blocks.has(Vector2i(col, ground)):
			continue                                   # column has no solid surface here (cave mouth) — skip
		var trunk: int = rng.randi_range(2, 3)
		if ground - trunk - 2 < 0:
			continue                                   # not enough sky above for trunk + canopy
		var blocked: bool = false
		for h: int in range(1, trunk + 1):
			if world.blocks.has(Vector2i(col, ground - h)):
				blocked = true                         # a hill cell already occupies the trunk space — skip
				break
		if blocked:
			continue
		for h: int in range(1, trunk + 1):
			world.blocks[Vector2i(col, ground - h)] = &"wood"
		# Rounded canopy: a 3-wide band beside/above the trunk top, with a single leaf crowning it.
		var ttr: int = ground - trunk                  # row of the topmost trunk cell
		var canopy: Array[Vector2i] = [
			Vector2i(col, ttr - 1), Vector2i(col, ttr - 2),
			Vector2i(col - 1, ttr - 1), Vector2i(col + 1, ttr - 1),
			Vector2i(col - 1, ttr), Vector2i(col + 1, ttr),
		]
		for leaf: Vector2i in canopy:
			if leaf.y >= 0 and leaf.x >= 0 and leaf.x < world.cols and not world.blocks.has(leaf):
				world.blocks[leaf] = &"leaves"
		last = col


## Stamp the near-complete bazaar ruin (see RUIN_X). Flatten its footprint to FLAT_SURFACE_ROW, then lay
## the wood frame MINUS one block (the bottom-right post, facing spawn) for the player to finish — the moment it
## completes, FactorySim.find_bazaars detects it and the Bazaars view plays the transform.
func _stamp_bazaar_ruin(world: WorldData) -> void:
	var ground: int = FLAT_SURFACE_ROW
	var w: int = FactorySim.BAZAAR_W
	var h: int = FactorySim.BAZAAR_H
	# Skip the ruin on any world too small to hold its fixed-column footprint (cols 40-43): every other gen
	# pass in_bounds-guards its writes, but this one wrote at fixed columns unguarded → OOB on narrow worlds.
	# The ruin is the shipping-world spawn tutorial; a tiny world simply goes without rather than a partial frame.
	if ground - h < 0 or not world.in_bounds(Vector2i(RUIN_X + w - 1, ground + 3)):
		return
	for cx: int in range(RUIN_X, RUIN_X + w):                  # flatten + clear the footprint
		for ry: int in range(0, ground):
			world.blocks.erase(Vector2i(cx, ry))              # remove any bump / tree above the ground line
			world.walls.erase(Vector2i(cx, ry))              # ...and its back-wall, so the cleared area is open
			                                                 # SKY (no floating dirt wall above the flattened ruin)
		for ry: int in range(ground, ground + 4):
			var fc := Vector2i(cx, ry)
			var existing: StringName = world.blocks.get(fc, &"")
			# Solid ground to stand + build on — and CLEAR any buried tree stump (wood/leaves left under a
			# cleared canopy), so a finished bazaar never connects to orphan wood that could flood-fell it.
			if existing == &"" or existing == &"wood" or existing == &"leaves":
				world.blocks[fc] = &"earth"
				world.walls[fc] = &"dirt_wall"
	var o := Vector2i(RUIN_X, ground - h)                     # frame top-left
	var missing := o + Vector2i(w - 1, h - 1)                 # bottom-RIGHT post — the gap faces spawn (which is
	                                                          # RIGHT of the ruin), so the player walks up from the
	                                                          # hand-work side to place the finishing block, and ends
	                                                          # up on the shaft side (never walled off by the frame)
	for dx: int in w:
		world.blocks[o + Vector2i(dx, 0)] = &"wood"           # top beam
	for dy: int in range(1, h):                               # posts (both sides), minus the gap
		for px: int in [0, w - 1]:
			var c := o + Vector2i(px, dy)
			if c != missing:
				world.blocks[c] = &"wood"
		for ix: int in range(1, w - 1):                       # keep the interior open
			world.blocks.erase(o + Vector2i(ix, dy))
