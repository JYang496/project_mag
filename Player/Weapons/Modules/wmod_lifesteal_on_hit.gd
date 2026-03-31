extends Module
# Use on frequent-hit weapons to recover player HP when attacks connect.

var ITEM_NAME := "Life Steal"

@export var steal_ratio: float = 0.1
@export var minimum_heal: int = 1
@export var ratio_per_fuse: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

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
	final_ratio *= get_effective_additive(1.0, 0.35)
	var base_damage: int = 1
	if source_weapon:
		if source_weapon.has_method("get_runtime_shot_damage"):
			base_damage = max(1, int(source_weapon.call("get_runtime_shot_damage")))
		elif source_weapon.get("damage") != null:
			base_damage = max(1, int(source_weapon.damage))
	var min_heal_scaled: int = max(1, int(round(get_effective_additive(float(minimum_heal), 0.4))))
	var heal_amount: int = max(min_heal_scaled, int(round(float(base_damage) * final_ratio)))
	PlayerData.player_hp = min(PlayerData.player_max_hp, PlayerData.player_hp + heal_amount)
