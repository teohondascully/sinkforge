class_name StatusLook
extends RefCounted

## THE STATUS VOCABULARY (A' step 6b, D0363): what each of the sim's machine statuses looks like on the
## machine. Legacy `scenes/visuals.gd`'s `STATUS_LOOK`, `status_look`, `draw_status_mark` and
## `draw_fix_glyph`, with the rig's three dead statuses (`blocked_pay`, `blocked_spoil`,
## `blocked_station`) out of the table; `no_power` stays, because the winch reports it today. The observation's machine
## records carry the status as the sim's own `StringName`, and this maps it to a colour AND a mark.
##
## COLOUR ALONE WAS NEVER ENOUGH (legacy's audit 195): green working against red no-fuel is the single
## most common colour confusion there is, with amber starved joining them; for a deuteranope those three
## lamps were one lamp. So every status carries a MARK, chosen to differ in OUTLINE rather than detail,
## and either channel alone answers it.
##
##   mark   the silhouette drawn in the lamp.
##   fix    what the player would have to DO. Two statuses calling for different fixes must never share
##          a mark, or the lamp sends you to the wrong job; two calling for the same fix may share one
##          (`no_fuel` and `no_input` are both "put something in"; which something is the need bubble's).
##   feeds  whether a floating need bubble, which can only draw an ITEM, can tell the truth about this.

const LOOK: Dictionary = {
	&"working":  {"color": Color(0.35, 0.92, 0.42), "mark": &"disc",  "fix": &"none",     "feeds": false},
	&"idle":     {"color": Color(0.52, 0.55, 0.62), "mark": &"bar",   "fix": &"none",     "feeds": false},
	&"spent":    {"color": Color(0.46, 0.58, 0.78), "mark": &"ring",  "fix": &"relocate", "feeds": false},
	&"no_fuel":  {"color": Color(0.96, 0.26, 0.20), "mark": &"feed",  "fix": &"feed",     "feeds": true},
	&"no_input": {"color": Color(0.97, 0.72, 0.22), "mark": &"feed",  "fix": &"feed",     "feeds": true},
	&"no_power": {"color": Color(0.36, 0.84, 0.98), "mark": &"power", "fix": &"power",    "feeds": false},
	&"blocked":  {"color": Color(0.95, 0.45, 0.18), "mark": &"clear", "fix": &"clear",    "feeds": false},
	&"unlinked": {"color": Color(0.86, 0.40, 0.92), "mark": &"link",  "fix": &"link",     "feeds": false},
}


## The look of a status, falling back on idle's neutral bar for anything the table has not heard of. The
## fallback is a safety net and not a licence: `tests/test_looks.gd` pins every status the sim can
## return against this table, so a new one is caught by the suite rather than in play.
static func of(status: StringName) -> Dictionary:
	return LOOK.get(status, LOOK[&"idle"])


## The MARK, the geometry half of the redundant coding, centred at `c` with radius `r`.
##   disc   a full disc: complete and running        bar    a bar at rest
##   ring   hollow: the machine is fine, the vein is empty
##   feed   pointing UP, at the need bubble it is asking for
##   power  a diamond: the power motif, the one mark neither round nor square
##   clear  a hard stop: something behind this machine is jammed
##   link   a cross: placed, but joined to nothing
static func draw_mark(canvas: CanvasItem, c: Vector2, r: float, mark: StringName, col: Color) -> void:
	match mark:
		&"feed":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r),
				c + Vector2(r * 0.95, r * 0.72), c + Vector2(-r * 0.95, r * 0.72)]), col)
		&"clear":
			canvas.draw_rect(Rect2(c - Vector2(r, r) * 0.84, Vector2(r, r) * 1.68), col)
		&"ring":
			canvas.draw_arc(c, r * 0.78, 0.0, TAU, 14, col, maxf(1.0, r * 0.44))
		&"power":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
				c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)
		&"link":
			var a: float = r * 0.82
			var w: float = maxf(1.2, r * 0.40)
			canvas.draw_line(c + Vector2(-a, -a), c + Vector2(a, a), col, w)
			canvas.draw_line(c + Vector2(-a, a), c + Vector2(a, -a), col, w)
		&"bar":
			canvas.draw_rect(Rect2(c - Vector2(r * 0.92, r * 0.32), Vector2(r * 1.84, r * 0.64)), col)
		_:
			canvas.draw_circle(c, r, col)


## The FIX glyph: what to do about it, drawn `size` px tall. Power is a bolt, clear is a shovel over a
## bar, link is two rings reaching for each other.
static func draw_fix_glyph(canvas: CanvasItem, c: Vector2, size: float, fix: StringName, col: Color) -> void:
	var u: float = size * 0.5
	match fix:
		&"power":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(u * 0.22, -u * 0.95), c + Vector2(-u * 0.62, u * 0.12),
				c + Vector2(-u * 0.06, u * 0.12), c + Vector2(-u * 0.22, u * 0.95),
				c + Vector2(u * 0.62, -u * 0.12), c + Vector2(u * 0.06, -u * 0.12)]), col)
		&"clear":
			canvas.draw_rect(Rect2(c + Vector2(-u * 0.78, u * 0.52), Vector2(u * 1.56, u * 0.30)), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, u * 0.30), c + Vector2(-u * 0.66, -u * 0.42),
				c + Vector2(-u * 0.30, -u * 0.42), c + Vector2(0.0, -u * 0.10),
				c + Vector2(u * 0.30, -u * 0.42), c + Vector2(u * 0.66, -u * 0.42)]), col)
		&"link":
			var w: float = maxf(1.4, u * 0.26)
			canvas.draw_arc(c + Vector2(-u * 0.46, 0.0), u * 0.44, -PI * 0.45, PI * 0.45, 10, col, w)
			canvas.draw_arc(c + Vector2(-u * 0.46, 0.0), u * 0.44, PI * 0.55, PI * 1.45, 10, col, w)
			canvas.draw_arc(c + Vector2(u * 0.46, 0.0), u * 0.44, PI * 0.55, PI * 1.45, 10, col, w)
			canvas.draw_arc(c + Vector2(u * 0.46, 0.0), u * 0.44, -PI * 0.45, PI * 0.45, 10, col, w)
		&"feed":
			draw_mark(canvas, c, u * 0.8, &"feed", col)
		&"relocate":
			draw_mark(canvas, c, u * 0.8, &"ring", col)
		_:
			pass
