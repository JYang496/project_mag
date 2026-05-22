@tool
extends Resource
class_name WeaponDefinition

const RARITY_UTIL := preload("res://data/LootRarity.gd")

@export var weapon_id := ""
@export var display_name := ""
@export var icon: Texture2D
@export var price := 0
@export_multiline var description := ""
@export var scene: PackedScene
@export var is_hidden: bool = false
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export_range(0.0, 1000000.0, 0.01) var drop_weight: float = 100.0

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_drop_weight() -> float:
	return RARITY_UTIL.sanitize_weight(drop_weight, get_rarity())
