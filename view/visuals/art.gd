class_name Art
extends RefCounted

## Drop-in sprite loader. Returns a Texture2D for a logical key if its PNG exists under
## `assets/sprites/`, else null so the caller falls back to its code-drawn primitive. Lookups are cached
## including misses, so a missing file is probed once and art can land one sprite at a time without
## touching draw code.
##
## Lifted unchanged from `legacy/scenes/art.gd` (`docs/DECISIONS_LEDGER.md` D0227).
##
## **ART HAS LANDED (D0268).** `assets/sprites/` holds 16 authored 32x48 miner PNGs, copied from
## `legacy/assets/sprites/`, and `view/visuals/miner_look.gd` is this file's first consumer. Both
## sentences replace the opposite claim that stood here from D0227 until 2026-08-31 -- that the directory
## did not exist and nothing called `tex()`. Correct when written, and left here in this form on purpose:
## a loader pointed at a missing directory is indistinguishable from a broken loader unless somebody
## writes down which one it is, and the same is true in reverse once the files arrive.
##
## The miss path is still the designed contract and is still exercised: any key with no PNG returns null,
## the miss is cached, and the caller keeps its own code-drawn primitive. `tests/test_view_lifts.gd` now
## asserts BOTH directions, where before it could only assert the miss.
##
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
