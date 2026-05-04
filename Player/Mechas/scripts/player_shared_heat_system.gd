extends RefCounted
class_name PlayerSharedHeatSystem

var _player
var _shared_heat_pool: SharedHeatPool
var _shared_heat_signature: String = ""

func setup(player) -> void:
	_player = player
	if _shared_heat_pool == null:
		_shared_heat_pool = SharedHeatPool.new() as SharedHeatPool
		if _shared_heat_pool == null:
			push_warning("Failed to initialize SharedHeatPool.")
			return
	rebuild()

func tick(delta: float) -> void:
	if _shared_heat_pool == null or _player == null:
		return
	var next_signature := _build_signature()
	if next_signature != _shared_heat_signature:
		_shared_heat_signature = next_signature
		rebuild()
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
