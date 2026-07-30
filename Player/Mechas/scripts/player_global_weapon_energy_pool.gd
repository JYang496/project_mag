extends RefCounted
class_name PlayerGlobalWeaponEnergyPool

const DEFAULT_MAX_ENERGY: float = 100.0
const DEFAULT_ATTACK_GAIN_CAP_RATIO: float = 0.50
const DEFAULT_SECOND_GAIN_CAP_RATIO: float = 0.75
const ATTACK_GAIN_RECORD_TTL_MSEC: int = 15000
const ATTACK_GROUP_META: StringName = &"_global_energy_attack_group"

var energy_value: float = 0.0
var max_energy: float = DEFAULT_MAX_ENERGY
var attack_gain_cap_ratio: float = DEFAULT_ATTACK_GAIN_CAP_RATIO
var second_gain_cap_ratio: float = DEFAULT_SECOND_GAIN_CAP_RATIO

var _gain_by_attack: Dictionary = {}
var _gain_window_started_msec: int = 0
var _gain_in_window: float = 0.0


func configure(
	max_value: float,
	per_attack_cap_ratio: float = DEFAULT_ATTACK_GAIN_CAP_RATIO,
	per_second_cap_ratio: float = DEFAULT_SECOND_GAIN_CAP_RATIO
) -> void:
	max_energy = maxf(max_value, 1.0)
	attack_gain_cap_ratio = clampf(per_attack_cap_ratio, 0.0, 1.0)
	second_gain_cap_ratio = clampf(per_second_cap_ratio, 0.0, 10.0)
	energy_value = clampf(energy_value, 0.0, max_energy)


func add_from_damage(raw_gain: float, source_attack: Node = null) -> float:
	var requested := maxf(raw_gain, 0.0)
	if requested <= 0.0 or energy_value >= max_energy:
		return 0.0
	_refresh_gain_window()
	var accepted := requested
	var attack_key: Variant = _resolve_attack_key(source_attack)
	var now_msec := Time.get_ticks_msec()
	if attack_key != null:
		var attack_cap := max_energy * attack_gain_cap_ratio
		var attack_record: Dictionary = _gain_by_attack.get(attack_key, {})
		var attack_gained := float(attack_record.get("amount", 0.0))
		accepted = minf(accepted, maxf(attack_cap - attack_gained, 0.0))
	var second_cap := max_energy * second_gain_cap_ratio
	accepted = minf(accepted, maxf(second_cap - _gain_in_window, 0.0))
	accepted = minf(accepted, maxf(max_energy - energy_value, 0.0))
	if accepted <= 0.0:
		return 0.0
	energy_value += accepted
	_gain_in_window += accepted
	if attack_key != null:
		var attack_record: Dictionary = _gain_by_attack.get(attack_key, {})
		_gain_by_attack[attack_key] = {
			"amount": float(attack_record.get("amount", 0.0)) + accepted,
			"last_seen_msec": now_msec,
		}
	return accepted


func consume_all() -> float:
	var consumed := maxf(energy_value, 0.0)
	energy_value = 0.0
	return consumed


func clear() -> void:
	energy_value = 0.0
	_gain_by_attack.clear()
	_gain_window_started_msec = 0
	_gain_in_window = 0.0


func get_ratio() -> float:
	if max_energy <= 0.0:
		return 0.0
	return clampf(energy_value / max_energy, 0.0, 1.0)


func _refresh_gain_window() -> void:
	var now_msec := Time.get_ticks_msec()
	if _gain_window_started_msec <= 0 or now_msec - _gain_window_started_msec >= 1000:
		_gain_window_started_msec = now_msec
		_gain_in_window = 0.0
		_prune_attack_gain_records(now_msec)


func _resolve_attack_key(source_attack: Node) -> Variant:
	if source_attack == null or not is_instance_valid(source_attack):
		return null
	if source_attack.has_meta(ATTACK_GROUP_META):
		return source_attack.get_meta(ATTACK_GROUP_META)
	return source_attack.get_instance_id()


func _prune_attack_gain_records(now_msec: int) -> void:
	for attack_key in _gain_by_attack.keys():
		var attack_record: Dictionary = _gain_by_attack.get(attack_key, {})
		var last_seen_msec := int(attack_record.get("last_seen_msec", 0))
		if last_seen_msec <= 0 or now_msec - last_seen_msec > ATTACK_GAIN_RECORD_TTL_MSEC:
			_gain_by_attack.erase(attack_key)
