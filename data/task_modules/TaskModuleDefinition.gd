extends Resource
class_name TaskModuleDefinition

const RARITY_UTIL := preload("res://data/LootRarity.gd")

@export var module_id: String = ""
@export_enum("NONE:0", "OFFENSE:1", "DEFENSE:2", "CLEAR:3", "HUNT:4", "DODGE:5")
var task_type: int = Cell.TaskType.NONE
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var unlock_level: int = 1
@export var drop_weight: float = 1.0

func get_display_name() -> String:
	var fallback := display_name if display_name.strip_edges() != "" else module_id.replace("_", " ").capitalize()
	return _translated("task_module.%s.name" % module_id, fallback)

func get_description() -> String:
	return _translated("task_module.%s.desc" % module_id, description.strip_edges())

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_reward_weight() -> float:
	return maxf(drop_weight, 0.0)

func get_task_label() -> String:
	match task_type:
		Cell.TaskType.OFFENSE:
			return _translated("ui.task_type.kill", "Kill")
		Cell.TaskType.DEFENSE:
			return _translated("ui.task_type.hold", "Hold")
		Cell.TaskType.CLEAR:
			return _translated("ui.task_type.clear", "Clear")
		Cell.TaskType.HUNT:
			return _translated("ui.task_type.hunt", "Hunt")
		Cell.TaskType.DODGE:
			return _translated("ui.task_type.dodge", "Dodge")
		_:
			return _translated("ui.task_type.none", "None")

func _translated(key: String, fallback: String) -> String:
	var translated := str(TranslationServer.translate(key))
	return fallback if translated == key else translated
