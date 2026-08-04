extends Node
class_name EnemySpawnSequence

const DEFAULT_DURATION_SEC := 0.62
const ELITE_DURATION_SEC := 0.95
const TELEGRAPH_RATIO := 0.32
const MIN_DURATION_SEC := 0.08

var _enemy: Node2D
var _elapsed := 0.0
var _duration := DEFAULT_DURATION_SEC
var _telegraph_duration := DEFAULT_DURATION_SEC * TELEGRAPH_RATIO
var _body: CanvasItem
var _shadow: CanvasItem
var _marker: CanvasItem
var _body_modulate := Color.WHITE
var _body_scale := Vector2.ONE
var _shadow_modulate := Color.WHITE
var _marker_was_visible := true
var _finished := false


func begin(enemy: Node2D, duration_override: float = -1.0) -> void:
	_enemy = enemy
	process_mode = Node.PROCESS_MODE_ALWAYS
	_duration = _resolve_duration(duration_override)
	_telegraph_duration = _duration * TELEGRAPH_RATIO
	_body = enemy.get_node_or_null("Body") as CanvasItem
	_shadow = enemy.get_node_or_null("GroundShadow") as CanvasItem
	_marker = enemy.get_node_or_null("AffiliationMarker") as CanvasItem
	_capture_visual_state()
	_apply_initial_visual_state()
	add_to_group("enemy_runtime_cleanup")
	set_process(true)


func _resolve_duration(duration_override: float) -> float:
	if duration_override > 0.0:
		return maxf(duration_override, MIN_DURATION_SEC)
	if _enemy != null and (bool(_enemy.get("is_boss")) or bool(_enemy.call("has_spawn_tag", &"elite"))):
		return ELITE_DURATION_SEC
	return DEFAULT_DURATION_SEC


func _capture_visual_state() -> void:
	if _body != null:
		_body_modulate = _body.modulate
		var body_node := _body as Node2D
		if body_node != null:
			_body_scale = body_node.scale
	if _shadow != null:
		_shadow_modulate = _shadow.modulate
	if _marker != null:
		_marker_was_visible = bool(_marker.get_meta(&"hybrid_ground_visible", _marker.visible))


func _apply_initial_visual_state() -> void:
	if _body != null:
		var hidden_body := _body_modulate
		hidden_body.a = 0.0
		_body.modulate = hidden_body
		var body_node := _body as Node2D
		if body_node != null:
			body_node.scale = _body_scale * Vector2(0.82, 0.34)
	if _shadow != null:
		var hidden_shadow := _shadow_modulate
		hidden_shadow.a = 0.0
		_shadow.modulate = hidden_shadow
	if _marker != null:
		_marker.visible = false
		_marker.set_meta(&"hybrid_ground_visible", false)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += maxf(delta, 0.0)
	var materialize_progress := clampf(
		(_elapsed - _telegraph_duration) / maxf(_duration - _telegraph_duration, 0.01),
		0.0,
		1.0
	)
	_apply_materialize_progress(materialize_progress)
	if _elapsed + 0.0001 >= _duration:
		_finish()


func _apply_materialize_progress(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	if _body != null:
		var body_color := _body_modulate
		body_color.a *= eased
		_body.modulate = body_color
		var body_node := _body as Node2D
		if body_node != null:
			var reconstruct_scale := Vector2(lerpf(0.82, 1.0, eased), lerpf(0.34, 1.0, eased))
			body_node.scale = _body_scale * reconstruct_scale
	if _shadow != null:
		var shadow_color := _shadow_modulate
		shadow_color.a *= clampf(progress * 1.45, 0.0, 1.0)
		_shadow.modulate = shadow_color


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_restore_visual_state()
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.complete_spawn_sequence()
	queue_free()


func _restore_visual_state() -> void:
	if _body != null:
		_body.modulate = _body_modulate
		var body_node := _body as Node2D
		if body_node != null:
			body_node.scale = _body_scale
	if _shadow != null:
		_shadow.modulate = _shadow_modulate
	if _marker != null:
		_marker.visible = false if bool(_marker.get_meta(&"hybrid_ground_registered", false)) else _marker_was_visible
		_marker.set_meta(&"hybrid_ground_visible", _marker_was_visible)
