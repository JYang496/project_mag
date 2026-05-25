extends Resource

class_name RewardInfo

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const KIND_STANDARD: StringName = &"standard"
const KIND_WEAPON_UPGRADE: StringName = &"weapon_upgrade"
const KIND_ECONOMY: StringName = &"economy"

@export var total_chip_value : int = 0
@export var item_id : String = ""
@export var item_level : int = 0
@export var module_scene: PackedScene
@export var module_level: int = 1
@export var gold_value: int = 0
@export_enum("common", "rare", "epic") var rarity: String = "common"
var reward_kind: StringName = KIND_STANDARD
var reward_key_override: String = ""
var target_weapon_ref: WeakRef
var target_weapon_id: String = ""
var target_weapon_name: String = ""
var target_weapon_from_level: int = 0
var target_weapon_to_level: int = 0

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func configure_weapon_upgrade(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	reward_kind = KIND_WEAPON_UPGRADE
	target_weapon_ref = weakref(weapon)
	target_weapon_id = DataHandler.get_weapon_id_from_instance(weapon)
	target_weapon_name = LocalizationManager.get_weapon_name_from_node(weapon)
	target_weapon_from_level = int(weapon.level)
	target_weapon_to_level = mini(int(weapon.level) + 1, int(weapon.max_level))
	reward_key_override = "upgrade:%s" % str(weapon.get_instance_id())

func get_target_weapon() -> Weapon:
	if target_weapon_ref == null:
		return null
	return target_weapon_ref.get_ref() as Weapon
