extends RefCounted
class_name PlayerElementalEffectSystem

var _player
var _player_data: Node = null
var _scorch_duration_sec: float = 6.0
var _scorch_dot_ratio_per_stack: float = 0.10
var _frost_duration_sec: float = 6.0
var _frost_slow_per_stack: float = 0.04
var _frost_stack_interval_sec: float = 0.6
var _frost_max_stacks: int = 5
var _frost_move_speed_source: StringName = &"incoming_frost"
var _energy_mark_ratio: float = 0.10
var _energy_mark_duration_sec: float = 6.0
var _energy_mark_max_hp_ratio: float = 0.40
var _energy_mark_trigger_cooldown_sec: float = 2.0

var _scorch_stacks: int = 0
var _scorch_expires_at_msec: int = 0
var _scorch_dot_damage_per_stack: int = 1
var _scorch_dot_accum_sec: float = 0.0
var _scorch_source_node: Node
var _scorch_source_player: Node
var _is_processing_scorch_dot: bool = false
var _frost_stacks: int = 0
var _frost_expires_at_msec: int = 0
var _frost_next_stack_at_msec: int = 0
var _energy_mark_value: int = 0
var _energy_mark_expires_at_msec: int = 0
var _energy_mark_trigger_ready_at_msec: int = 0
var _is_processing_energy_burst: bool = false

func setup(player) -> void:
	_player = player
	if _player != null and is_instance_valid(_player):
		_player_data = _player.get_node_or_null("/root/PlayerData")

func configure(
	scorch_duration_sec: float,
	scorch_dot_ratio_per_stack: float,
	frost_duration_sec: float,
	frost_slow_per_stack: float,
	frost_stack_interval_sec: float,
	frost_max_stacks: int,
	frost_move_speed_source: StringName,
	energy_mark_ratio: float,
	energy_mark_duration_sec: float,
	energy_mark_max_hp_ratio: float,
	energy_mark_trigger_cooldown_sec: float
) -> void:
	_scorch_duration_sec = scorch_duration_sec
	_scorch_dot_ratio_per_stack = scorch_dot_ratio_per_stack
	_frost_duration_sec = frost_duration_sec
	_frost_slow_per_stack = frost_slow_per_stack
	_frost_stack_interval_sec = frost_stack_interval_sec
	_frost_max_stacks = frost_max_stacks
	_frost_move_speed_source = frost_move_speed_source
	_energy_mark_ratio = energy_mark_ratio
	_energy_mark_duration_sec = energy_mark_duration_sec
	_energy_mark_max_hp_ratio = energy_mark_max_hp_ratio
	_energy_mark_trigger_cooldown_sec = energy_mark_trigger_cooldown_sec

func clear_expired_scorch() -> void:
	if _scorch_stacks <= 0:
		_scorch_stacks = 0
		_scorch_expires_at_msec = 0
		_scorch_dot_damage_per_stack = 1
		_scorch_dot_accum_sec = 0.0
		_scorch_source_node = null
		_scorch_source_player = null
		return
	if Time.get_ticks_msec() < _scorch_expires_at_msec:
		return
	_scorch_stacks = 0
	_scorch_expires_at_msec = 0
	_scorch_dot_damage_per_stack = 1
	_scorch_dot_accum_sec = 0.0
	_scorch_source_node = null
	_scorch_source_player = null

func apply_scorch_on_fire_hit(fire_damage: int, source_node: Node = null, source_player: Node = null) -> void:
	if _player_data == null or not is_instance_valid(_player_data):
		return
	var max_hp: float = maxf(float(_player_data.player_max_hp), 1.0)
	var hp_ratio: float = clampf(float(max(_player_data.player_hp, 0)) / max_hp, 0.0, 1.0)
	var stack_cap := _get_scorch_stack_cap(hp_ratio)
	if _scorch_stacks < stack_cap:
		_scorch_stacks += 1
	var per_stack_dot: int = max(1, int(round(float(max(1, fire_damage)) * _scorch_dot_ratio_per_stack)))
	_scorch_dot_damage_per_stack = max(_scorch_dot_damage_per_stack, per_stack_dot)
	_scorch_source_node = source_node
	_scorch_source_player = source_player
	_scorch_expires_at_msec = Time.get_ticks_msec() + int(_scorch_duration_sec * 1000.0)

func clear_expired_frost() -> void:
	if _frost_stacks <= 0:
		_frost_stacks = 0
		_frost_expires_at_msec = 0
		_frost_next_stack_at_msec = 0
		_remove_frost_slow()
		return
	if Time.get_ticks_msec() < _frost_expires_at_msec:
		return
	_frost_stacks = 0
	_frost_expires_at_msec = 0
	_frost_next_stack_at_msec = 0
	_remove_frost_slow()

func apply_frost_on_freeze_hit() -> void:
	var now_msec := Time.get_ticks_msec()
	if _frost_stacks < _frost_max_stacks and now_msec >= _frost_next_stack_at_msec:
		_frost_stacks += 1
		_frost_next_stack_at_msec = now_msec + int(maxf(_frost_stack_interval_sec, 0.05) * 1000.0)
	_refresh_frost_move_slow()
	_frost_expires_at_msec = now_msec + int(_frost_duration_sec * 1000.0)

func refresh_frost_move_slow() -> void:
	_refresh_frost_move_slow()

func clear_expired_energy_mark() -> void:
	if _energy_mark_value <= 0:
		_energy_mark_value = 0
		_energy_mark_expires_at_msec = 0
		return
	if Time.get_ticks_msec() < _energy_mark_expires_at_msec:
		return
	_energy_mark_value = 0
	_energy_mark_expires_at_msec = 0

func apply_energy_mark_on_energy_hit(energy_damage: int) -> void:
	if _player_data == null or not is_instance_valid(_player_data):
		return
	var gained_mark: int = max(0, int(round(float(max(0, energy_damage)) * _energy_mark_ratio)))
	if gained_mark <= 0:
		return
	var mark_cap: int = max(1, int(round(maxf(float(_player_data.player_max_hp), 1.0) * _energy_mark_max_hp_ratio)))
	_energy_mark_value = mini(mark_cap, _energy_mark_value + gained_mark)
	_energy_mark_expires_at_msec = Time.get_ticks_msec() + int(_energy_mark_duration_sec * 1000.0)

func try_trigger_energy_mark_burst(reference_attack: Attack) -> void:
	if _energy_mark_value <= 0:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < _energy_mark_trigger_ready_at_msec:
		return
	if _player_data == null or not is_instance_valid(_player_data):
		return
	if _player_data.player_hp >= _energy_mark_value:
		return
	var burst_damage := _energy_mark_value
	_energy_mark_value = 0
	_energy_mark_expires_at_msec = 0
	_energy_mark_trigger_ready_at_msec = now_msec + int(_energy_mark_trigger_cooldown_sec * 1000.0)
	if burst_damage <= 0:
		return
	var burst_attack := Attack.new()
	burst_attack.damage = burst_damage
	burst_attack.damage_type = Attack.TYPE_ENERGY
	if reference_attack != null:
		burst_attack.source_node = reference_attack.source_node
		burst_attack.source_player = reference_attack.source_player
	_is_processing_energy_burst = true
	if _player != null and is_instance_valid(_player):
		_player.damaged(burst_attack)
	_is_processing_energy_burst = false

func apply_scorch_dot_tick(dot_damage: int) -> void:
	if dot_damage <= 0:
		return
	var dot_attack := Attack.new()
	dot_attack.damage = dot_damage
	dot_attack.damage_type = Attack.TYPE_FIRE
	dot_attack.source_node = _scorch_source_node
	dot_attack.source_player = _scorch_source_player
	_is_processing_scorch_dot = true
	if _player != null and is_instance_valid(_player):
		_player.damaged(dot_attack)
	_is_processing_scorch_dot = false

func update_incoming_elemental_effects(damage_pipeline, damage_profile, delta: float) -> void:
	if damage_pipeline == null or damage_profile == null:
		return
	damage_pipeline.process_periodic_effects(_player, damage_profile, delta)

func on_profile_apply_frost_slow(move_multiplier: float) -> void:
	if _player != null and is_instance_valid(_player):
		_player.apply_move_speed_mul(_frost_move_speed_source, move_multiplier)

func on_profile_clear_frost_slow() -> void:
	_remove_frost_slow()

func _refresh_frost_move_slow() -> void:
	if _frost_stacks <= 0:
		_remove_frost_slow()
		return
	var move_mul := clampf(1.0 - float(_frost_stacks) * _frost_slow_per_stack, 0.05, 1.0)
	if _player != null and is_instance_valid(_player):
		_player.apply_move_speed_mul(_frost_move_speed_source, move_mul)

func _remove_frost_slow() -> void:
	if _player != null and is_instance_valid(_player):
		_player.remove_move_speed_mul(_frost_move_speed_source)

func _get_scorch_stack_cap(hp_ratio: float) -> int:
	if hp_ratio <= 0.5:
		return 3
	if hp_ratio <= 0.75:
		return 2
	return 1
