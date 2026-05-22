extends Resource

class_name RewardInfo

const RARITY_UTIL := preload("res://data/LootRarity.gd")

@export var total_chip_value : int = 0
@export var item_id : String = ""
@export var item_level : int = 0
@export var module_scene: PackedScene
@export var module_level: int = 1
@export_enum("common", "rare", "epic") var rarity: String = "common"

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)
