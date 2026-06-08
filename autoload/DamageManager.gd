extends Node

# Small TTL avoids stale cache while still eliminating repeated parent walks.
@export var source_cache_ttl_sec: float = 2.0

var _source_player_cache: Dictionary = {}
var _dedupe_until_msec: Dictionary = {}
var _dedupe_cleanup_cursor: int = 0


func build_damage_data(
	source_node: Node,
	base_damage: int,
	damage_type: StringName = Attack.TYPE_PHYSICAL,
	knock_back: Dictionary = {}
) -> DamageData:
	var resolved_source_player: Node = resolve_source_player(source_node)
	var final_damage: int = max(0, int(base_damage))
	if resolved_source_player and is_instance_valid(resolved_source_player) and resolved_source_player is Player:
		final_damage = (resolved_source_player as Player).compute_outgoing_damage(final_damage)

	var data := DamageData.new().setup(
		final_damage,
		damage_type,
		knock_back,
		source_node,
		resolved_source_player
	)
	return data


func build_final_damage_data(
	source_node: Node,
	final_damage: int,
	damage_type: StringName = Attack.TYPE_PHYSICAL,
	knock_back: Dictionary = {}
) -> DamageData:
	var data := DamageData.new().setup(
		max(0, int(final_damage)),
		damage_type,
		knock_back,
		source_node,
		resolve_source_player(source_node)
	)
	data.damage_is_final = true
	data.suppress_reactive_effects = true
	return data


func apply_to_hurt_box(hurt_box: HurtBox, data: DamageData) -> bool:
	return apply_to_hurt_box_result(hurt_box, data).applied


func apply_to_hurt_box_result(hurt_box: HurtBox, data: DamageData) -> DamageResult:
	var result := DamageResult.new()
	if hurt_box == null or not is_instance_valid(hurt_box):
		return result
	var target: Node = null
	if hurt_box.has_method("get_damage_target"):
		target = hurt_box.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	return apply_to_target_result(target, data)


func apply_to_target(target: Node, data: DamageData) -> bool:
	return apply_to_target_result(target, data).applied


func apply_to_target_result(target: Node, data: DamageData) -> DamageResult:
	var result := DamageResult.new()
	if target == null or not is_instance_valid(target):
		return result
	if data == null:
		return result
	if _is_player_attack_blocked_by_phase(data):
		return result
	if _is_duplicate_damage(target, data):
		return result
	var hp_before: Variant = _read_target_hp(target)

	# Prefer a Damageable component when present for extensibility.
	var component := target.get_node_or_null("Damageable")
	if component and component.has_method("apply_damage_data"):
		result.applied = bool(component.apply_damage_data(data))
		_populate_damage_result(result, target, data, hp_before)
		return result

	if target.has_method("damaged"):
		target.damaged(data.to_attack())
		result.applied = true
		_populate_damage_result(result, target, data, hp_before)
		return result
	return result


func _populate_damage_result(result: DamageResult, target: Node, data: DamageData, hp_before: Variant) -> void:
	if result == null or data == null:
		return
	result.damage_type = Attack.normalize_damage_type(data.damage_type)
	if not result.applied:
		return
	var hp_after: Variant = _read_target_hp(target)
	if hp_before != null and hp_after != null:
		result.final_damage = max(0, int(hp_before) - int(hp_after))
	else:
		result.final_damage = max(0, int(data.amount))
	if target != null and is_instance_valid(target) and target.get("is_dead") != null:
		result.killed = bool(target.get("is_dead"))


func _read_target_hp(target: Node) -> Variant:
	if target == null or not is_instance_valid(target):
		return null
	var hp_value: Variant = target.get("hp")
	if hp_value == null:
		return null
	return int(hp_value)

func _is_player_attack_blocked_by_phase(data: DamageData) -> bool:
	if data == null:
		return false
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return false
	if str(PhaseManager.current_state()) == str(PhaseManager.BATTLE):
		return false
	var source_player: Node = data.source_player
	if source_player == null and data.source_node != null and is_instance_valid(data.source_node):
		source_player = resolve_source_player(data.source_node)
	if source_player == null or not is_instance_valid(source_player):
		return false
	return source_player is Player


func resolve_source_player(source_node: Node) -> Node:
	if source_node == null or not is_instance_valid(source_node):
		return null

	var source_id := source_node.get_instance_id()
	var now_msec := Time.get_ticks_msec()
	if _source_player_cache.has(source_id):
		var cached: Dictionary = _source_player_cache[source_id]
		if int(cached.get("expires", 0)) > now_msec:
			var cached_ref: WeakRef = cached.get("player_ref", null)
			var cached_player: Node = cached_ref.get_ref() if cached_ref else null
			if cached_player != null and is_instance_valid(cached_player):
				return cached_player

	var resolved_player := _resolve_player_by_walk(source_node)
	var expires_msec := now_msec + int(maxf(source_cache_ttl_sec, 0.1) * 1000.0)
	_source_player_cache[source_id] = {
		"player_ref": weakref(resolved_player) if resolved_player != null else null,
		"expires": expires_msec,
	}
	return resolved_player


func _resolve_player_by_walk(source_node: Node) -> Node:
	var current: Node = source_node
	while current:
		if current is Player:
			return current
		current = current.get_parent()

	var source_weapon_value: Variant = source_node.get("source_weapon")
	if source_weapon_value != null and source_weapon_value is Node and is_instance_valid(source_weapon_value):
		current = source_weapon_value
		while current:
			if current is Player:
				return current
			current = current.get_parent()
	return null


func _is_duplicate_damage(target: Node, data: DamageData) -> bool:
	if data.dedupe_window_sec <= 0.0:
		return false
	var source_id := 0
	if data.source_node and is_instance_valid(data.source_node):
		source_id = data.source_node.get_instance_id()
	var token := str(data.dedupe_token)
	if token.is_empty():
		token = "%d|%d|%s|%d" % [
			source_id,
			target.get_instance_id(),
			String(data.damage_type),
			data.amount,
		]
	var now_msec := Time.get_ticks_msec()
	var until_msec := int(_dedupe_until_msec.get(token, 0))
	if until_msec > now_msec:
		return true
	_dedupe_until_msec[token] = now_msec + int(data.dedupe_window_sec * 1000.0)
	_cleanup_dedupe_map(now_msec)
	return false


func _cleanup_dedupe_map(now_msec: int) -> void:
	if _dedupe_until_msec.is_empty():
		return
	_dedupe_cleanup_cursor += 1
	if _dedupe_cleanup_cursor % 32 != 0:
		return
	var to_remove: Array[String] = []
	for token in _dedupe_until_msec.keys():
		if int(_dedupe_until_msec[token]) <= now_msec:
			to_remove.append(token)
	for token in to_remove:
		_dedupe_until_msec.erase(token)
