class_name SignedPlane
extends RefCounted

## THE RUNNING-SIGNATURE PLANE, once. Every plane of sim state -- terrain, water, the placed layers, the
## deposits, the pack -- keeps D0261's two 32-bit XOR lanes and writes through the same sandwich (xor the
## old term out, write, xor the new term in). Four planes carried private copies of that by the end of
## A' step 3c and `tools/quality_check/duplication.py` refused the fourth; this is the one copy (D0348).
##
## A subclass implements `_term_of(key)` -- the two-lane term of the record at `key`, `Vector2i.ZERO`
## when there is no record -- and either writes through `_write_int` (one integer per key, erased at
## zero: water levels, pack counts) or wraps its own multi-field write between two `_xor_term` calls
## (`LogicGrid`, `DepositPlane`). `_lanes` is the signature, `_rebuilt` the from-scratch check that every
## suite runs after randomised mutation, and `_copy_lanes_from` is what a `clone()` carries.
##
## `TileGrid` is the pattern's origin and still stands on its own: its `_xor_term` also bumps
## `terrain_version` (D0340), and its golden is the one thing this file must not move.

var _sig_a: int = 0
var _sig_b: int = 0


## The record at `key` as a two-lane term, or ZERO when absent. Override.
func _term_of(_key: Variant) -> Vector2i:
	return Vector2i.ZERO


func _xor_term(t: Vector2i) -> void:
	_sig_a ^= t.x
	_sig_b ^= t.y


## The sandwich for a one-integer-per-key plane: a value at or below zero erases the record.
func _write_int(keyed: Dictionary, key: Variant, value: int) -> void:
	_xor_term(_term_of(key))
	if value <= 0:
		keyed.erase(key)
	else:
		keyed[key] = value
	_xor_term(_term_of(key))


func _lanes(prefix: String) -> String:
	return "%s%d:%d" % [prefix, _sig_a, _sig_b]


## The signature rebuilt from `keys` (every key that holds a record), for the self-check.
func _rebuilt(prefix: String, keys: Array) -> String:
	var a: int = 0
	var b: int = 0
	for key: Variant in keys:
		var t: Vector2i = _term_of(key)
		a ^= t.x
		b ^= t.y
	return "%s%d:%d" % [prefix, a, b]


func _copy_lanes_from(other: SignedPlane) -> void:
	_sig_a = other._sig_a
	_sig_b = other._sig_b


## A `clone()` in one call: duplicate each named dictionary plane into `copy` and carry the lanes.
func _clone_into(copy: SignedPlane, dictionaries: Array[StringName]) -> void:
	for name: StringName in dictionaries:
		copy.set(name, (get(name) as Dictionary).duplicate())
	copy._copy_lanes_from(self)
