extends Control
class_name PlayerAmmoHud

const RELOAD_ICON_TEXTURE := preload("res://UI/assets/hud_icons/reload_icon.png")
const RELOAD_TRACK_COLOR := Color(0.025, 0.075, 0.13, 0.92)
const RELOAD_FILL_COLOR := Color(0.16, 0.72, 1.0, 0.98)
const FRAME_COLOR := Color(0.58, 0.90, 1.0, 1.0)
const CONTAINER_SCREEN_OFFSET := Vector2(0.0, 42.0)
const RELOAD_BAR_SIZE := Vector2(52.0, 6.0)
const HUD_ICON_SIZE := Vector2(10.0, 10.0)
const HUD_ICON_GAP := 4.0

@export var hud_size := Vector2(128.0, 64.0)
@export_range(1.0, 1.5, 0.01) var ring_radius_scale := 1.30
@export_range(0.05, 0.5, 0.01) var fade_duration_sec := 0.15

var _player: Node2D
var _reload_visible := false
var _reload_ratio := 0.0
var _arc_points := PackedVector2Array()
var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = hud_size
	_player = get_parent().get_parent() as Node2D
	visible = false
	modulate.a = 0.0
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_reload_status()
	_sync_screen_position()


func set_reload_status(is_reloading: bool, reload_left: float, reload_total: float, enabled: bool = true) -> void:
	var next_visible := enabled and is_reloading and reload_total > 0.0
	var next_ratio := clampf(1.0 - (reload_left / reload_total), 0.0, 1.0) if next_visible else 0.0
	if next_visible == _reload_visible and is_equal_approx(next_ratio, _reload_ratio):
		if not is_inside_tree():
			visible = next_visible
			modulate.a = 1.0 if next_visible else 0.0
		return
	var visibility_changed := next_visible != _reload_visible
	_reload_visible = next_visible
	if next_visible:
		_reload_ratio = next_ratio
		queue_redraw()
	if visibility_changed:
		_transition_visibility(next_visible)


func get_reload_ratio() -> float:
	return _reload_ratio


func _transition_visibility(show_reload: bool) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not is_inside_tree():
		visible = show_reload
		modulate.a = 1.0 if show_reload else 0.0
		return
	if show_reload:
		visible = true
		modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, fade_duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fade_tween.tween_callback(_finish_fade_out)


func _finish_fade_out() -> void:
	if not _reload_visible:
		visible = false


func _sync_reload_status() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("get_main_weapon"):
		set_reload_status(false, 0.0, 0.0, false)
		return
	var weapon := _player.call("get_main_weapon") as Node
	if weapon == null or not is_instance_valid(weapon) or not weapon.has_method("get_ammo_status"):
		set_reload_status(false, 0.0, 0.0, false)
		return
	var status_variant: Variant = weapon.call("get_ammo_status")
	if not status_variant is Dictionary:
		set_reload_status(false, 0.0, 0.0, false)
		return
	var status := status_variant as Dictionary
	set_reload_status(
		bool(status.get("is_reloading", false)),
		maxf(float(status.get("reload_left", 0.0)), 0.0),
		maxf(float(status.get("reload_total", 0.0)), 0.0),
		bool(status.get("enabled", false)),
	)


func _sync_screen_position() -> void:
	if _player == null or not is_instance_valid(_player):
		visible = false
		return
	var ground_anchor := Vector2.ZERO
	var shadow := _player.get_node_or_null("GroundShadow") as Node2D
	if shadow != null:
		ground_anchor = shadow.position
	var logical_anchor := _player.global_transform * ground_anchor
	var screen_position := _player.get_global_transform_with_canvas() * ground_anchor
	var footprint := Vector2(46.0, 46.0)
	var marker := _player.get_node_or_null("AffiliationMarker")
	if marker != null and marker.has_method("get_hybrid_ground_marker_config"):
		var marker_config := marker.call("get_hybrid_ground_marker_config") as Dictionary
		footprint = marker_config.get("footprint_size", footprint) as Vector2
	var views := get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	var view: Node = null
	if not views.is_empty():
		view = views[0] as Node
		if view != null and view.has_method("project_world_to_screen"):
			screen_position = view.call("project_world_to_screen", logical_anchor) as Vector2
	position = (screen_position - size * 0.5).round()
	var next_points := PackedVector2Array()
	for index in range(17):
		var weight := float(index) / 16.0
		var angle := lerpf(0.0, PI * 0.5, weight)
		var local_point := ground_anchor + Vector2(
			cos(angle) * footprint.x * 0.5 * ring_radius_scale,
			sin(angle) * footprint.y * 0.5 * ring_radius_scale
		)
		var projected := _player.get_global_transform_with_canvas() * local_point
		if view != null and view.has_method("project_world_to_screen"):
			projected = view.call("project_world_to_screen", _player.global_transform * local_point) as Vector2
		next_points.append(projected - position)
	if next_points != _arc_points:
		_arc_points = next_points
		queue_redraw()
	if not _player.visible:
		visible = false
	elif _reload_visible and not visible:
		visible = true
		modulate.a = 1.0


func _draw() -> void:
	if _arc_points.size() < 2:
		return
	var frame_rect := _get_reload_bar_rect(_arc_points)
	draw_rect(frame_rect, RELOAD_TRACK_COLOR, true)
	if _reload_ratio > 0.001:
		var fill_rect := frame_rect
		fill_rect.size.x *= _reload_ratio
		draw_rect(fill_rect, RELOAD_FILL_COLOR, true)
	draw_rect(frame_rect, FRAME_COLOR, false, 1.5, false)
	draw_texture_rect(RELOAD_ICON_TEXTURE, get_reload_icon_rect(frame_rect), false)


func _get_reload_bar_rect(track: PackedVector2Array) -> Rect2:
	if track.size() < 2:
		return Rect2()
	var anchor := hud_size * 0.5 + CONTAINER_SCREEN_OFFSET
	return Rect2(anchor - RELOAD_BAR_SIZE * 0.5, RELOAD_BAR_SIZE)


func get_reload_icon_rect(bar_rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(bar_rect.position.x - HUD_ICON_GAP - HUD_ICON_SIZE.x, bar_rect.get_center().y - HUD_ICON_SIZE.y * 0.5),
		HUD_ICON_SIZE,
	)


func get_reload_icon_texture() -> Texture2D:
	return RELOAD_ICON_TEXTURE
