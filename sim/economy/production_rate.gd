class_name ProductionRate
extends RefCounted

## The production dashboard's number: how fast each item is being made right now, in items per minute,
## measured over a sliding window of `total_produced` snapshots. Lifted in A' step 3f (D0351) from
## `legacy/src/core/factory_sim.gd`: `_sample_production` 1959, `production_rate` 1969,
## `production_rates` 1983, `RATE_SAMPLE_TICKS`/`RATE_WINDOW_SAMPLES` 363-364.
##
## DERIVED, NOT SAVED (plan §4 step 3): a ring buffer of history the HUD reads, never state the sim
## acts on; it is not in any signature and a loaded game starts with an empty window, as legacy's
## did. Integers throughout: the rate is CENTI-items per minute (legacy's 8.2/min is 820), so the view
## formats and nothing here carries a float. Hand-mined bursts land in `total_produced` too, so the
## rate covers income by hand as well as by machine.

const SAMPLE_TICKS: int = 20      # one snapshot per simulated second at the hub's 20 Hz
const WINDOW_SAMPLES: int = 61    # ~60 s of history
## The hub's tick rate: `Body.TICK_HZ / HubTick.HUB_TICK_DIVISOR`, written here rather than read so
## `sim/economy` does not depend on `sim/run`; `tests/test_economy.gd` pins the identity.
const HUB_HZ: int = 20
const CENTI_PER_MINUTE: int = HUB_HZ * 60 * 100

var _tick: int = 0
var _samples: Array[Dictionary] = []   # each: {"tick": int, "totals": Dictionary}


## Push a `total_produced` snapshot once per SAMPLE_TICKS. Called at the end of every hub tick.
func sample(items: Items) -> void:
	_tick += 1
	if _tick % SAMPLE_TICKS != 0:
		return
	_samples.append({"tick": _tick, "totals": items.total_produced.duplicate()})
	while _samples.size() > WINDOW_SAMPLES:
		_samples.pop_front()


func sample_count() -> int:
	return _samples.size()


## How fast `item` is being produced, in CENTI-items per minute over the window. 0 until a second of
## history exists. Pure read on the ring buffer.
func rate_centi(items: Items, item: StringName) -> int:
	if _samples.is_empty():
		return 0
	var oldest: Dictionary = _samples[0]
	var span_ticks: int = _tick - int(oldest["tick"])
	if span_ticks < SAMPLE_TICKS:
		return 0
	var made: int = int(items.total_produced.get(item, 0)) - int((oldest["totals"] as Dictionary).get(item, 0))
	return made * CENTI_PER_MINUTE / span_ticks


## Every item with a live rate, fastest first, ties in text order: [{item, rate_centi}, ...]. The
## HUD's "making ore 8.2/min, ingot 4.1/min" summary reads this. Legacy listed `r > 0.05`; one unit
## inside a 1200-tick window is 100 centi, so that floor could never fire in integers and is "above 0".
func rates(items: Items) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in Ordering.ids(items.total_produced):
		var r: int = rate_centi(items, item)
		if r > 0:
			out.append({"item": item, "rate_centi": r})
	out.sort_custom(_faster_first)
	return out


static func _faster_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a["rate_centi"]) != int(b["rate_centi"]):
		return int(a["rate_centi"]) > int(b["rate_centi"])
	return Ordering.less(a["item"], b["item"])
