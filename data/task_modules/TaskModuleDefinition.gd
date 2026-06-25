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
	if display_name.strip_edges() != "":
		return display_name
	return module_id.replace("_", " ").capitalize()

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_reward_weight() -> float:
	return maxf(drop_weight, 0.0)

func get_task_label() -> String:
	match task_type:
		Cell.TaskType.OFFENSE:
			return "Kill"
		Cell.TaskType.DEFENSE:
			return "Hold"
		Cell.TaskType.CLEAR:
			return "Clear"
		Cell.TaskType.HUNT:
			return "Hunt"
		Cell.TaskType.DODGE:
			return "Dodge"
		_:
			return "None"
