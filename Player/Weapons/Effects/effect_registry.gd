extends RefCounted
class_name EffectRegistry

const _SCENE_PATH_BY_ID := {
	"linear_movement": "res://Player/Weapons/Effects/linear_movement.tscn",
	"enemy_seek_steer": "res://Player/Weapons/Effects/enemy_seek_steer.tscn",
	"explosion_effect": "res://Player/Weapons/Effects/explosion_effect.tscn",
	"speed_change_on_hit": "res://Player/Weapons/Effects/speed_change_on_hit.tscn",
	"dmg_up_on_enemy_death": "res://Player/Weapons/Effects/dmg_up_on_enemy_death.tscn",
}

static var _scene_cache: Dictionary = {}

const _CONFIG_SCRIPT_BY_ID := {
	"linear_movement": preload("res://Player/Weapons/Effects/Configs/linear_movement_config.gd"),
	"enemy_seek_steer": preload("res://Player/Weapons/Effects/Configs/enemy_seek_steer_config.gd"),
	"explosion_effect": preload("res://Player/Weapons/Effects/Configs/explosion_effect_config.gd"),
	"speed_change_on_hit": preload("res://Player/Weapons/Effects/Configs/speed_change_on_hit_config.gd"),
	"dmg_up_on_enemy_death": preload("res://Player/Weapons/Effects/Configs/dmg_up_on_enemy_death_config.gd"),
}

# Returns true when the registry knows this effect id.
static func has_effect(effect_id: StringName) -> bool:
	return _SCENE_PATH_BY_ID.has(str(effect_id))

# Returns the scene for a known effect id, or null when unknown.
static func get_scene(effect_id: StringName) -> PackedScene:
	var key := str(effect_id)
	if _scene_cache.has(key):
		return _scene_cache[key] as PackedScene
	var scene_path := str(_SCENE_PATH_BY_ID.get(key, ""))
	if scene_path.is_empty():
		return null
	var loaded_scene := load(scene_path) as PackedScene
	if loaded_scene != null:
		_scene_cache[key] = loaded_scene
	return loaded_scene

# Returns all known effect ids for validation and editor helpers.
static func get_known_effect_ids() -> Array[StringName]:
	var output: Array[StringName] = []
	for key in _SCENE_PATH_BY_ID.keys():
		output.append(StringName(key))
	return output

# Creates a typed default EffectConfig instance for the requested effect id.
static func create_default_config(effect_id: StringName) -> EffectConfig:
	var script_ref: Script = _CONFIG_SCRIPT_BY_ID.get(str(effect_id), null)
	if script_ref == null:
		return null
	var config = script_ref.new()
	if config is EffectConfig:
		return config as EffectConfig
	return null
