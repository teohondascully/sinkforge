class_name Art
extends RefCounted

## Drop-in sprite loader. Returns a Texture2D for a logical key if its PNG exists
## under assets/sprites/, else null so the caller falls back to its code-drawn primitive. Caches lookups
## (including misses) so a missing file is probed once. This is the seam that lets the user add art
## incrementally without touching draw code: no PNG → today's primitives; PNG present → their art.

const DIR: String = "res://assets/sprites/"

static var _cache: Dictionary = {}                   ## key -> Texture2D or null (miss)


## Texture for a logical key (e.g. "miner", "machine_processor", "item_ore", "tile_earth"), or null.
static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = DIR + key + ".png"
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[key] = t
	return t


## True if any sprite art exists at all (lets a renderer keep its pure-primitive path until art lands).
static func has_any() -> bool:
	return tex("miner") != null or tex("machine_processor") != null
