class_name RevealMetric
extends RefCounted

## claims/C004's dig-rate-lift metric. Computed entirely from a per-tick event trace (tick index, whether
## a dig fired, and -- only on a tick where it did -- which material it revealed). Deliberately does NOT
## take feature location, a grid, or a site config as input anywhere in this file: the original framing
## of this claim ("does the player travel toward an unrevealed feature") was rejected as circular,
## because measuring it requires knowing where undiscovered features are -- something the player does not
## know either, and something an agent's decision policy must never be given
## (`docs/EXPERIENCE_EVALUATION.md`'s own Readiness Gate 6: an actor exposed to that kind of privileged
## state makes the whole evaluation `INVALID`). This metric only uses information that becomes available
## at the moment of a dig itself -- the same thing a human player sees the instant they dig it -- which is
## the anti-cheat property `docs/DECISIONS_LEDGER.md` D0109/`claims/C004` require stated explicitly.
##
## `WINDOW_TICKS` (300 = 5s at the fixed 60Hz tick rate) is a real, stated judgment call, not derived from
## data (`docs/DECISIONS_LEDGER.md` D0109) -- a plausible "immediate reaction to a discovery" timescale.
## If the first real measurement shows it's clearly wrong, it should move with a recorded reason, same as
## any other threshold in this project (`docs/CLAIMS.md` §9).

const WINDOW_TICKS: int = 300


## One tick's own dig outcome. `dug_material` is `&""` unless `dig_event` is true this same tick --
## mirrors `Body.dig_event_this_tick`/`dug_material_this_tick`'s own shape exactly, so a caller building
## this array from a live or replayed session can copy those two fields straight across.
class TickEvent:
	var dig_event: bool = false
	var dug_material: StringName = &""


## `events`: one `TickEvent` per tick of a session, in order, index == tick. `reveal_material`: which
## material counts as "a reveal" (`&"glimmer"` in practice) -- passed in, not hardcoded, so this file
## doesn't need to know about `data/materials/*.yaml` at all.
##
## Returns a Dictionary: `total_ticks`, `dig_events` (raw count, the whole point of "dig-events-per-
## session"), `qualifying_reveals` (reveal events with a FULL window on both sides -- one within
## WINDOW_TICKS of session start/end is excluded, not padded with a partial window, per claims/C004's own
## Falsifiable form), `mean_before_rate`, `mean_after_rate`, `lift` (after minus before; positive means
## digging picked up after a reveal, which is the claim's own pass condition). `lift` and both rates are
## `null` (GDScript: left absent from the dict) when `qualifying_reveals == 0` -- a session too short to
## produce even one qualifying reveal has nothing to average, and reporting 0.0 would misrepresent that
## as a measured null result rather than an insufficient sample.
static func compute(events: Array[TickEvent], reveal_material: StringName) -> Dictionary:
	var total_ticks: int = events.size()
	var dig_events: int = 0
	for e: TickEvent in events:
		if e.dig_event:
			dig_events += 1

	var reveal_ticks: Array[int] = []
	for t: int in total_ticks:
		if events[t].dig_event and events[t].dug_material == reveal_material:
			reveal_ticks.append(t)

	var before_rates: Array[float] = []
	var after_rates: Array[float] = []
	for t: int in reveal_ticks:
		if t - WINDOW_TICKS < 0 or t + WINDOW_TICKS >= total_ticks:
			continue  # not a full window on both sides -- excluded, not padded (claims/C004)
		var before_count: int = 0
		for i: int in range(t - WINDOW_TICKS, t):
			if events[i].dig_event:
				before_count += 1
		var after_count: int = 0
		for i: int in range(t + 1, t + WINDOW_TICKS + 1):
			if events[i].dig_event:
				after_count += 1
		before_rates.append(float(before_count) / float(WINDOW_TICKS))
		after_rates.append(float(after_count) / float(WINDOW_TICKS))

	var result: Dictionary = {
		"total_ticks": total_ticks,
		"dig_events": dig_events,
		"qualifying_reveals": before_rates.size(),
	}
	if before_rates.is_empty():
		return result
	var mean_before: float = _mean(before_rates)
	var mean_after: float = _mean(after_rates)
	result["mean_before_rate"] = mean_before
	result["mean_after_rate"] = mean_after
	result["lift"] = mean_after - mean_before
	return result


static func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())
