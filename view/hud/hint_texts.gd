class_name HintTexts
extends RefCounted

## THE LESSON TABLES (moved out of `Hints` in D0469 so the detectors keep under the size gate): the pack
## lessons a first pickup teaches, and the moments a state edge teaches. `Hints.DEFS` and `Hints.MOMENTS`
## alias these; every text is authored here and nowhere else. [BUILD]/[MINE]/[DROP]/[LINK] are the
## binding names `BindingLabels` fills at draw.

## The teachable items, scanned in order (order is priority when several fire on one frame). The drill
## belongs to the Objectives chain as its capstone; recipe machines need no bubble because drop in /
## product out is the verb that chain taught.
const DEFS: Array[Dictionary] = [
	{"id": &"rope", "item": &"rope", "text": "ROPE — set it above a drop. Climb it up and down; leap off."},
	{"id": &"torch", "item": &"torch", "text": "TORCH — set it on a wall-backed cell. Its light stays."},
	{"id": &"generator", "item": &"generator", "text": "GENERATOR — set it down with [BUILD], stand by it and press [DROP] with coal selected. It powers what is near."},
	{"id": &"conduit", "item": &"conduit", "text": "CONDUIT — lays a power line. Power flows down and sideways, never up."},
	{"id": &"hopper", "item": &"hopper", "text": "HOPPER — banks what falls in, meters it down. Its filter is the first thing it tastes."},
	{"id": &"lift", "item": &"lift", "text": "LIFT — hauls goods and YOU up its column."},
	{"id": &"pump", "item": &"pump", "text": "PUMP — set it in the wet. Powered, it drains the water under it."},
	{"id": &"winch_head", "item": &"winch_head", "text": "WINCH HEAD — the machine, not your line. Stand it on a lode with [BUILD], then [LINK] it to a Station. The vein climbs on its own."},
	{"id": &"winch_station", "item": &"winch_station", "text": "WINCH STATION — the head's drain. Collect from it."},
]

## State-edge hints: the rising edge fires once and latches like a pack hint. `in_water` sits above the
## swing techniques so a player who is wading is told about the pump before being told how to swing.
const MOMENTS: Array[Dictionary] = [
	{"id": &"too_far", "text": "TOO FAR — the red slashed square means the rock is past your reach. Your reach is about a body length: step closer, then hold [MINE]."},
	{"id": &"far_below", "text": "TOO FAR DOWN — what you point at lies under the ground, past your reach. Dig at the WHITE SQUARE first: the hole brings it into reach."},
	{"id": &"cut_through", "text": "CUT THROUGH — the rock under the pointer is gone. Point at what is left of the WHITE SQUARE: a hole has to be a little wider than you before you drop in."},
	{"id": &"aim_air", "text": "NOTHING THERE — the red slashed square is on open air: no rock under the pointer. Point at the rock or trunk itself; a trunk is thin, so aim at its middle."},
	{"id": &"build_far", "text": "TOO FAR — the ring is past your reach. Your reach is about a body length: step closer, then press [BUILD] on it."},
	{"id": &"build_here", "text": "STEP ASIDE — a machine cannot stand where you stand. Step out of the ring, then press [BUILD] on it."},
	{"id": &"build_rock", "text": "IN THE ROCK — a machine stands in the open, not inside rock. Point at the open metre in the WHITE RING, right above the vein, then press [BUILD]."},
	{"id": &"wrong_spot", "text": "WRONG SPOT — a Drill bores what is under it and pours that into what is under THAT: it belongs in the WHITE RING, over the vein, over the forge. Press [BUILD] on it to take it back."},
	{"id": &"aim_sight", "text": "BEHIND ROCK — that rock is in reach, but another rock is in the way of your pick. Cut the near one first, or point at a face you can see."},
	{"id": &"aim_machine", "text": "THAT IS A MACHINE — [MINE] cuts rock, not machines. Stand beside it and press [DROP] to feed it what it takes; what it makes comes to you as you stand there."},
	{"id": &"mined_wrong", "text": "NOT ORE — that was {broke}, and the task wants ore. The ore is the silver-flecked rock inside the WHITE RING: cut that one."},
	{"id": &"dropped_wrong", "text": "WRONG STACK — you dropped {dropped}; the machine beside you takes {wanted}. Press the number over the {wanted} in your bar to hold it, then [DROP]."},
	{"id": &"left_working", "text": "STILL WORKING — the forge has more of your ore in it, and what it makes comes to you only while you stand beside it. Step back and wait: {more} more coming."},
	{"id": &"dropped_floor", "text": "DROPPED — the stack fell at your feet, and you pick up what lies there as you stand. A machine takes a drop from within a body length, over it or beside it; the WHITE RING marks the one this step wants."},
	{"id": &"in_water", "text": "AQUIFER — water slows you. A POWERED PUMP drains it."},
	{"id": &"way_down", "text": "THE WAY DOWN — the ground is rock you can cut. Point at the ground under you and hold [MINE]: the metre opens and you drop into it. One metre at a time is a safe fall."},
	{"id": &"deep_enough", "text": "GRAPPLE — POINT at rock above you and press [GRAPPLE] to throw your line there. Hold [REEL] to climb it, press [GRAPPLE] again to let go and fly."},
	{"id": &"pump", "text": "PUMP IT — hold [REEL] at the bottom of the arc, [LOWER] at the top."},
	{"id": &"chain", "text": "CHAIN IT — press [GRAPPLE] again in mid-air to plant the next line, and the speed you left with is the speed you keep."},
	{"id": &"wrapped", "text": "THE LINE CAUGHT — it bent around the rock instead of through it. A short line whips you round harder."},
	{"id": &"hard_landing", "text": "HARD LANDING — a long drop costs your footing. A line fired on the way DOWN takes the fall instead of your legs."},
]
