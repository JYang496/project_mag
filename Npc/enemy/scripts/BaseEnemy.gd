extends BaseNPC
class_name BaseEnemy
@export var damage := 0
@export var is_boss: bool = false
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")
@onready var drop_preload = preload("res://Objects/loots/drop.tscn")

signal enemy_death()

@onready var hit_box_dot: HitBoxDot = $HitBoxDot
@onready var enable_collision_timer: Timer = $EnableCollisionTimer
var stun_remaining: float = 0.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var _is_knockback_overlap_mode: bool = false

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

func _process(delta: float) -> void:
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_multiplier = 1.0
	_update_knockback_overlap_mode()

func death() -> void:
	var drop = drop_preload.instantiate()
	drop.drop = coin_preload
	drop.value = hp / 10 + 1
	drop.spawn_global_position = global_position
	self.call_deferred("add_sibling",drop)
	enemy_death.emit()
	queue_free()

func erase() -> void:
	enemy_death.emit()
	queue_free()

func _on_enable_collision_timer_timeout() -> void:
	self.set_collision_mask_value(6,true)
	self.set_collision_mask_value(3,true)

func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	var adjusted_duration := duration
	if self is EliteEnemy or is_boss or is_in_group("boss"):
		adjusted_duration *= 0.5
	stun_remaining = maxf(stun_remaining, adjusted_duration)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var clamped_multiplier: float = clampf(multiplier, 0.05, 1.0)
	if slow_remaining > 0.0:
		slow_multiplier = minf(slow_multiplier, clamped_multiplier)
	else:
		slow_multiplier = clamped_multiplier
	slow_remaining = maxf(slow_remaining, duration)

func is_slowed() -> bool:
	return slow_remaining > 0.0 and slow_multiplier < 1.0

func get_current_movement_speed() -> float:
	if has_method("is_quest_movement_locked") and is_quest_movement_locked():
		return 0.0
	return movement_speed * slow_multiplier

func interrupt_movement() -> void:
	if has_method("_finish_dash"):
		call_deferred("_finish_dash")
	if has_method("apply_stun"):
		apply_stun(0.2)

func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	super.apply_status_payload(status_name, status_data)
	if not (status_data is Dictionary):
		return
	var payload := status_data as Dictionary
	match status_name:
		&"stun":
			apply_stun(float(payload.get("duration", 0.0)))
		&"slow":
			apply_slow(
				float(payload.get("multiplier", 1.0)),
				float(payload.get("duration", 0.0))
			)

func _update_knockback_overlap_mode() -> void:
	var is_being_knocked_back: bool = float(knockback.get("amount", 0.0)) > 0.01
	if is_being_knocked_back:
		if not _is_knockback_overlap_mode:
			# During knockback, disable enemy-vs-enemy body collision to allow overlap.
			self.set_collision_mask_value(3, false)
			_is_knockback_overlap_mode = true
		return
	if _is_knockback_overlap_mode:
		# Restore normal enemy collision behavior after knockback ends.
		self.set_collision_mask_value(3, true)
		_is_knockback_overlap_mode = false

func set_quest_highlight(enabled: bool, color: Color = Color.WHITE) -> void:
	if self is EliteEnemy:
		var elite := self as EliteEnemy
		if elite.has_method("set_quest_highlight"):
			elite.set_quest_highlight(enabled, color)
		else:
			elite.highlight(enabled)
			if enabled:
				elite.set_highlight_color(color)
		return
	if has_method("set_outline_highlight"):
		set_outline_highlight(enabled, color, 1.0)
