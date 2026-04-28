extends RefCounted
class_name PlayerStatusModifierSystem

var _player
var _player_data: Node = null
var _move_speed_mul_modifiers: Dictionary = {}
var _vision_mul_modifiers: Dictionary = {}
var _damage_mul_modifiers: Dictionary = {}
var _low_hp_damage_modifiers: Dictionary = {}
var _bonus_hit_modifiers: Dictionary = {}
var _loot_bonus_modifiers: Dictionary = {}

func setup(player) -> void:
	_player = player
	if _player != null and is_instance_valid(_player):
		_player_data = _player.get_node_or_null("/root/PlayerData")

func apply_move_speed_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := clampf(mul, 0.05, 10.0)
	_move_speed_mul_modifiers[source_id] = clamped_mul
	_notify(&"move_speed_up" if clamped_mul >= 1.0 else &"move_speed_down", source_id, true)

func remove_move_speed_mul(source_id: StringName) -> void:
	if _move_speed_mul_modifiers.has(source_id):
		var prev_mul := float(_move_speed_mul_modifiers.get(source_id, 1.0))
		_move_speed_mul_modifiers.erase(source_id)
		_notify(&"move_speed_up" if prev_mul >= 1.0 else &"move_speed_down", source_id, false)

func get_total_move_speed_mul() -> float:
	var total := 1.0
	for mul in _move_speed_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func apply_vision_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := clampf(mul, 0.05, 10.0)
	_vision_mul_modifiers[source_id] = clamped_mul
	_notify(&"vision_up" if clamped_mul >= 1.0 else &"vision_down", source_id, true)

func remove_vision_mul(source_id: StringName) -> void:
	if _vision_mul_modifiers.has(source_id):
		var prev_mul := float(_vision_mul_modifiers.get(source_id, 1.0))
		_vision_mul_modifiers.erase(source_id)
		_notify(&"vision_up" if prev_mul >= 1.0 else &"vision_down", source_id, false)

func get_total_vision_mul() -> float:
	var total := 1.0
	for mul in _vision_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func apply_damage_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := maxf(mul, 0.05)
	_damage_mul_modifiers[source_id] = clamped_mul
	_notify(&"damage_up" if clamped_mul >= 1.0 else &"damage_down", source_id, true)

func remove_damage_mul(source_id: StringName) -> void:
	if _damage_mul_modifiers.has(source_id):
		var prev_mul := float(_damage_mul_modifiers.get(source_id, 1.0))
		_damage_mul_modifiers.erase(source_id)
		_notify(&"damage_up" if prev_mul >= 1.0 else &"damage_down", source_id, false)

func register_low_hp_damage_bonus(source_id: StringName, min_hp_ratio: float, max_damage_mul: float) -> void:
	if source_id == StringName():
		return
	_low_hp_damage_modifiers[source_id] = {
		"min_hp_ratio": clampf(min_hp_ratio, 0.05, 1.0),
		"max_damage_mul": maxf(max_damage_mul, 1.0)
	}

func remove_low_hp_damage_bonus(source_id: StringName) -> void:
	if _low_hp_damage_modifiers.has(source_id):
		_low_hp_damage_modifiers.erase(source_id)

func register_bonus_hit(source_id: StringName, chance: float, damage: int) -> void:
	if source_id == StringName():
		return
	_bonus_hit_modifiers[source_id] = {
		"chance": clampf(chance, 0.0, 1.0),
		"damage": max(1, damage)
	}

func remove_bonus_hit(source_id: StringName) -> void:
	if _bonus_hit_modifiers.has(source_id):
		_bonus_hit_modifiers.erase(source_id)

func register_loot_bonus(source_id: StringName, coin_chance: float, chip_chance: float, multiplier: int) -> void:
	if source_id == StringName():
		return
	_loot_bonus_modifiers[source_id] = {
		"coin_chance": clampf(coin_chance, 0.0, 1.0),
		"chip_chance": clampf(chip_chance, 0.0, 1.0),
		"multiplier": max(2, multiplier)
	}

func remove_loot_bonus(source_id: StringName) -> void:
	if _loot_bonus_modifiers.has(source_id):
		_loot_bonus_modifiers.erase(source_id)

func compute_outgoing_damage(base_damage: int) -> int:
	var total_mul_delta := 0.0
	for mul in _damage_mul_modifiers.values():
		total_mul_delta += (float(mul) - 1.0)
	total_mul_delta += (_get_low_hp_damage_mul() - 1.0)
	var final_mul := maxf(0.0, 1.0 + total_mul_delta)
	return max(1, int(round(float(base_damage) * final_mul)))

func get_low_hp_damage_mul() -> float:
	return _get_low_hp_damage_mul()

func apply_bonus_hit_if_needed(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	for data in _bonus_hit_modifiers.values():
		var chance: float = float(data.get("chance", 0.0))
		var bonus_damage: int = int(data.get("damage", 1))
		if randf() <= chance:
			var bonus_attack := Attack.new()
			bonus_attack.damage = max(1, bonus_damage)
			bonus_attack.damage_type = Attack.TYPE_PHYSICAL
			bonus_attack.source_node = _player
			bonus_attack.source_player = _player
			target.damaged(bonus_attack)

func apply_loot_bonus(value: int, loot_type: StringName) -> int:
	var result: int = max(0, value)
	for data in _loot_bonus_modifiers.values():
		var chance: float = 0.0
		if loot_type == &"coin":
			chance = float(data.get("coin_chance", 0.0))
		elif loot_type == &"chip":
			chance = float(data.get("chip_chance", 0.0))
		if chance <= 0.0:
			continue
		if randf() <= chance:
			var multiplier: int = int(data.get("multiplier", 2))
			result *= max(2, multiplier)
	return result

func _get_low_hp_damage_mul() -> float:
	if _low_hp_damage_modifiers.is_empty():
		return 1.0
	if _player_data == null or not is_instance_valid(_player_data):
		return 1.0
	var max_hp: float = maxf(float(_player_data.player_max_hp), 1.0)
	var hp_ratio: float = float(_player_data.player_hp) / max_hp
	var best_mul := 1.0
	for data in _low_hp_damage_modifiers.values():
		var min_ratio: float = clampf(float(data.get("min_hp_ratio", 0.25)), 0.05, 1.0)
		var max_mul: float = maxf(float(data.get("max_damage_mul", 1.0)), 1.0)
		if hp_ratio >= 1.0:
			continue
		var factor: float = clampf((1.0 - hp_ratio) / maxf(1.0 - min_ratio, 0.001), 0.0, 1.0)
		var computed_mul: float = lerpf(1.0, max_mul, factor)
		if computed_mul > best_mul:
			best_mul = computed_mul
	return best_mul

func _notify(stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("_notify_status_hint"):
		_player.call("_notify_status_hint", &"player", stat_type, source_id, is_gain)
