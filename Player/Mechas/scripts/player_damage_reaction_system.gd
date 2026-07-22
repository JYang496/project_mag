extends RefCounted
class_name PlayerDamageReactionSystem

var _player
var _elite_hit_slow_until_msec: int = 0

func setup(player) -> void:
	_player = player

func damaged(attack: Attack) -> DamageResult:
	var rejected := DamageResult.new()
	rejected.rejection_reason = DamageResult.REASON_INVALID
	if _player == null or not is_instance_valid(_player):
		return rejected
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		rejected.rejection_reason = DamageResult.REASON_DEAD
		return rejected
	if _player._incoming_damage_pipeline == null:
		_player._incoming_damage_pipeline = DamagePipeline.new() as DamagePipeline
	if _player._incoming_damage_profile == null:
		_player._setup_incoming_damage_profile()
	var result: DamageResult = _player._incoming_damage_pipeline.apply_incoming_damage(_player, attack, _player._incoming_damage_profile)
	if not result.applied:
		return result
	if _player.has_method("_broadcast_weapon_passive_event"):
		_player.call("_broadcast_weapon_passive_event", &"on_player_damaged", {
			"attack": attack,
			"player": _player,
			"_suppress_default_emit": true,
		})
	_apply_elite_hit_slow_if_needed(attack)
	if _player.PlayerData.testing_keep_hp_above_zero and _player.PlayerData.player_hp <= 0:
		_player.PlayerData.player_hp = 1
	if _player.PlayerData.player_hp <= 0:
		PhaseManager.enter_gameover()
		return result
	return result

func apply_elite_hit_slow_if_needed(attack: Attack) -> void:
	_apply_elite_hit_slow_if_needed(attack)

func clear_expired_scorch() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.clear_expired_scorch()

func apply_scorch_on_fire_hit(fire_damage: int, source_node: Node = null, source_player: Node = null) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.apply_scorch_on_fire_hit(fire_damage, source_node, source_player)

func get_scorch_stack_cap(hp_ratio: float) -> int:
	if hp_ratio <= 0.5:
		return 3
	if hp_ratio <= 0.75:
		return 2
	return 1

func clear_expired_frost() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.clear_expired_frost()

func apply_frost_on_freeze_hit() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.apply_frost_on_freeze_hit()

func refresh_frost_move_slow() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.refresh_frost_move_slow()

func clear_expired_energy_mark() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.clear_expired_energy_mark()

func apply_energy_mark_on_energy_hit(energy_damage: int) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.apply_energy_mark_on_energy_hit(energy_damage)

func try_trigger_energy_mark_burst(reference_attack: Attack) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.try_trigger_energy_mark_burst(reference_attack)

func apply_scorch_dot_tick(dot_damage: int) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.apply_scorch_dot_tick(dot_damage)

func update_incoming_elemental_effects(delta: float) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system == null:
		return
	_player._elemental_effect_system.update_incoming_elemental_effects(_player._incoming_damage_pipeline, _player._incoming_damage_profile, delta)

func on_profile_apply_frost_slow(move_multiplier: float) -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.on_profile_apply_frost_slow(move_multiplier)

func on_profile_clear_frost_slow() -> void:
	_ensure_elemental_system()
	if _player._elemental_effect_system != null:
		_player._elemental_effect_system.on_profile_clear_frost_slow()

func _apply_elite_hit_slow_if_needed(attack: Attack) -> void:
	if attack == null or _is_attack_from_player(attack):
		return
	if not _is_attack_from_elite_or_boss(attack):
		return
	var duration_msec := int(maxf(_player.elite_hit_slow_duration_sec, 0.0) * 1000.0)
	if duration_msec <= 0:
		return
	_elite_hit_slow_until_msec = Time.get_ticks_msec() + duration_msec
	_player.apply_move_speed_mul(_player.ELITE_HIT_SLOW_SOURCE_ID, clampf(_player.elite_hit_slow_mul, 0.05, 1.0))
	_clear_elite_hit_slow_after_delay(_elite_hit_slow_until_msec)

func _clear_elite_hit_slow_after_delay(token_until_msec: int) -> void:
	await _player.get_tree().create_timer(maxf(_player.elite_hit_slow_duration_sec, 0.0)).timeout
	if not _player.is_inside_tree():
		return
	if token_until_msec != _elite_hit_slow_until_msec:
		return
	_player.remove_move_speed_mul(_player.ELITE_HIT_SLOW_SOURCE_ID)

func _is_attack_from_player(attack: Attack) -> bool:
	if attack == null:
		return false
	return attack.is_from_player()

func _is_attack_from_elite_or_boss(attack: Attack) -> bool:
	if attack == null or attack.source_node == null or not is_instance_valid(attack.source_node):
		return false
	var current: Node = attack.source_node
	while current != null:
		if current is EliteEnemy:
			return true
		if current.is_in_group("boss"):
			return true
		var is_boss_variant: Variant = current.get("is_boss")
		if is_boss_variant != null and bool(is_boss_variant):
			return true
		current = current.get_parent()
	return false

func _ensure_elemental_system() -> void:
	if _player == null:
		return
	_player._ensure_elemental_effect_system()
