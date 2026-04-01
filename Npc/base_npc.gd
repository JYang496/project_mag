extends CharacterBody2D
class_name BaseNPC

const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox
@onready var hit_label = preload("res://UI/labels/hit_label.tscn")

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5
@export var hit_label_merge_window_sec: float = 0.03
var damage_taken_multiplier: float = 1.0
const SCORCH_DURATION_SEC: float = 6.0
const SCORCH_DOT_RATIO_PER_STACK: float = 0.10
const SCORCH_DOT_TICK_SEC: float = 1.0
const FROST_DURATION_SEC: float = 6.0
const FROST_SLOW_PER_STACK: float = 0.04
const FROST_STACK_INTERVAL_SEC: float = 0.6
const FROST_MAX_STACKS: int = 5
const ENERGY_MARK_RATIO: float = 0.10
const ENERGY_MARK_DURATION_SEC: float = 6.0
const ENERGY_MARK_MAX_HP_RATIO: float = 0.40
const ENERGY_MARK_TRIGGER_COOLDOWN_SEC: float = 2.0

var knockback = {
	"amount": 0,
	"angle": Vector2.ZERO
}

@onready var status_timer: Timer = $StatusTimer
var status_effects: Array[StatusEffect] = []
var overlapping : bool = false
var is_dead: bool = false
var _pending_hit_label_damage: int = 0
var _hit_label_batch_id: int = 0
var _pending_hit_label_damage_by_type: Dictionary = {}
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
var _last_status_tick_msec: int = 0
@onready var _scorch_max_hp: int = max(1, int(hp))
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _incoming_damage_max_hp: int = 1

var _quest_lock_active := false
var _quest_lock_speed := 0.0
var _quest_lock_damage_mul := 1.0
var _quest_freeze_movement := false
@onready var _base_movement_speed: float = movement_speed
var _quest_outline_enabled := false
var _quest_outline_original_material: Material
var _quest_outline_material: ShaderMaterial

const QUEST_OUTLINE_SHADER: Shader = preload("res://Shaders/quest_outline.gdshader") as Shader


func damaged(attack:Attack):
	if _incoming_damage_pipeline == null:
		_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	if _incoming_damage_profile == null:
		_setup_incoming_damage_profile()
	var result := _incoming_damage_pipeline.apply_incoming_damage(self, attack, _incoming_damage_profile)
	if not result.applied:
		return
	_queue_hit_label_damage(result.final_damage, result.damage_type)
	knockback.amount = attack.knock_back.amount
	knockback.angle = attack.knock_back.angle
	if status_timer.is_stopped() and (_incoming_damage_pipeline.has_active_effects(self) or not status_effects.is_empty()):
		status_timer.start()
		_last_status_tick_msec = Time.get_ticks_msec()


func _queue_hit_label_damage(damage_value: int, damage_type: StringName) -> void:
	if damage_value <= 0:
		return
	var normalized_type := Attack.normalize_damage_type(damage_type)
	_pending_hit_label_damage += damage_value
	var current_type_damage: int = int(_pending_hit_label_damage_by_type.get(normalized_type, 0))
	_pending_hit_label_damage_by_type[normalized_type] = current_type_damage + damage_value
	# Death is decided inside the damage pipeline before this function is called.
	# Flush immediately so queue_free on death does not swallow the label.
	if is_dead:
		_flush_pending_hit_label()
		return
	_hit_label_batch_id += 1
	var queued_batch_id := _hit_label_batch_id
	_schedule_hit_label_flush(queued_batch_id)


func _schedule_hit_label_flush(batch_id: int) -> void:
	_flush_hit_label_after_delay(batch_id)


func _flush_hit_label_after_delay(batch_id: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(maxf(hit_label_merge_window_sec, 0.0)).timeout
	if not is_inside_tree():
		return
	if batch_id != _hit_label_batch_id:
		return
	_flush_pending_hit_label()


func _flush_pending_hit_label() -> void:
	if _pending_hit_label_damage <= 0:
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var combined_damage := _pending_hit_label_damage
	var label_color := _resolve_hit_label_color()
	_pending_hit_label_damage = 0
	var hit_label_ins = hit_label.instantiate()
	hit_label_ins.global_position = global_position
	hit_label_ins.setNumber(combined_damage)
	hit_label_ins.setColor(label_color)
	tree.root.call_deferred("add_child", hit_label_ins)
	_pending_hit_label_damage_by_type.clear()

func _resolve_hit_label_color() -> Color:
	if _pending_hit_label_damage <= 0:
		return Color.WHITE
	var dominant_type: StringName = Attack.TYPE_PHYSICAL
	var dominant_damage: int = 0
	for type_key in _pending_hit_label_damage_by_type.keys():
		var type_damage := int(_pending_hit_label_damage_by_type[type_key])
		if type_damage > dominant_damage:
			dominant_damage = type_damage
			dominant_type = Attack.normalize_damage_type(type_key)
	if float(dominant_damage) <= float(_pending_hit_label_damage) * 0.5:
		return Color(0.65, 0.65, 0.65, 1.0) # Gray (chaos)
	match dominant_type:
		Attack.TYPE_ENERGY:
			return Color(0.72, 0.45, 1.0, 1.0) # Purple
		Attack.TYPE_FIRE:
			return Color(1.0, 0.3, 0.25, 1.0) # Red
		Attack.TYPE_FREEZE:
			return Color(0.35, 0.95, 1.0, 1.0) # Cyan
		_:
			return Color.WHITE

func death(_killing_attack: Attack = null):
		queue_free()

func _on_status_timer_timeout() -> void:
	if _incoming_damage_pipeline == null:
		_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	if _incoming_damage_profile == null:
		_setup_incoming_damage_profile()
	var now_msec := Time.get_ticks_msec()
	var elapsed_sec := status_timer.wait_time
	if _last_status_tick_msec > 0:
		elapsed_sec = maxf(0.0, float(now_msec - _last_status_tick_msec) / 1000.0)
	_last_status_tick_msec = now_msec
	var periodic_results := _incoming_damage_pipeline.process_periodic_effects(self, _incoming_damage_profile, elapsed_sec)
	for periodic_result in periodic_results:
		if periodic_result.applied:
			_queue_hit_label_damage(periodic_result.final_damage, periodic_result.damage_type)
	if status_effects.is_empty() and not _incoming_damage_pipeline.has_active_effects(self):
		status_timer.stop()
		_last_status_tick_msec = 0
		return
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		effect.apply_tick(self)
		if effect.step():
			status_effects.remove_at(i)


func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return
	for existing in status_effects:
		if existing.effect_id == effect.effect_id:
			existing.merge_from(effect)
			if status_timer.is_stopped():
				status_timer.start()
				_last_status_tick_msec = Time.get_ticks_msec()
			return
	status_effects.append(effect)
	if status_timer.is_stopped():
		status_timer.start()
		_last_status_tick_msec = Time.get_ticks_msec()

func _setup_incoming_damage_profile() -> void:
	_incoming_damage_max_hp = max(1, int(hp))
	var profile := DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
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

func _profile_get_hp() -> int:
	return int(hp)

func _profile_set_hp(value: int) -> void:
	hp = int(value)

func _profile_get_max_hp() -> int:
	return max(1, _incoming_damage_max_hp)

func _profile_get_armor() -> int:
	return 0

func _profile_get_damage_reduction() -> float:
	return 1.0

func _profile_get_damage_taken_multiplier() -> float:
	return maxf(0.0, damage_taken_multiplier)

func _profile_get_is_dead() -> bool:
	return is_dead

func _profile_set_is_dead(value: bool) -> void:
	is_dead = value

func _profile_on_death(attack: Attack) -> void:
	if is_dead:
		_flush_pending_hit_label()
		death(attack)

func _profile_on_apply_frost_slow(move_multiplier: float, duration_sec: float) -> void:
	if has_method("apply_slow"):
		call("apply_slow", move_multiplier, duration_sec)

func _profile_on_clear_frost_slow() -> void:
	pass


func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	match status_name:
		&"dot":
			apply_status_effect(DotStatusEffect.from_dot_payload(status_data))

func set_quest_lock(active: bool, damage_mul: float = 0.5, freeze_movement: bool = true) -> void:
	if active:
		if _quest_lock_active:
			return
		_quest_lock_active = true
		_quest_lock_speed = movement_speed if movement_speed > 0.0 else _base_movement_speed
		_quest_lock_damage_mul = damage_taken_multiplier
		_quest_freeze_movement = freeze_movement
		damage_taken_multiplier = minf(damage_taken_multiplier, maxf(damage_mul, 0.05))
		return
	if not _quest_lock_active:
		return
	_quest_lock_active = false
	_quest_freeze_movement = false
	damage_taken_multiplier = _quest_lock_damage_mul

func is_quest_movement_locked() -> bool:
	return _quest_lock_active and _quest_freeze_movement

func set_outline_highlight(enabled: bool, color: Color = Color.WHITE, width: float = 1.0) -> void:
	if sprite_body == null:
		return
	if enabled:
		if not _quest_outline_enabled:
			_quest_outline_original_material = sprite_body.material
			_quest_outline_material = _build_quest_outline_material(color, width)
			_quest_outline_enabled = true
		if _quest_outline_material:
			_quest_outline_material.set_shader_parameter("outline_color", color)
			_quest_outline_material.set_shader_parameter("outline_width", width)
			sprite_body.material = _quest_outline_material
		return
	if not _quest_outline_enabled:
		return
	_quest_outline_enabled = false
	sprite_body.material = _quest_outline_original_material

func _build_quest_outline_material(color: Color, width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = QUEST_OUTLINE_SHADER
	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter("outline_width", width)
	return material
