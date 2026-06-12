extends CharacterBody2D
class_name BaseNPC

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5
@export var hit_label_merge_window_sec: float = 0.03
@export var hp_bar_show_duration_sec: float = 1.5
@export var hp_bar_vertical_offset: float = -30.0
@export var hit_flash_enabled: bool = true
@export var hit_flash_peak_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var hit_flash_peak_alpha: float = 0.8
@export var hit_flash_in_duration_sec: float = 0.0
@export var hit_flash_out_duration_sec: float = 0.3
var damage_taken_multiplier: float = 1.0

var knockback = {
	"amount": 0,
	"angle": Vector2.ZERO
}

@onready var status_timer: Timer = $StatusTimer
var status_effects: Array[StatusEffect]:
	get:
		return status_runtime.status_effects
var overlapping : bool = false
var is_dead: bool = false
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _incoming_damage_max_hp: int = 1
var damage_feedback: NpcDamageFeedbackController = NpcDamageFeedbackController.new()
var status_runtime: NpcStatusRuntime = NpcStatusRuntime.new()

func _init() -> void:
	damage_feedback.setup(self)
	status_runtime.setup(self)

func damaged(attack:Attack):
	if _incoming_damage_pipeline == null:
		_incoming_damage_pipeline = DamagePipeline.new()
	if _incoming_damage_profile == null:
		_setup_incoming_damage_profile()
	var result := _incoming_damage_pipeline.apply_incoming_damage(self, attack, _incoming_damage_profile)
	if not result.applied:
		return
	if attack != null and attack.is_from_player():
		PlayerData.run_total_damage_dealt += max(0, result.final_damage)
	_queue_hit_label_damage(result.final_damage, result.damage_type)
	knockback.amount = attack.knock_back.amount
	knockback.angle = attack.knock_back.angle
	_play_hit_flash()
	_sync_enemy_hp_bar()
	_show_enemy_hp_bar_on_damage()
	if status_timer.is_stopped() and (_incoming_damage_pipeline.has_active_effects(self) or not status_effects.is_empty()):
		status_runtime.start_timer_if_needed()


func _queue_hit_label_damage(damage_value: int, damage_type: StringName) -> void:
	damage_feedback.queue_hit_label_damage(damage_value, damage_type)

func _flush_pending_hit_label() -> void:
	damage_feedback.flush_pending_hit_label()

func death(_killing_attack: Attack = null):
		queue_free()

func _on_status_timer_timeout() -> void:
	if _incoming_damage_pipeline == null:
		_incoming_damage_pipeline = DamagePipeline.new()
	if _incoming_damage_profile == null:
		_setup_incoming_damage_profile()
	var elapsed_sec := status_runtime.get_elapsed_tick_sec(status_timer.wait_time)
	var periodic_results := _incoming_damage_pipeline.process_periodic_effects(self, _incoming_damage_profile, elapsed_sec)
	for periodic_result in periodic_results:
		if periodic_result.applied:
			_queue_hit_label_damage(periodic_result.final_damage, periodic_result.damage_type)
	if status_effects.is_empty() and not _incoming_damage_pipeline.has_active_effects(self):
		status_timer.stop()
		status_runtime.stop_timer_tracking()
		return
	status_runtime.process_tick()


func apply_status_effect(effect: StatusEffect) -> void:
	status_runtime.apply_status_effect(effect)

func apply_mark(mark_id: StringName, duration_sec: float, data: Dictionary = {}) -> void:
	status_runtime.apply_mark(mark_id, duration_sec, data)


func has_mark(mark_id: StringName) -> bool:
	return status_runtime.has_mark(mark_id)


func has_any_mark() -> bool:
	return status_runtime.has_any_mark()


func get_active_mark_ids() -> Array[StringName]:
	return status_runtime.get_active_mark_ids()


func get_mark_value(mark_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	return status_runtime.get_mark_value(mark_id, key, default_value)


func apply_damage_taken_multiplier_status(status_id: StringName, multiplier: float, duration_sec: float) -> void:
	status_runtime.apply_damage_taken_multiplier_status(status_id, multiplier, duration_sec)


func has_damage_taken_multiplier_status(status_id: StringName) -> bool:
	return status_runtime.has_damage_taken_multiplier_status(status_id)


func get_damage_taken_multiplier_status_value(status_id: StringName, default_value: float = 1.0) -> float:
	return status_runtime.get_damage_taken_multiplier_status_value(status_id, default_value)


func _get_status_damage_taken_multiplier() -> float:
	return status_runtime.get_damage_taken_multiplier()


func _setup_incoming_damage_profile() -> void:
	_incoming_damage_max_hp = max(1, int(hp))
	var profile := DamageProfile.new()
	profile.profile_id = &"enemy"
	profile.use_damage_reduction = false
	profile.use_armor = false
	profile.use_invuln = false
	profile.dot_bypasses_invuln = true
	profile.get_hp = Callable(self, "_profile_get_hp")
	profile.set_hp = Callable(self, "_profile_set_hp")
	profile.get_max_hp = Callable(self, "_profile_get_max_hp")
	profile.get_armor = Callable(self, "_profile_get_armor")
	profile.get_damage_reduction = Callable(self, "_profile_get_damage_reduction")
	profile.get_damage_taken_multiplier = Callable(self, "_profile_get_damage_taken_multiplier")
	profile.get_is_dead = Callable(self, "_profile_get_is_dead")
	profile.set_is_dead = Callable(self, "_profile_set_is_dead")
	profile.on_death = Callable(self, "_profile_on_death")
	profile.on_apply_frost_slow = Callable(self, "_profile_on_apply_frost_slow")
	profile.on_clear_frost_slow = Callable(self, "_profile_on_clear_frost_slow")
	_incoming_damage_profile = profile
	_sync_enemy_hp_bar()

func _profile_get_hp() -> int:
	return int(hp)

func _profile_set_hp(value: int) -> void:
	hp = int(value)

func _profile_get_max_hp() -> int:
	return max(1, _incoming_damage_max_hp)

func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var maximum: int = maxi(1, _incoming_damage_max_hp)
	var previous: int = int(hp)
	hp = mini(previous + amount, maximum)
	var restored: int = int(hp) - previous
	if restored > 0:
		_sync_enemy_hp_bar()
	return restored

func get_health_ratio() -> float:
	return clampf(float(maxi(int(hp), 0)) / float(maxi(_incoming_damage_max_hp, 1)), 0.0, 1.0)

func _profile_get_armor() -> int:
	return 0

func _profile_get_damage_reduction() -> float:
	return 1.0

func _profile_get_damage_taken_multiplier() -> float:
	return maxf(0.0, damage_taken_multiplier)

func get_source_damage_taken_multiplier(attack: Attack) -> float:
	if attack == null or not _attack_is_from_player_weapon_source(attack):
		return 1.0
	return _get_status_damage_taken_multiplier()

func _attack_is_from_player_weapon_source(attack: Attack) -> bool:
	if attack == null:
		return false
	if attack.is_from_player():
		return true
	var source := attack.source_node
	if source == null or not is_instance_valid(source):
		return false
	if bool(source.get_meta("player_weapon_damage_source", false)):
		return true
	if source is Weapon:
		return true
	var source_weapon_value: Variant = source.get("source_weapon")
	return source_weapon_value is Weapon and is_instance_valid(source_weapon_value)

func _profile_get_is_dead() -> bool:
	return is_dead

func _profile_set_is_dead(value: bool) -> void:
	is_dead = value

func _profile_on_death(attack: Attack) -> void:
	if is_dead:
		_hide_enemy_hp_bar()
		_flush_pending_hit_label()
		death(attack)

func _profile_on_apply_frost_slow(move_multiplier: float, duration_sec: float) -> void:
	if has_method("apply_slow"):
		call("apply_slow", move_multiplier, duration_sec)

func _profile_on_clear_frost_slow() -> void:
	pass

func _play_hit_flash() -> void:
	damage_feedback.play_hit_flash()


func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	status_runtime.apply_status_payload(status_name, status_data)

func _ensure_enemy_hp_bar() -> EnemyHpBar:
	return damage_feedback._ensure_enemy_hp_bar()

func _sync_enemy_hp_bar() -> void:
	damage_feedback.sync_enemy_hp_bar()

func _show_enemy_hp_bar_on_damage() -> void:
	damage_feedback.show_enemy_hp_bar_on_damage()

func _hide_enemy_hp_bar() -> void:
	damage_feedback.hide_enemy_hp_bar()

func get_incoming_damage_max_hp() -> int:
	return _incoming_damage_max_hp
