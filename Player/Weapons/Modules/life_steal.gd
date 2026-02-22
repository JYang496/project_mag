extends Module

var ITEM_NAME := "Life Steal"

@export var steal_ratio: float = 0.1
@export var minimum_heal: int = 1
@export var ratio_per_fuse: float = 0.0

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if PlayerData.player == null:
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var final_ratio: float = maxf(0.0, steal_ratio + ratio_per_fuse * float(fuse_bonus_steps))
	var base_damage: int = 1
	if source_weapon and source_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon.damage))
	var heal_amount: int = max(minimum_heal, int(round(float(base_damage) * final_ratio)))
	PlayerData.player_hp = min(PlayerData.player_max_hp, PlayerData.player_hp + heal_amount)
