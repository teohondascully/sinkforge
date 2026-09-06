extends "res://tests/test_base.gd"

## THE BEACON PROBE RECORD (D0407): `data/starts/beacon_probe.yaml` stands a processor with nothing to
## process sixty metres down a floored corridor, so the status beacon (T014, D0401) can be witnessed in the
## dark it was built for -- no start of play puts a machine underground. The capture is the witness
## (`tests/body/recordings/round15_2026-09-06/beacon/`, read by `tools/capture_probe.gd`); this suite is the
## mechanism the witness stands on: the record stamps, the machine is where the record says and STARVED,
## the seat's `--start=` flag picks the record, a body at the documented warp is ten metres from it with the
## lamp's beam short of it, the observation from there carries the machine, and the veil's sources emit its
## beacon cut in the status colour. A control record with the machine fed emits none.

const SEED: int = 20260826
const WARP := Vector2i(144, 328)             # the record's own documented warp, terrain cells
const MACHINE_LOGIC := Vector2i(32 + 14, 20 + 62)   # spawn_col_m + dx, SURFACE_ROW_M + dy


func _initialize() -> void:
	_test_the_record_stamps_a_starved_processor_ten_metres_from_the_warp()
	_test_the_seat_flag_picks_the_record()
	_finish("beacon_probe")


func _test_the_record_stamps_a_starved_processor_ten_metres_from_the_warp() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"beacon_probe")
	_check(door != null and WorldSeeder.last_refusal.is_empty(), "the record stamps onto the shaped world (%s)" % WorldSeeder.last_refusal)
	if door == null:
		return
	var world: World = door.services()["world"]
	var machines: Machines = door.services()["machines"]
	var m: MachineState = machines.machine_at(MACHINE_LOGIC)
	_check(m != null and m.def.id == &"processor", "a processor stands at logic %s" % [MACHINE_LOGIC])
	if m == null:
		return
	var status: StringName = MachineStatus.of(m, world, machines)
	_check(status == &"no_input", "and it is starved: status %s" % status)
	_check(StatusLook.of(status).fix != &"none", "a starved status is one the veil beacons (fix %s)" % StatusLook.of(status).fix)
	var body: Body = door.services()["body"]
	var cell_px: int = Interface.Observation.CELL_PX
	var feet: Vector2i = SeatFlags.stand_near(world.grid, WARP, (Body.HEIGHT_PX + cell_px - 1) / cell_px + 1)
	_check(feet != SeatFlags.NO_WARP and feet.y == 331, "the warp finds the corridor's floor at %s" % [feet])
	body.place((feet.x * cell_px + cell_px / 2) * Fx.SCALE, ((feet.y + 1) * cell_px - Body.HEIGHT_PX / 2) * Fx.SCALE)
	var body_m: float = float(body.pos_x) / float(Fx.SCALE) / float(Interface.Observation.CELL_PX * MaterialLook.CELLS_PER_METRE)
	var machine_m: float = float(MACHINE_LOGIC.x) + 0.5
	var apart: float = machine_m - body_m
	_check(apart > 9.5 and apart < 10.5 and apart > VeilPainter.LAMP_BEAM_M,
		"the machine is %.2f m from the body, past the lamp's %.1f m beam: whatever lights it is its own" % [apart, VeilPainter.LAMP_BEAM_M])
	var obs: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var carried: bool = false
	for rec: Dictionary in obs.machines:
		if rec["cell"] == MACHINE_LOGIC and rec["status"] == &"no_input":
			carried = true
	_check(carried, "the observation from the warp carries the starved machine")
	var cuts: Array[Dictionary] = VeilSources.cuts(obs, [], [], 0.0, Rect2(0, 0, 1e6, 1e6))
	var beacon: Dictionary = {}
	var at: Vector2 = Vector2(MACHINE_LOGIC) * float(LogicGrid.TERRAIN_PER_LOGIC) + Vector2.ONE * float(LogicGrid.TERRAIN_PER_LOGIC) * 0.5
	for c: Dictionary in cuts:
		if Vector2(c["centre"]).distance_to(at) < 0.01 and absf(float(c["radius"]) - VeilSources.BEACON_R_M * VeilSources.PER_M) < 0.01:
			beacon = c
	_check(not beacon.is_empty(), "the veil's sources emit the beacon cut at the machine, radius %.1f m" % VeilSources.BEACON_R_M)
	if not beacon.is_empty():
		var tint: Color = beacon["tint"]
		_check(tint.r > tint.b, "in the status colour: amber over blue (r %.2f, b %.2f)" % [tint.r, tint.b])


## Positive control for the pin above: the same corridor with the processor FED reads `working` and the
## veil emits no beacon for it -- so a beacon found above is the status's, not every machine's.
func _test_the_seat_flag_picks_the_record() -> void:
	_check(SeatFlags.start_id({"start": "beacon_probe"}, &"tutorial") == &"beacon_probe", "--start=beacon_probe picks the record")
	_check(SeatFlags.start_id({"start": "no_such_record"}, &"tutorial") == &"tutorial" and SeatFlags.start_id({}, &"tutorial") == &"tutorial",
		"an unknown or absent --start falls back to the seat's own start")
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"beacon_probe")
	if door == null:
		return
	var world: World = door.services()["world"]
	var machines: Machines = door.services()["machines"]
	var m: MachineState = machines.machine_at(MACHINE_LOGIC)
	var fed: int = 0
	for input_id: StringName in m.def.recipe.inputs:
		m.input_buffer[input_id] = int(m.def.recipe.inputs[input_id])
		fed += 1
	var status: StringName = MachineStatus.of(m, world, machines)
	_check(fed > 0 and StatusLook.of(status).fix == &"none", "control: fed (%d inputs), the same processor reads %s and wants nothing" % [fed, status])
	var obs: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var cuts: Array[Dictionary] = VeilSources.cuts(obs, [], [], 0.0, Rect2(0, 0, 1e6, 1e6))
	var beacons: int = 0
	for c: Dictionary in cuts:
		if absf(float(c["radius"]) - VeilSources.BEACON_R_M * VeilSources.PER_M) < 0.01:
			beacons += 1
	_check(beacons == 0, "and the veil emits no beacon cut for it (%d)" % beacons)
