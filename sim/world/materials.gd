class_name WorldMaterials
extends RefCounted

## Material registry: hardness by material id. `sim/world/MODULE.md`'s stated job ("material IDs,
## hardness") lives here, separate from `TileGrid`'s spatial storage -- one concept per file.
##
## Mirrors `data/materials/*.yaml` by hand. No runtime YAML loader exists yet (Godot ships none);
## `docs/DECISIONS_LEDGER.md` D0021 has the full reasoning and the options for fixing this properly.
## Each entry below names the file it mirrors -- if a value here and that file ever disagree, the
## `.yaml` is the source of truth and this table is the one that's wrong.

const HARDNESS: Dictionary = {
	&"clay": 1.0,        # data/materials/clay.yaml
	&"hardrock": 3.0,    # data/materials/hardrock.yaml
	&"deepstone": 5.0,   # data/materials/deepstone.yaml
	&"coal": 1.5,        # data/materials/coal.yaml
	&"ore_copper": 2.0,  # data/materials/ore_copper.yaml
	&"ore_iron": 3.5,    # data/materials/ore_iron.yaml
}


static func hardness(material_id: StringName) -> float:
	return float(HARDNESS.get(material_id, 0.0))


static func exists(material_id: StringName) -> bool:
	return HARDNESS.has(material_id)
