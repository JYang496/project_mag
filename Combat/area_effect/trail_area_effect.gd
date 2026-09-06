extends Node2D
class_name TrailAreaEffect

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")
const SURFACE_VISUAL := preload("res://Combat/visual/trail_surface_visual.gd")

enum SurfaceStyle { FIRE, RIFT, FROST }

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
@export var fill_color: Color = Color(PALETTE.FREEZE, 0.14)
@export var line_color: Color = Color(PALETTE.PLAYER_PRIMARY, 0.48)
@export var line_width: float = 1.5
@export var chainsaw_visual: bool = false
@export var surface_style: SurfaceStyle = SurfaceStyle.FROST

var source_node: Node
var source_category: StringName = StringName()

var _segments: Array[Dictionary] = []
var _emitters: Dictionary = {}
var _tick_accum: float = 0.0
var _next_segment_id: int = 1
var _retired_segments: Array[Dictionary] = []
var _surface: MeshInstance2D
var _finishing := false

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)

func cleanup_for_battle_end() -> void:
	clear_emitters()
	clear_segments()
	_tick_accum = 0.0
	queue_free()

func _exit_tree() -> void:
	clear_segments()

func _process(delta: float) -> void:
	if not auto_process:
		return
	step(delta)

func step(delta: float) -> void:
	_update_emitters(delta)
	_cleanup_segments()
	_process_tick_damage(delta)
	if not chainsaw_visual:
		var now := Time.get_ticks_msec()
		for index in range(_retired_segments.size() - 1, -1, -1):
			if now >= int(_retired_segments[index]["expires_at_msec"]) + 350:
				_retired_segments.remove_at(index)
		if _surface == null:
			_surface = SURFACE_VISUAL.new()
			_surface.name = "TrailSurface"
			add_child(_surface)
		_surface.update_surface(_segments, _retired_segments, surface_style, draw_enabled)
	if _finishing and _segments.is_empty() and _retired_segments.is_empty():
		queue_free()

## End damage immediately, then let purely decorative residue dissolve.
func finish_with_residue() -> void:
	clear_emitters()
	for segment in _segments:
		_retire_segment(segment)
	_segments.clear()
	_finishing = true
	auto_process = true

func _retire_segment(segment: Dictionary) -> void:
	_release_segment_visual(segment)
	if chainsaw_visual:
		return
	var residue := segment.duplicate()
	residue["expires_at_msec"] = mini(int(residue["expires_at_msec"]), Time.get_ticks_msec())
	_retired_segments.append(residue)
	while _retired_segments.size() > 32:
		_retired_segments.remove_at(0)

func attach_emitter(
	emitter: Node2D,
	segment_radius: float,
	min_spacing: float = 0.0,
	prime_on_first_step: bool = false
) -> void:
	if emitter == null or not is_instance_valid(emitter):
		return
	var snapshot: Variant = null
	if emitter.has_meta(Weapon.HEAT_SNAPSHOT_META):
		snapshot = emitter.get_meta(Weapon.HEAT_SNAPSHOT_META)
	_emitters[emitter.get_instance_id()] = {
		"emitter_ref": weakref(emitter),
		"last_position": emitter.global_position,
		"sample_accum": 0.0,
		"is_primed": not prime_on_first_step,
		"segment_radius": maxf(segment_radius, 0.1),
		"min_spacing": maxf(min_spacing, 0.0),
		"heat_snapshot": snapshot,
	}

func detach_emitter(emitter: Node2D) -> void:
	if emitter == null:
		return
	_emitters.erase(emitter.get_instance_id())

func clear_emitters() -> void:
	_emitters.clear()

func clear_segments() -> void:
	for segment in _segments:
		_release_segment_visual(segment)
	_segments.clear()
	_retired_segments.clear()
	if _surface != null and is_instance_valid(_surface):
		_surface.update_surface(_segments, _retired_segments, surface_style, false)
	if draw_enabled:
		queue_redraw()

func add_point(world_position: Vector2, segment_radius: float) -> void:
	_add_segment(world_position, world_position, segment_radius)

func add_segment(from_world: Vector2, to_world: Vector2, segment_radius: float) -> void:
	_add_segment(from_world, to_world, segment_radius)

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
			_add_segment(
				previous_position as Vector2,
				emitter.global_position,
				float(payload.get("segment_radius", 1.0)),
				payload.get("heat_snapshot", null)
			)
			payload["last_position"] = emitter.global_position
		payload["sample_accum"] = sample_accum
		_emitters[emitter_id] = payload

func _add_segment(from_pos: Vector2, to_pos: Vector2, segment_radius: float, heat_snapshot: Variant = null) -> void:
	var segment := {
		"id": _next_segment_id,
		"from": from_pos,
		"to": to_pos,
		"radius": maxf(segment_radius, 0.1),
		"born_at_msec": Time.get_ticks_msec(),
		"expires_at_msec": Time.get_ticks_msec() + int(maxf(duration, 0.05) * 1000.0),
		"heat_snapshot": heat_snapshot,
	}
	_next_segment_id += 1
	segment["visual"] = _create_segment_visual(segment)
	_segments.append(segment)
	while _segments.size() > max(1, max_segments):
		_retire_segment(_segments[0])
		_segments.remove_at(0)

func _cleanup_segments() -> void:
	if _segments.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	for i in range(_segments.size() - 1, -1, -1):
		var segment: Dictionary = _segments[i]
		if now_msec >= int(segment.get("expires_at_msec", 0)):
			_retire_segment(segment)
			_segments.remove_at(i)

func _create_segment_visual(segment: Dictionary) -> Line2D:
	if not chainsaw_visual:
		return null
	var line := Line2D.new()
	line.name = "TrailGroundSegment%d" % int(segment.get("id", 0))
	line.width = maxf(float(segment.get("radius", 1.0)) * 2.0, 1.0)
	line.default_color = fill_color
	if chainsaw_visual:
		line.default_color = Color.WHITE
		line.set_meta(&"hybrid_segment_style", &"chainsaw")
		var shader_material := ShaderMaterial.new()
		shader_material.shader = preload("res://Shaders/chainsaw_boundary_2d.gdshader")
		shader_material.set_shader_parameter("boundary_length", (segment["from"] as Vector2).distance_to(segment["to"] as Vector2))
		shader_material.set_shader_parameter("boundary_width", line.width)
		line.material = shader_material
		var white_texture := GradientTexture2D.new()
		white_texture.gradient = Gradient.new()
		white_texture.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
		line.texture = white_texture
		line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.points = PackedVector2Array([
		to_local(segment.get("from", Vector2.ZERO) as Vector2),
		to_local(segment.get("to", Vector2.ZERO) as Vector2),
	])
	line.set_meta(&"hybrid_ground_visible", true)
	add_child(line)
	HYBRID_GROUND_REGISTRATION.register(line, &"register_ground_segment")
	return line

func _release_segment_visual(segment: Dictionary) -> void:
	var line := segment.get("visual", null) as Line2D
	if line == null or not is_instance_valid(line):
		return
	HYBRID_GROUND_REGISTRATION.unregister(line)
	line.queue_free()

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
		var hit_info := _get_segment_hit_info(target2d.global_position)
		var overlap_count := int(hit_info.get("count", 0))
		if overlap_count <= 0:
			continue
		var damage_amount := tick_damage * overlap_count if stack_damage_per_segment else tick_damage
		var damage_data := DamageManager.build_damage_data(
			source_node,
			max(1, int(damage_amount)),
			Attack.normalize_damage_type(damage_type),
			knock_back,
			source_category,
			DamageDeliveryType.AREA,
			hit_info.get("heat_snapshot", null)
		)
		DamageManager.apply_to_target(target, damage_data)

func _collect_targets(tree: SceneTree) -> Array[Node]:
	var output: Array[Node] = []
	if target_group == TargetGroup.ENEMIES or target_group == TargetGroup.BOTH:
		for enemy_ref in _collect_enemy_candidates(tree):
			var enemy := enemy_ref as Node
			if enemy != null and is_instance_valid(enemy):
				output.append(enemy)
	if target_group == TargetGroup.ALLIES or target_group == TargetGroup.BOTH:
		var player: Node = PlayerData.player
		if player != null and is_instance_valid(player):
			output.append(player)
	return output

func _collect_enemy_candidates(tree: SceneTree) -> Array[Node2D]:
	var output: Array[Node2D] = []
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry == null or not registry.has_method("get_enemies_in_rect"):
		return output
	var bounds := _get_segments_world_bounds()
	if bounds.size == Vector2.ZERO:
		return output
	var registered_enemies: Variant = registry.call("get_enemies_in_rect", bounds)
	if registered_enemies is Array:
		for enemy_ref in registered_enemies:
			var enemy := enemy_ref as Node2D
			if enemy != null and is_instance_valid(enemy):
				output.append(enemy)
	return output

func _get_segments_world_bounds() -> Rect2:
	if _segments.is_empty():
		return Rect2()
	var first_segment: Dictionary = _segments[0]
	var first_from: Vector2 = first_segment.get("from", Vector2.ZERO)
	var first_to: Vector2 = first_segment.get("to", first_from)
	var bounds := Rect2(first_from, Vector2.ZERO).expand(first_to)
	var max_radius := maxf(float(first_segment.get("radius", 0.0)), 0.0)
	for i in range(1, _segments.size()):
		var segment: Dictionary = _segments[i]
		var from_pos: Vector2 = segment.get("from", Vector2.ZERO)
		var to_pos: Vector2 = segment.get("to", from_pos)
		bounds = bounds.expand(from_pos)
		bounds = bounds.expand(to_pos)
		max_radius = maxf(max_radius, float(segment.get("radius", 0.0)))
	return bounds.grow(max_radius)

func _count_segment_hits(point: Vector2) -> int:
	return int(_get_segment_hit_info(point).get("count", 0))

func _get_segment_hit_info(point: Vector2) -> Dictionary:
	var hits := 0
	var heat_snapshot: Variant = null
	for segment in _segments:
		var from_pos: Vector2 = segment.get("from", Vector2.ZERO)
		var to_pos: Vector2 = segment.get("to", Vector2.ZERO)
		var radius_value := float(segment.get("radius", 0.0))
		if _distance_point_to_segment_sq(point, from_pos, to_pos) <= radius_value * radius_value:
			hits += 1
			if heat_snapshot == null:
				heat_snapshot = segment.get("heat_snapshot", null)
			if not stack_damage_per_segment:
				return {"count": 1, "heat_snapshot": heat_snapshot}
	return {"count": hits, "heat_snapshot": heat_snapshot}

func _distance_point_to_segment_sq(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> float:
	var segment := to_pos - from_pos
	var len_sq := segment.length_squared()
	if len_sq <= 0.0001:
		return point.distance_squared_to(from_pos)
	var t := clampf((point - from_pos).dot(segment) / len_sq, 0.0, 1.0)
	var projection := from_pos + segment * t
	return point.distance_squared_to(projection)
