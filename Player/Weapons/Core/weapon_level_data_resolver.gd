extends RefCounted
class_name WeaponLevelDataResolver

static func get_level_key(source_weapon: Weapon, requested_level: Variant, data: Dictionary = {}) -> String:
	var source := _resolve_data_source(source_weapon, data)
	if source.is_empty():
		return str(maxi(int(requested_level), 1))
	var key := str(requested_level)
	if source.has(key):
		return key
	var fallback_key := str(clampi(int(requested_level), 1, source.size()))
	if source.has(fallback_key):
		return fallback_key
	if source.has("1"):
		return "1"
	var keys := source.keys()
	keys.sort()
	return str(keys[0])

static func get_level_data(source_weapon: Weapon, requested_level: Variant, data: Dictionary = {}) -> Dictionary:
	var source := _resolve_data_source(source_weapon, data)
	if source.is_empty():
		return {}
	var key := get_level_key(source_weapon, requested_level, source)
	var level_data: Variant = source.get(key, {})
	if level_data is Dictionary:
		return level_data as Dictionary
	return {}

static func get_data_max_level(source_weapon: Weapon, fallback_max_level: int) -> int:
	var source := _resolve_data_source(source_weapon)
	if source.is_empty():
		return maxi(int(fallback_max_level), 1)
	var best := 0
	for key_variant in source.keys():
		var key_text := str(key_variant)
		if not key_text.is_valid_int():
			continue
		best = maxi(best, int(key_text))
	return best

static func _resolve_data_source(source_weapon: Weapon, data: Dictionary = {}) -> Dictionary:
	if not data.is_empty():
		return data
	if source_weapon == null:
		return {}
	var weapon_data_variant: Variant = source_weapon.get("weapon_data")
	if weapon_data_variant is Dictionary:
		return weapon_data_variant as Dictionary
	return {}
