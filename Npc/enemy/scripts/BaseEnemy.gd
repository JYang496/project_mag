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

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

func _process(delta: float) -> void:
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_multiplier = 1.0

func death() -> void:
	var drop = drop_preload.instantiate()
	drop.drop = coin_preload
	drop.value = hp / 10 + 1
	drop.global_position = self.global_position
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
	return movement_speed * slow_multiplier
