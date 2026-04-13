extends Node2D

@onready var hitbox_dot : HitBoxDot = $HitBoxDot
@onready var hitbox_collision_shape : CollisionShape2D = $HitBoxDot/CollisionShape2D
@onready var line2d : Line2D = $Line2D
@onready var expire_timer : Timer = $ExpireTimer
var damage = 1
var damage_type: StringName = Attack.TYPE_ENERGY
var source_weapon: Weapon
var target_position = Vector2(100,100)
var width := 8
var hit_cd
var duration : float = 3.0
var beam_profile: Dictionary = {}
var target_lock_mode: StringName = &"none"
var target_lock_release_multiplier: float = 1.8
var clip_to_nearest_target: bool = false

var _locked_target_id: int = -1
var _locked_target_ref: WeakRef
var _last_locked_hit_time_sec: float = -999.0
var overlapping : bool :
	set(value):
		if value != overlapping:
			overlapping = value
			overlapping_signal.emit()

# Signals
signal overlapping_signal()

var frame_counter = 0
var frames_until_show = 1

func _ready() -> void:
	expire_timer.wait_time = duration
	line2d.width = width
	clip_to_nearest_target = bool(beam_profile.get("clip_to_nearest_target", false))
	if hitbox_dot:
		hitbox_dot.dot_cd = hit_cd
		var hit_timer := hitbox_dot.get_node_or_null("HitTimer") as Timer
		if hit_timer:
			hit_timer.wait_time = maxf(float(hit_cd), 0.01)
	expire_timer.start()

func _physics_process(delta: float) -> void:
	_update_target_lock_timeout()
	frame_counter += 1
	if frame_counter > frames_until_show:
		line2d.show()
	if hitbox_dot:
		hitbox_dot.hitbox_owner = self
		var full_end: Vector2 = target_position * 9.0
		var effective_end: Vector2 = full_end
		if clip_to_nearest_target:
			effective_end = _resolve_nearest_target_end(full_end)
		line2d.points = [Vector2.ZERO, effective_end]
		var points = line2d.points
		var start = points[0]
		var end = points[1]
		var length = start.distance_to(end)
		var direction = (end - start).normalized()
		
		# Hitbox
		var rect_shape  = RectangleShape2D.new()
		rect_shape.extents = Vector2(length / 2, maxf(width * 0.5, 2.0)) # Half length and width
		hitbox_collision_shape.shape = rect_shape
		
		hitbox_dot.position = start + direction * length / 2
		hitbox_dot.rotation = direction.angle()


func _on_expire_timer_timeout() -> void:
	queue_free()

func can_hit_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target_lock_mode != &"first_hit":
		return true
	if _locked_target_id < 0:
		return true
	return target.get_instance_id() == _locked_target_id

func on_hit_target(target: Node) -> void:
	if target_lock_mode == &"first_hit":
		var target_id: int = target.get_instance_id()
		if _locked_target_id < 0:
			_locked_target_id = target_id
			_locked_target_ref = weakref(target)
		if target_id == _locked_target_id:
			_last_locked_hit_time_sec = Time.get_ticks_msec() / 1000.0
	if source_weapon and is_instance_valid(source_weapon) and source_weapon.has_method("on_beam_hit_target"):
		source_weapon.call("on_beam_hit_target", target, beam_profile, int(damage))
	if source_weapon and is_instance_valid(source_weapon):
		source_weapon.on_hit_target(target)

func _update_target_lock_timeout() -> void:
	if target_lock_mode != &"first_hit":
		return
	if _locked_target_id < 0:
		return
	if not _is_locked_target_valid():
		_clear_target_lock()
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var timeout_sec: float = maxf(float(hit_cd), 0.01) * maxf(target_lock_release_multiplier, 1.0)
	if now_sec - _last_locked_hit_time_sec > timeout_sec:
		_clear_target_lock()

func _is_locked_target_valid() -> bool:
	if _locked_target_ref == null:
		return false
	var target_variant: Variant = _locked_target_ref.get_ref()
	if not (target_variant is Node):
		return false
	var target_node := target_variant as Node
	return target_node != null and is_instance_valid(target_node)

func _clear_target_lock() -> void:
	_locked_target_id = -1
	_locked_target_ref = null
	_last_locked_hit_time_sec = -999.0

func _resolve_nearest_target_end(full_end: Vector2) -> Vector2:
	if hitbox_dot == null or not is_instance_valid(hitbox_dot):
		return full_end
	var full_length := full_end.length()
	if full_length <= 0.001:
		return full_end
	var beam_dir := full_end / full_length
	var nearest_distance := full_length
	var has_target := false
	for area in hitbox_dot.get_overlapping_areas():
		if not (area is HurtBox):
			continue
		var sample_points: Array[Vector2] = [to_local((area as Area2D).global_position)]
		var target := _resolve_hurtbox_target(area)
		if target != null:
			sample_points.append(to_local((target as Node2D).global_position))
		for local_pos in sample_points:
			var along := beam_dir.dot(local_pos)
			var clamped_along := clampf(along, 0.0, full_length)
			if clamped_along < nearest_distance:
				nearest_distance = clamped_along
				has_target = true
	if not has_target:
		return full_end
	return beam_dir * nearest_distance

func _resolve_hurtbox_target(area: Area2D) -> Node2D:
	if area == null or not is_instance_valid(area):
		return null
	var target: Node = null
	if area is HurtBox and area.has_method("get_damage_target"):
		target = area.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = area.get_owner()
	if target == null or not is_instance_valid(target):
		target = area.get_parent()
	if not (target is Node2D):
		return null
	return target as Node2D
