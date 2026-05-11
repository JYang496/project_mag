extends RefCounted
class_name PlayerSharedHeatSystem

var _player
var _shared_heat_pool: SharedHeatPool
var _shared_heat_signature: String = ""
var _last_heat_decay_weapon_id: int = 0
var _last_heat_decay_rate: float = 0.0
var _last_heat_decay_source_name: String = "None"
var _selected_heat_decay_rate: float = 0.0
var _selected_heat_decay_source_name: String = "None"
var _heat_stabilized_decay_mul: float = 1.0

func setup(player) -> void:
	_player = player
	if _shared_heat_pool == null:
		_shared_heat_pool = SharedHeatPool.new() as SharedHeatPool
		if _shared_heat_pool == null:
			push_warning("Failed to initialize SharedHeatPool.")
			return
	if _player != null and _player.has_method("get_heat_gain_multiplier"):
		_shared_heat_pool.heat_gain_multiplier_provider = Callable(_player, "get_heat_gain_multiplier")
	rebuild()

func tick(delta: float) -> void:
	if _shared_heat_pool == null or _player == null:
		return
	var next_signature := _build_signature()
	if next_signature != _shared_heat_signature:
		_shared_heat_signature = next_signature
		rebuild()
	var selected_rate := _resolve_selected_decay_rate()
	_heat_stabilized_decay_mul = 1.0
	if _player.has_method("get_heat_stabilized_decay_mul"):
		_heat_stabilized_decay_mul = maxf(float(_player.call("get_heat_stabilized_decay_mul")), 0.0)
	var effective_rate := selected_rate * _heat_stabilized_decay_mul
	if _shared_heat_pool.has_method("cool_down_at_rate"):
		_shared_heat_pool.call("cool_down_at_rate", delta, effective_rate)
	else:
		_shared_heat_pool.cool_down(delta)

func rebuild() -> void:
	if _shared_heat_pool == null or _player == null or _player.PlayerData == null:
		return
	_shared_heat_pool.configure_from_weapons(_player.PlayerData.player_weapon_list)
	_shared_heat_signature = _build_signature()

func mark_dirty() -> void:
	_shared_heat_signature = ""

func get_pool() -> SharedHeatPool:
	return _shared_heat_pool

func get_total_heat_value() -> float:
	if _shared_heat_pool == null:
		return 0.0
	return float(_shared_heat_pool.heat_value)

func get_total_heat_max() -> float:
	if _shared_heat_pool == null or not _shared_heat_pool.has_contributors():
		return 0.0
	return float(_shared_heat_pool.max_heat)

func get_total_heat_ratio() -> float:
	if _shared_heat_pool == null or not _shared_heat_pool.has_contributors():
		return 0.0
	return _shared_heat_pool.get_ratio()

func get_selected_heat_decay_rate() -> float:
	return _selected_heat_decay_rate

func get_selected_heat_decay_source_name() -> String:
	return _selected_heat_decay_source_name

func get_last_heat_decay_source_name() -> String:
	return _last_heat_decay_source_name

func get_heat_stabilized_decay_mul() -> float:
	return _heat_stabilized_decay_mul

func get_effective_heat_decay_rate() -> float:
	return _selected_heat_decay_rate * _heat_stabilized_decay_mul

func _resolve_selected_decay_rate() -> float:
	var current_main := _get_current_main_weapon()
	if _weapon_has_heat_trait(current_main):
		_last_heat_decay_weapon_id = current_main.get_instance_id()
		_last_heat_decay_rate = _get_weapon_heat_cool_rate(current_main)
		_last_heat_decay_source_name = _get_weapon_display_name(current_main)
		_selected_heat_decay_rate = _last_heat_decay_rate
		_selected_heat_decay_source_name = _last_heat_decay_source_name
		return _selected_heat_decay_rate
	if not _is_last_decay_source_valid():
		_clear_last_decay_source()
	_selected_heat_decay_rate = _last_heat_decay_rate
	_selected_heat_decay_source_name = _last_heat_decay_source_name
	return _selected_heat_decay_rate

func _get_current_main_weapon() -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	if _player.has_method("get_main_weapon"):
		return _player.call("get_main_weapon") as Node
	if _player.PlayerData == null:
		return null
	var weapons: Array = _player.PlayerData.player_weapon_list
	if weapons.is_empty():
		return null
	var idx: int = clampi(int(_player.PlayerData.main_weapon_index), 0, weapons.size() - 1)
	return weapons[idx] as Node

func _weapon_has_heat_trait(weapon: Node) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if weapon.has_method("has_heat_trait"):
		return bool(weapon.call("has_heat_trait"))
	if weapon.has_method("has_heat_system"):
		return bool(weapon.call("has_heat_system"))
	return false

func _get_weapon_heat_cool_rate(weapon: Node) -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 0.0
	var rate_variant: Variant = weapon.get("heat_cool_rate")
	if rate_variant == null:
		return 0.0
	return maxf(float(rate_variant), 0.0)

func _get_weapon_display_name(weapon: Node) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return "None"
	var item_name: Variant = weapon.get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		return str(item_name)
	return weapon.name

func _is_last_decay_source_valid() -> bool:
	if _last_heat_decay_weapon_id == 0:
		return false
	if _player == null or _player.PlayerData == null:
		return false
	for weapon in _player.PlayerData.player_weapon_list:
		var node := weapon as Node
		if node != null and is_instance_valid(node) and node.get_instance_id() == _last_heat_decay_weapon_id:
			return true
	return false

func _clear_last_decay_source() -> void:
	_last_heat_decay_weapon_id = 0
	_last_heat_decay_rate = 0.0
	_last_heat_decay_source_name = "None"
	_selected_heat_decay_rate = 0.0
	_selected_heat_decay_source_name = "None"

func _build_signature() -> String:
	if _player == null or _player.PlayerData == null:
		return ""
	var keys: PackedStringArray = []
	for weapon in _player.PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		var contributes := false
		if weapon.has_method("has_heat_trait"):
			contributes = bool(weapon.call("has_heat_trait"))
		elif weapon.has_method("has_heat_system"):
			contributes = bool(weapon.call("has_heat_system"))
		if not contributes:
			continue
		var max_heat: float = 0.0
		var cool_rate: float = 0.0
		if weapon.get("heat_max_value") != null:
			max_heat = float(weapon.get("heat_max_value"))
		if weapon.get("heat_cool_rate") != null:
			cool_rate = float(weapon.get("heat_cool_rate"))
		keys.append("%s:%.4f:%.4f" % [str(weapon.get_instance_id()), max_heat, cool_rate])
	keys.sort()
	return "|".join(keys)
