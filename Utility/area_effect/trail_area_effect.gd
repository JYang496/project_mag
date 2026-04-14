extends Node2D
class_name TrailAreaEffect

enum TargetGroup {
	ENEMIES,
	ALLIES,
	BOTH
}

@export var duration: float = 1.6
@export var tick_interval: float = 0.35
@export var sample_interval: float = 0.08
@export var max_segments: int = 18
@export var target_group: TargetGroup = TargetGroup.ENEMIES
@export var tick_damage: int = 1
@export var damage_type: StringName = Attack.TYPE_FREEZE
@export var knock_back := {
	"amount": 0.0,
	"angle": Vector2.ZERO
}
@export var stack_damage_per_segment: bool = false
@export var auto_process: bool = true
@export var draw_enabled: bool = true
@export var fill_color: Color = Color(0.35, 0.85, 1.0, 0.18)
@export var line_color: Color = Color(0.45, 0.95, 1.0, 0.75)
@export var line_width: float = 1.5

var source_node: Node

var _segments: Array[Dictionary] = []
var _emitters: Dictionary = {}
var _tick_accum: float = 0.0

func _process(delta: float) -> void:
	if not auto_process:
		return
	step(delta)

func step(delta: float) -> void:
	_update_emitters(delta)
	_cleanup_segments()
	_process_tick_damage(delta)
	if draw_enabled:
		queue_redraw()

func attach_emitter(
	emitter: Node2D,
	segment_radius: float,
	min_spacing: float = 0.0,
	prime_on_first_step: bool = false
) -> void:
	if emitter == null or not is_instance_valid(emitter):
		return
	_emitters[emitter.get_instance_id()] = {
		"emitter_ref": weakref(emitter),
		"last_position": emitter.global_position,
		"sample_accum": 0.0,
		"is_primed": not prime_on_first_step,
		"segment_radius": maxf(segment_radius, 0.1),
		"min_spacing": maxf(min_spacing, 0.0),
	}

func detach_emitter(emitter: Node2D) -> void:
	if emitter == null:
		return
	_emitters.erase(emitter.get_instance_id())

func clear_emitters() -> void:
	_emitters.clear()

func clear_segments() -> void:
	_segments.clear()
	if draw_enabled:
		queue_redraw()

func _update_emitters(delta: float) -> void:
	if _emitters.is_empty():
		return
	var sample_step := maxf(sample_interval, 0.02)
	for emitter_id in _emitters.keys():
		var payload_variant: Variant = _emitters.get(emitter_id, {})
		if not (payload_variant is Dictionary):
			_emitters.erase(emitter_id)
			continue
		var payload: Dictionary = payload_variant
		var emitter_ref: WeakRef = payload.get("emitter_ref", null)
		var emitter: Node2D = null
		if emitter_ref != null:
			emitter = emitter_ref.get_ref() as Node2D
		if emitter == null or not is_instance_valid(emitter):
			_emitters.erase(emitter_id)
			continue
		var sample_accum := float(payload.get("sample_accum", 0.0)) + maxf(delta, 0.0)
		if sample_accum < sample_step:
			payload["sample_accum"] = sample_accum
			_emitters[emitter_id] = payload
			continue
		sample_accum = 0.0
		if not bool(payload.get("is_primed", false)):
			payload["last_position"] = emitter.global_position
			payload["is_primed"] = true
			payload["sample_accum"] = sample_accum
			_emitters[emitter_id] = payload
			continue
		var previous_position: Variant = payload.get("last_position", emitter.global_position)
		var min_spacing := maxf(float(payload.get("min_spacing", 0.0)), 0.0)
		if previous_position is Vector2 and (previous_position as Vector2).distance_to(emitter.global_position) >= maxf(min_spacing, 0.5):
			_add_segment(previous_position as Vector2, emitter.global_position, float(payload.get("segment_radius", 1.0)))
			payload["last_position"] = emitter.global_position
		payload["sample_accum"] = sample_accum
		_emitters[emitter_id] = payload

func _add_segment(from_pos: Vector2, to_pos: Vector2, segment_radius: float) -> void:
	_segments.append({
		"from": from_pos,
		"to": to_pos,
		"radius": maxf(segment_radius, 0.1),
		"expires_at_msec": Time.get_ticks_msec() + int(maxf(duration, 0.05) * 1000.0),
	})
	while _segments.size() > max(1, max_segments):
		_segments.remove_at(0)

func _cleanup_segments() -> void:
	if _segments.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	for i in range(_segments.size() - 1, -1, -1):
		var segment: Dictionary = _segments[i]
		if now_msec >= int(segment.get("expires_at_msec", 0)):
			_segments.remove_at(i)

func _process_tick_damage(delta: float) -> void:
	if _segments.is_empty():
		return
	_tick_accum += maxf(delta, 0.0)
	var interval := maxf(tick_interval, 0.05)
	while _tick_accum >= interval:
		_tick_accum -= interval
		_apply_tick_damage()

func _apply_tick_damage() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for target in _collect_targets(tree):
		var target2d := target as Node2D
		if target2d == null:
			continue
		var overlap_count := _count_segment_hits(target2d.global_position)
		if overlap_count <= 0:
			continue
		var damage_amount := tick_damage * overlap_count if stack_damage_per_segment else tick_damage
		var damage_data := DamageManager.build_damage_data(
			source_node,
			max(1, int(damage_amount)),
			Attack.normalize_damage_type(damage_type),
			knock_back
		)
		DamageManager.apply_to_target(target, damage_data)

func _collect_targets(tree: SceneTree) -> Array[Node]:
	var output: Array[Node] = []
	if target_group == TargetGroup.ENEMIES or target_group == TargetGroup.BOTH:
		for enemy_ref in tree.get_nodes_in_group("enemies"):
			var enemy := enemy_ref as Node
			if enemy != null and is_instance_valid(enemy):
				output.append(enemy)
	if target_group == TargetGroup.ALLIES or target_group == TargetGroup.BOTH:
		var player: Node = PlayerData.player
		if player != null and is_instance_valid(player):
			output.append(player)
	return output

func _count_segment_hits(point: Vector2) -> int:
	var hits := 0
	for segment in _segments:
		var from_pos: Vector2 = segment.get("from", Vector2.ZERO)
		var to_pos: Vector2 = segment.get("to", Vector2.ZERO)
		var radius_value := float(segment.get("radius", 0.0))
		if _distance_point_to_segment_sq(point, from_pos, to_pos) <= radius_value * radius_value:
			hits += 1
			if not stack_damage_per_segment:
				return 1
	return hits

func _distance_point_to_segment_sq(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> float:
	var segment := to_pos - from_pos
	var len_sq := segment.length_squared()
	if len_sq <= 0.0001:
		return point.distance_squared_to(from_pos)
	var t := clampf((point - from_pos).dot(segment) / len_sq, 0.0, 1.0)
	var projection := from_pos + segment * t
	return point.distance_squared_to(projection)

func _draw() -> void:
	if not draw_enabled:
		return
	for segment in _segments:
		var from_pos: Vector2 = segment.get("from", Vector2.ZERO)
		var to_pos: Vector2 = segment.get("to", Vector2.ZERO)
		var radius_value := maxf(float(segment.get("radius", 0.0)), 0.1)
		var local_from := to_local(from_pos)
		var local_to := to_local(to_pos)
		draw_line(local_from, local_to, fill_color, radius_value * 2.0, true)
		draw_circle(local_from, radius_value, fill_color)
		draw_circle(local_to, radius_value, fill_color)
		draw_line(local_from, local_to, line_color, maxf(line_width, 0.5), true)
