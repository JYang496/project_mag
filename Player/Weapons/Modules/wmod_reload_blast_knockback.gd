extends Module
# Reloading pushes nearby enemies back based on spent ammo ratio.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reload Shockwave"

@export var radius: float = 175.0
@export var knockback_lv1: float = 150.0
@export var knockback_lv2: float = 210.0
@export var knockback_lv3: float = 280.0

func _exit_tree() -> void:
	super._exit_tree()

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(
			self, "detail.1", {}, "Reload shockwave knocks back nearby enemies"
		),
		LocalizationManager.get_module_detail(
			self, "detail.2", {}, "Knockback scales with spent ammo"
		),
	]))

func on_reload_started(_source_weapon: Weapon, detail: Dictionary) -> void:
	if detail == null or detail.get("source_weapon", null) != weapon:
		return
	var spent_ratio := UTILS.get_spent_ratio(detail)
	if spent_ratio <= 0.0:
		return
	var player := UTILS.resolve_player_node(weapon)
	if player == null or not is_instance_valid(player):
		return
	if not (player is Node2D):
		return
	var origin := (player as Node2D).global_position
	var tree := get_tree()
	if tree == null:
		return
	var knockback_amount := _get_knockback_amount() * spent_ratio
	for enemy in UTILS.get_nearby_enemies(tree, origin, radius):
		var direction := origin.direction_to(enemy.global_position)
		if direction == Vector2.ZERO:
			direction = Vector2.UP
		var damage_data := DamageManager.build_damage_data(
			weapon,
			0,
			Attack.TYPE_PHYSICAL,
			{"amount": knockback_amount, "angle": direction},
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.AREA
		)
		DamageManager.apply_to_target(enemy, damage_data)

func _get_knockback_amount() -> float:
	return UTILS.get_value_by_level(module_level, knockback_lv1, knockback_lv2, knockback_lv3)
