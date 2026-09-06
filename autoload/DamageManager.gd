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
	knock_back: Dictionary = {},
	source_category: StringName = StringName(),
	delivery_type: StringName = StringName(),
	heat_snapshot_override: Variant = null
) -> DamageData:
	var resolved_source_player: Node = resolve_source_player(source_node)
	var final_damage: int = max(0, int(base_damage))
	var is_critical := false
	if resolved_source_player and is_instance_valid(resolved_source_player) and resolved_source_player is Player:
		var heat_snapshot: Variant = heat_snapshot_override
		if heat_snapshot == null and source_node != null and is_instance_valid(source_node) \
				and source_node.has_meta(Weapon.HEAT_SNAPSHOT_META):
			heat_snapshot = source_node.get_meta(Weapon.HEAT_SNAPSHOT_META)
		var weapon_ordinary_multiplier := _resolve_weapon_ordinary_damage_multiplier(source_node, heat_snapshot)
		var outgoing_result = (resolved_source_player as Player).compute_outgoing_damage_result(
			final_damage,
			damage_type,
			heat_snapshot,
			weapon_ordinary_multiplier
		)
		final_damage = outgoing_result.damage
		is_critical = outgoing_result.is_critical

	var effective_knock_back := knock_back.duplicate(true)
	var source_weapon := resolve_source_weapon(source_node)
	if source_weapon != null and source_weapon.has_method("get_effective_knockback"):
		effective_knock_back["amount"] = source_weapon.call(
			"get_effective_knockback",
			float(effective_knock_back.get("amount", 0.0))
		)
	var data := DamageData.new().setup(
		final_damage,
		damage_type,
		effective_knock_back,
		source_node,
		resolved_source_player,
		source_category,
		delivery_type
	)
	data.is_critical = is_critical
	data.outgoing_modifiers_applied = true
	data.heat_snapshot = heat_snapshot_override
	return data


func build_final_damage_data(
	source_node: Node,
	final_damage: int,
	damage_type: StringName = Attack.TYPE_PHYSICAL,
	knock_back: Dictionary = {},
	source_category: StringName = StringName(),
	delivery_type: StringName = StringName()
) -> DamageData:
	var data := DamageData.new().setup(
		max(0, int(final_damage)),
		damage_type,
		knock_back,
		source_node,
		resolve_source_player(source_node),
		source_category,
		delivery_type
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
		result.rejection_reason = DamageResult.REASON_INVALID
		return result
	if data == null:
		result.rejection_reason = DamageResult.REASON_INVALID
		return result
	if not data.has_valid_player_weapon_context():
		push_error("Player weapon damage is missing a valid delivery_type.")
		result.rejection_reason = DamageResult.REASON_INVALID
		return result
	if _is_player_attack_blocked_by_phase(data):
		result.rejection_reason = DamageResult.REASON_PHASE_BLOCKED
		return result
	_apply_outgoing_modifiers_if_needed(data)
	if _is_duplicate_damage(target, data):
		result.rejection_reason = DamageResult.REASON_DUPLICATE
		return result
	var hp_before: Variant = _read_target_hp(target)

	# Prefer a Damageable component when present for extensibility.
	var component := target.get_node_or_null("Damageable")
	if component and component.has_method("apply_damage_data"):
		var component_result: Variant = component.apply_damage_data(data)
		var component_has_authoritative_result := component_result is DamageResult
		if component_result is DamageResult:
			result = component_result as DamageResult
		else:
			result.applied = bool(component_result)
			result.accepted = result.applied
		_populate_damage_result(result, target, data, hp_before, not component_has_authoritative_result)
		_notify_player_weapon_damage_applied(target, data, result)
		return result

	if target.has_method("damaged"):
		var target_result: Variant = target.damaged(data.to_attack())
		var target_has_authoritative_result := target_result is DamageResult
		if target_result is DamageResult:
			result = target_result as DamageResult
		else:
			# Compatibility for legacy void damage receivers. HP delta below remains
			# authoritative where the target exposes an hp property.
			result.applied = true
			result.accepted = true
		_populate_damage_result(result, target, data, hp_before, not target_has_authoritative_result)
		_notify_player_weapon_damage_applied(target, data, result)
		return result
	return result

func _apply_outgoing_modifiers_if_needed(data: DamageData) -> void:
	if data == null or data.outgoing_modifiers_applied or data.damage_is_final:
		return
	if data.source_category != DamageData.SOURCE_PLAYER_WEAPON:
		return
	var player := data.source_player
	if player == null or not is_instance_valid(player):
		player = resolve_source_player(data.source_node)
	if not (player is Player):
		return
	var heat_snapshot: Variant = data.heat_snapshot
	if heat_snapshot == null and data.source_node != null and is_instance_valid(data.source_node) \
			and data.source_node.has_meta(Weapon.HEAT_SNAPSHOT_META):
		heat_snapshot = data.source_node.get_meta(Weapon.HEAT_SNAPSHOT_META)
	var weapon_ordinary_multiplier := _resolve_weapon_ordinary_damage_multiplier(data.source_node, heat_snapshot)
	var outgoing_result = (player as Player).compute_outgoing_damage_result(
		data.amount,
		data.damage_type,
		heat_snapshot,
		weapon_ordinary_multiplier
	)
	data.amount = outgoing_result.damage
	data.is_critical = outgoing_result.is_critical
	data.outgoing_modifiers_applied = true

func _resolve_weapon_ordinary_damage_multiplier(source_node: Node, heat_snapshot: Variant = null) -> float:
	if heat_snapshot is Dictionary and (heat_snapshot as Dictionary).has("weapon_ordinary_multiplier"):
		return maxf(float((heat_snapshot as Dictionary).get("weapon_ordinary_multiplier", 1.0)), 0.05)
	if source_node != null and is_instance_valid(source_node) \
			and source_node.has_meta(Weapon.HEAT_SNAPSHOT_META):
		var snapshot: Variant = source_node.get_meta(Weapon.HEAT_SNAPSHOT_META)
		if snapshot is Dictionary and (snapshot as Dictionary).has("weapon_ordinary_multiplier"):
			return maxf(float((snapshot as Dictionary).get("weapon_ordinary_multiplier", 1.0)), 0.05)
	var source_weapon := resolve_source_weapon(source_node)
	if source_weapon == null or not is_instance_valid(source_weapon):
		return 1.0
	if not source_weapon.has_method("get_total_ordinary_damage_multiplier"):
		return 1.0
	return maxf(float(source_weapon.call("get_total_ordinary_damage_multiplier")), 0.05)


func _notify_player_weapon_damage_applied(target: Node, data: DamageData, result: DamageResult) -> void:
	if result == null or not result.applied or result.final_damage <= 0:
		return
	if data == null or data.source_category != DamageData.SOURCE_PLAYER_WEAPON:
		return
	var source_weapon := resolve_source_weapon(data.source_node)
	if source_weapon == null or not source_weapon.has_method("on_damage_applied"):
		return
	source_weapon.call("on_damage_applied", target, data, result)


func _populate_damage_result(
	result: DamageResult,
	target: Node,
	data: DamageData,
	hp_before: Variant,
	derive_damage_amounts: bool = true
) -> void:
	if result == null or data == null:
		return
	result.damage_type = Attack.normalize_damage_type(data.damage_type)
	result.damage_kind = data.damage_kind
	result.is_critical = data.is_critical
	if not result.applied:
		return
	if derive_damage_amounts:
		var hp_after: Variant = _read_target_hp(target)
		if hp_before != null and hp_after != null:
			var observed_damage: int = maxi(0, int(hp_before) - int(hp_after))
			var remaining_hp: int = maxi(int(hp_before), 0)
			result.final_damage = observed_damage
			result.health_damage = mini(observed_damage, remaining_hp)
			result.overkill_damage = maxi(observed_damage - remaining_hp, 0)
		else:
			result.final_damage = max(0, int(data.amount))
			result.health_damage = result.final_damage
			result.overkill_damage = 0
	if target != null and is_instance_valid(target) and target.get("is_dead") != null:
		result.killed = bool(target.get("is_dead"))
	_play_player_weapon_hit_feedback(target, data, result)


func _play_player_weapon_hit_feedback(target: Node, data: DamageData, result: DamageResult) -> void:
	if data.source_category != DamageData.SOURCE_PLAYER_WEAPON:
		return
	if result == null or result.final_damage <= 0:
		return
	var source_weapon := resolve_source_weapon(data.source_node)
	if source_weapon == null:
		return
	if source_weapon.has_method("play_hit_feedback"):
		source_weapon.call("play_hit_feedback", target)


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

func resolve_source_weapon(source_node: Variant) -> Weapon:
	# A long-lived effect can outlive its weapon. Accept the reference before
	# narrowing its type so a previously freed Object can be rejected safely.
	if source_node == null or not is_instance_valid(source_node) or not source_node is Node:
		return null
	var source_node_instance := source_node as Node
	var current: Node = source_node_instance
	while current != null:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	var source_weapon_value: Variant = source_node_instance.get("source_weapon")
	if typeof(source_weapon_value) == TYPE_OBJECT and is_instance_valid(source_weapon_value) and source_weapon_value is Weapon:
		return source_weapon_value as Weapon
	return null


func _resolve_player_by_walk(source_node: Node) -> Node:
	var current: Node = source_node
	while current:
		if current is Player:
			return current
		current = current.get_parent()

	var source_weapon_value: Variant = source_node.get("source_weapon")
	if typeof(source_weapon_value) == TYPE_OBJECT and is_instance_valid(source_weapon_value) and source_weapon_value is Node:
		current = source_weapon_value as Node
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
