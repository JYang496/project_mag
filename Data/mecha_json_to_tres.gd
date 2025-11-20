@tool
extends Node
const SOURCE := "res://data/mechas.json"
const TARGET_DIR := "res://data/mechas"

# Script to convert mechas.json into seperated files in data/mechas/
func _ready():
	var file := FileAccess.open(SOURCE, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(typeof(parsed) == TYPE_DICTIONARY)
	DirAccess.make_dir_recursive_absolute(TARGET_DIR)
	for id in parsed.keys():
		var src: Dictionary = parsed[id]
		var def := MechaDefinition.new()
		def.mecha_id = id
		def.display_name = src.get("name", "")
		def.scene = load(src.get("res", ""))
		def.max_level = int(src.get("max_level", "1"))
		def.next_level_exp = PackedInt32Array(_as_ints(src["next_level_exp"]))
		def.player_max_hp = PackedInt32Array(_as_ints(src["player_max_hp"]))
		def.player_speed = PackedFloat32Array(_as_floats(src["player_speed"]))
		def.armor = PackedInt32Array(_as_ints(src.get("armor", [])))
		def.shield = PackedInt32Array(_as_ints(src.get("shield", [])))
		def.hp_regen = PackedFloat32Array(_as_floats(src.get("hp_regen", [])))
		def.damage_reduction = PackedFloat32Array(_as_floats(src.get("damage_reduction", [])))
		def.crit_rate = PackedFloat32Array(_as_floats(src.get("crit_rate", [])))
		def.crit_damage = PackedFloat32Array(_as_floats(src.get("crit_damage", [])))
		def.grab_radius = PackedFloat32Array(_as_floats(src.get("grab_radius", [])))
		def.player_gold = PackedInt32Array(_as_ints(src.get("player_gold", [])))
		var save_path := "%s/%s.tres" % [TARGET_DIR, def.display_name]
		var err := ResourceSaver.save(def, save_path)
		assert(err == OK, "Failed to save %s" % save_path)

func _as_ints(items: Array) -> Array:
	return items.map(func(v): return int(v))

func _as_floats(items: Array) -> Array:
	return items.map(func(v): return float(v))
