extends RefCounted

var _player
var _passive_time_tick_accum: float = 0.0
var _debug_passive_connected_weapon_ids: Dictionary = {}
var _global_weapon_passive_effects: Dictionary = {}
var _global_weapon_passive_applied: Dictionary = {}

func setup(player) -> void:
	_player = player

func broadcast_weapon_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	if _player == null or _player.PlayerData == null:
		return
	for weapon in _player.PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("dispatch_passive_event"):
			weapon.call("dispatch_passive_event", event_name, detail)

func apply_global_weapon_passive_effect(source_id: StringName, stat_type: StringName, multiplier: float, duration_sec: float = 0.0, source_weapon: Weapon = null, include_source_weapon: bool = true) -> void:
	if source_id == StringName() or stat_type == StringName():
		return
	var now_msec := Time.get_ticks_msec()
	var expires_at_msec := 0
	if duration_sec > 0.0:
		expires_at_msec = now_msec + int(maxf(duration_sec, 0.01) * 1000.0)
	_global_weapon_passive_effects[source_id] = {
		"stat_type": stat_type,
		"multiplier": maxf(multiplier, 0.01),
		"expires_at_msec": expires_at_msec,
		"source_weapon": weakref(source_weapon) if source_weapon != null else null,
		"include_source_weapon": include_source_weapon,
	}
	sync_global_weapon_passive_source(source_id)

func remove_global_weapon_passive_effect(source_id: StringName) -> void:
	if source_id == StringName():
		return
	_global_weapon_passive_effects.erase(source_id)
	remove_global_weapon_passive_source(source_id)

func clear_global_weapon_passives() -> void:
	var applied_source_ids := _global_weapon_passive_applied.keys()
	for source_id_variant in applied_source_ids:
		remove_global_weapon_passive_source(StringName(str(source_id_variant)))
	_global_weapon_passive_effects.clear()
	_global_weapon_passive_applied.clear()

func update_global_weapon_passives() -> void:
	if _global_weapon_passive_effects.is_empty() and _global_weapon_passive_applied.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	var expired_sources: Array[StringName] = []
	for source_id_variant in _global_weapon_passive_effects.keys():
		var source_id := StringName(str(source_id_variant))
		var effect: Dictionary = _global_weapon_passive_effects[source_id]
		var expires_at_msec := int(effect.get("expires_at_msec", 0))
		if (expires_at_msec > 0 and now_msec >= expires_at_msec) or effect_source_weapon_is_stale(effect):
			expired_sources.append(source_id)
			continue
		sync_global_weapon_passive_source(source_id)
	for source_id in expired_sources:
		remove_global_weapon_passive_effect(source_id)

func sync_global_weapon_passive_source(source_id: StringName) -> void:
	if not _global_weapon_passive_effects.has(source_id):
		remove_global_weapon_passive_source(source_id)
		return
	if _player == null or _player.PlayerData == null:
		return
	var effect: Dictionary = _global_weapon_passive_effects[source_id]
	var valid_weapon_ids: Dictionary = {}
	for weapon_ref in _player.PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not bool(effect.get("include_source_weapon", true)) and effect_source_weapon_equals(effect, weapon):
			continue
		valid_weapon_ids[weapon.get_instance_id()] = true
		apply_global_weapon_passive_to_weapon(source_id, effect, weapon)
	var applied: Dictionary = _global_weapon_passive_applied.get(source_id, {})
	for weapon_id_variant in applied.keys():
		var weapon_id := int(weapon_id_variant)
		if valid_weapon_ids.has(weapon_id):
			continue
		var applied_entry: Dictionary = applied[weapon_id]
		var weapon_ref: WeakRef = applied_entry.get("weapon_ref", null)
		var weapon: Weapon = weapon_ref.get_ref() as Weapon if weapon_ref else null
		if weapon != null and is_instance_valid(weapon):
			remove_global_weapon_passive_from_weapon(source_id, StringName(str(applied_entry.get("stat_type", ""))), weapon)
		applied.erase(weapon_id)
	_global_weapon_passive_applied[source_id] = applied

func apply_global_weapon_passive_to_weapon(source_id: StringName, effect: Dictionary, weapon: Weapon) -> void:
	var stat_type := StringName(str(effect.get("stat_type", "")))
	var multiplier := float(effect.get("multiplier", 1.0))
	match stat_type:
		&"damage_mul":
			if weapon.has_method("apply_external_damage_mul"):
				weapon.call("apply_external_damage_mul", source_id, multiplier)
		&"damage_flat":
			if weapon.has_method("apply_external_damage_mul"):
				var runtime_damage := resolve_weapon_runtime_damage_for_global_effect(weapon)
				var bonus_flat: int = max(0, int(round(multiplier)))
				if bonus_flat <= 0:
					return
				var damage_mul := float(runtime_damage + bonus_flat) / float(runtime_damage)
				weapon.call("apply_external_damage_mul", source_id, damage_mul)
		&"attack_speed_mul":
			if weapon.has_method("apply_external_attack_speed_mul"):
				weapon.call("apply_external_attack_speed_mul", source_id, multiplier)
		&"spread_mul":
			if weapon.has_method("apply_external_spread_mul"):
				weapon.call("apply_external_spread_mul", source_id, multiplier)
		_:
			return
	var applied: Dictionary = _global_weapon_passive_applied.get(source_id, {})
	applied[weapon.get_instance_id()] = {
		"weapon_ref": weakref(weapon),
		"stat_type": stat_type,
	}
	_global_weapon_passive_applied[source_id] = applied

func remove_global_weapon_passive_source(source_id: StringName) -> void:
	var applied: Dictionary = _global_weapon_passive_applied.get(source_id, {})
	for applied_entry_variant in applied.values():
		var applied_entry: Dictionary = applied_entry_variant
		var weapon_ref: WeakRef = applied_entry.get("weapon_ref", null)
		var weapon: Weapon = weapon_ref.get_ref() as Weapon if weapon_ref else null
		if weapon == null or not is_instance_valid(weapon):
			continue
		remove_global_weapon_passive_from_weapon(source_id, StringName(str(applied_entry.get("stat_type", ""))), weapon)
	_global_weapon_passive_applied.erase(source_id)

func remove_global_weapon_passive_from_weapon(source_id: StringName, stat_type: StringName, weapon: Weapon) -> void:
	match stat_type:
		&"damage_mul":
			if weapon.has_method("remove_external_damage_mul"):
				weapon.call("remove_external_damage_mul", source_id)
		&"damage_flat":
			if weapon.has_method("remove_external_damage_mul"):
				weapon.call("remove_external_damage_mul", source_id)
		&"attack_speed_mul":
			if weapon.has_method("remove_external_attack_speed_mul"):
				weapon.call("remove_external_attack_speed_mul", source_id)
		&"spread_mul":
			if weapon.has_method("remove_external_spread_mul"):
				weapon.call("remove_external_spread_mul", source_id)

func effect_source_weapon_equals(effect: Dictionary, weapon: Weapon) -> bool:
	var source_ref: WeakRef = effect.get("source_weapon", null)
	if source_ref == null:
		return false
	var source_weapon: Weapon = source_ref.get_ref() as Weapon
	return source_weapon != null and is_instance_valid(source_weapon) and source_weapon == weapon

func effect_source_weapon_is_stale(effect: Dictionary) -> bool:
	var source_ref: WeakRef = effect.get("source_weapon", null)
	if source_ref == null:
		return false
	var source_weapon: Weapon = source_ref.get_ref() as Weapon
	return source_weapon == null or not is_instance_valid(source_weapon)

func resolve_weapon_runtime_damage_for_global_effect(weapon: Weapon) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 1
	if weapon.has_method("get_runtime_shot_damage"):
		return max(1, int(weapon.call("get_runtime_shot_damage")))
	if weapon.has_method("get_runtime_damage_value"):
		var base_damage_value := 1.0
		if weapon.get("base_damage") != null:
			base_damage_value = maxf(1.0, float(weapon.get("base_damage")))
		elif weapon.get("damage") != null:
			base_damage_value = maxf(1.0, float(weapon.get("damage")))
		return max(1, int(weapon.call("get_runtime_damage_value", base_damage_value)))
	if weapon.get("damage") != null:
		return max(1, int(weapon.get("damage")))
	return 1

func debug_connect_weapon_passive_triggers() -> void:
	if _player == null or not _player.debug_weapon_passive_trigger_event_prints:
		return
	if _player.PlayerData == null:
		return
	var active_ids := {}
	for weapon_ref in _player.PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		var weapon_instance_id := weapon.get_instance_id()
		active_ids[weapon_instance_id] = true
		if _debug_passive_connected_weapon_ids.has(weapon_instance_id):
			continue
		var callback := Callable(self, "debug_on_weapon_passive_triggered").bind(weapon)
		if not weapon.passive_triggered.is_connected(callback):
			weapon.passive_triggered.connect(callback)
		_debug_passive_connected_weapon_ids[weapon_instance_id] = true
	for connected_id in _debug_passive_connected_weapon_ids.keys():
		if not active_ids.has(connected_id):
			_debug_passive_connected_weapon_ids.erase(connected_id)

func debug_on_weapon_passive_triggered(event_name: StringName, detail: Dictionary, weapon: Weapon) -> void:
	if _player == null or not _player.debug_weapon_passive_trigger_event_prints:
		return
	if not debug_is_weapon_passive_trigger_event(event_name):
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon) if DataHandler != null else ""
	var weapon_name = weapon.get("ITEM_NAME")
	if weapon_name == null or str(weapon_name).strip_edges() == "":
		weapon_name = weapon.name
	print("[WEAPON PASSIVE TRIGGERED] id=", weapon_id, " name=", weapon_name, " event=", event_name, " scope=", detail.get("passive_scope", Weapon.PASSIVE_SCOPE_BODY), " detail=", detail)

func debug_is_weapon_passive_trigger_event(event_name: StringName) -> bool:
	var event_text := str(event_name)
	return event_text.ends_with("_triggered") or event_text.ends_with("_spend")

func update_passive_time_tick(delta: float) -> void:
	_passive_time_tick_accum += maxf(delta, 0.0)
	if _passive_time_tick_accum < 1.0:
		return
	_passive_time_tick_accum = 0.0
	broadcast_weapon_passive_event(&"on_time_tick", {})
