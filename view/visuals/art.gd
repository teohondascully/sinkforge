class_name Art
extends RefCounted

## Drop-in sprite loader. Returns a Texture2D for a logical key if its PNG exists under
## `assets/sprites/`, else null so the caller falls back to its code-drawn primitive. Lookups are cached
## including misses, so a missing file is probed once and art can land one sprite at a time without
## touching draw code.
##
## Lifted unchanged from `legacy/scenes/art.gd` (`docs/DECISIONS_LEDGER.md` D0227).
##
## **`res://assets/` DOES NOT EXIST IN THIS TREE, and that is this file's designed state, not a defect.**
## Every `tex()` returns null and `has_any()` returns false, which is exactly the contract: a renderer
## keeps its pure-primitive path until real art lands. Said out loud because a loader pointed at a
## missing directory is indistinguishable from a broken loader unless somebody writes down which one it
## is -- and because the negative case is the ONLY one this build can currently test, so
## `tests/test_art.gd` measures the caching and the fallback, and cannot measure a hit.
##
## NO CONSUMER TODAY. Nothing in `view/` calls it. It is the seam the director's art pass lands through,
## ported while it is 26 lines and provably inert.

const DIR: String = "res://assets/sprites/"

static var _cache: Dictionary = {}                   ## key -> Texture2D or null (miss)


## Texture for a logical key (e.g. "miner", "machine_processor", "item_ore", "tile_earth"), or null.
static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = DIR + key + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[key] = texture
	return texture


## True if any sprite art exists at all, so a renderer can keep its pure-primitive path until it does.
static func has_any() -> bool:
	return tex("miner") != null or tex("machine_processor") != null


## Drops every cached lookup, including the misses. Exists for tests: the cache is `static`, so one
## suite's probe of a missing key would otherwise decide a later one's answer.
static func clear_cache() -> void:
	_cache.clear()
