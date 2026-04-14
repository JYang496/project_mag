extends Module
# Reloading deals one burst of damage around the player based on spent ammo ratio.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reload Burst"

@export var radius: float = 175.0
@export var damage_ratio_lv1: float = 0.65
@export var damage_ratio_lv2: float = 0.85
@export var damage_ratio_lv3: float = 1.10
@export var damage_type: StringName = Attack.TYPE_PHYSICAL

var _registered: bool = false

func _enter_tree() -> void:
	super._enter_tree()
	_register_hook()

func _ready() -> void:
	_register_hook()

func _exit_tree() -> void:
	_unregister_hook()

func get_effect_descriptions() -> PackedStringArray:
	return PackedStringArray([
		"Reload burst damages nearby enemies",
		"Damage scales with spent ammo",
	])

func _register_hook() -> void:
	if _registered:
		return
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.passive_triggered.is_connected(_on_weapon_passive_triggered):
		_registered = true
		return
	weapon.passive_triggered.connect(_on_weapon_passive_triggered)
	_registered = true

func _unregister_hook() -> void:
	if not _registered:
		return
	if weapon != null and is_instance_valid(weapon) and weapon.passive_triggered.is_connected(_on_weapon_passive_triggered):
		weapon.passive_triggered.disconnect(_on_weapon_passive_triggered)
	_registered = false

func _on_weapon_passive_triggered(event_name: StringName, detail: Dictionary) -> void:
	if event_name != &"on_reload_started":
		return
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
	var tree := get_tree()
	if tree == null:
		return
	var burst_damage: int = max(1, int(round(float(UTILS.get_runtime_weapon_damage(weapon)) * _get_damage_ratio() * spent_ratio)))
	for enemy in UTILS.get_nearby_enemies(tree, (player as Node2D).global_position, radius):
		var damage_data := DamageManager.build_damage_data(
			weapon,
			burst_damage,
			Attack.normalize_damage_type(damage_type),
			{"amount": 0.0, "angle": Vector2.ZERO}
		)
		DamageManager.apply_to_target(enemy, damage_data)

func _get_damage_ratio() -> float:
	return UTILS.get_value_by_level(module_level, damage_ratio_lv1, damage_ratio_lv2, damage_ratio_lv3)
