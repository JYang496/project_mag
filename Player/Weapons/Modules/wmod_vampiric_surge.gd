extends Module
# Converts overkill damage into temporary bonus shield.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Vampiric Surge"

@export var conversion_ratio_lv1: float = 0.40
@export var conversion_ratio_lv2: float = 0.55
@export var conversion_ratio_lv3: float = 0.70
@export var min_shield_gain: int = 1
@export var shield_duration_sec: float = 4.0

var _active_shield_chunks: Array[Dictionary] = []

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_clear_all_shield()

func _physics_process(_delta: float) -> void:
	if _active_shield_chunks.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	for i in range(_active_shield_chunks.size() - 1, -1, -1):
		var chunk: Dictionary = _active_shield_chunks[i]
		if now_msec < int(chunk.get("expires_at_msec", 0)):
			continue
		var amount: int = max(0, int(chunk.get("amount", 0)))
		if amount > 0:
			PlayerData.bonus_shield = max(0, int(PlayerData.bonus_shield) - amount)
		_active_shield_chunks.remove_at(i)

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var hp_value: Variant = target.get("hp")
	if hp_value == null:
		return
	var current_hp: int = int(hp_value)
	if current_hp >= 0:
		return
	var overflow_damage: int = max(0, -current_hp)
	if overflow_damage <= 0:
		return
	var base_damage: int = UTILS.get_runtime_weapon_damage(source_weapon)
	if base_damage <= 0:
		return
	var overflow_ratio: float = clampf(float(overflow_damage) / float(base_damage), 0.0, 2.0)
	var gain_amount: int = int(round(float(overflow_damage) * _get_conversion_ratio() * overflow_ratio))
	gain_amount = max(max(0, min_shield_gain), gain_amount)
	if gain_amount <= 0:
		return
	PlayerData.bonus_shield += gain_amount
	_active_shield_chunks.append({
		"amount": gain_amount,
		"expires_at_msec": Time.get_ticks_msec() + int(maxf(shield_duration_sec, 0.1) * 1000.0),
	})

func _clear_all_shield() -> void:
	for chunk in _active_shield_chunks:
		var amount: int = max(0, int(chunk.get("amount", 0)))
		if amount > 0:
			PlayerData.bonus_shield = max(0, int(PlayerData.bonus_shield) - amount)
	_active_shield_chunks.clear()

func _get_conversion_ratio() -> float:
	match module_level:
		3:
			return maxf(0.0, conversion_ratio_lv3)
		2:
			return maxf(0.0, conversion_ratio_lv2)
		_:
			return maxf(0.0, conversion_ratio_lv1)
