extends Control
class_name PlayerSkillHud

const SKILL_ICON_TEXTURE := preload("res://UI/assets/hud_icons/skill_energy_icon.png")
const ENERGY_BAR_SIZE := Vector2(52.0, 6.0)
const ENERGY_BAR_SCREEN_OFFSET := Vector2(0.0, 54.0)
const HUD_ICON_SIZE := Vector2(12.0, 12.0)
const HUD_ICON_GAP := 4.0
const ENERGY_TRACK := Color(0.105, 0.065, 0.018, 0.94)
const ENERGY_FILL := Color(1.0, 0.55, 0.04, 0.98)
const ENERGY_EDGE := Color(1.0, 0.76, 0.22, 1.0)

@export var hud_size := Vector2(128.0, 64.0)
@export_range(0.05, 0.5, 0.01) var fade_in_duration_sec := 0.15
@export_range(0.25, 5.0, 0.05) var hold_duration_sec := 2.0
@export_range(0.05, 0.75, 0.01) var fade_out_duration_sec := 0.25

var _player: Node2D
var _feedback_tween: Tween
var _feedback_active := false
var _current_energy := 100.0
var _max_energy := 100.0


func _init() -> void:
	visible = false
	modulate.a = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = hud_size
	_player = get_parent().get_parent() as Node2D
	visible = false
	modulate.a = 0.0
	if _player != null and _player.has_signal("player_active_skill"):
		_player.connect("player_active_skill", _on_player_skill_attempted)
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_sync_energy()
	_sync_screen_position()


func _on_player_skill_attempted() -> void:
	_sync_energy()
	show_skill_feedback()


func show_skill_feedback() -> void:
	if _feedback_active:
		return
	_feedback_active = true
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	visible = true
	if not is_inside_tree():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_interval(hold_duration_sec)
	_feedback_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_callback(_finish_feedback)


func _finish_feedback() -> void:
	_feedback_active = false
	visible = false


func set_energy(current: float, maximum: float) -> void:
	var next_max := maxf(maximum, 1.0)
	var next_current := clampf(current, 0.0, next_max)
	if is_equal_approx(_max_energy, next_max) and is_equal_approx(_current_energy, next_current):
		return
	_max_energy = next_max
	_current_energy = next_current
	queue_redraw()


func get_energy_ratio() -> float:
	return clampf(_current_energy / maxf(_max_energy, 1.0), 0.0, 1.0)


func _sync_energy() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("get_current_energy") or not _player.has_method("get_max_energy"):
		return
	set_energy(
		float(_player.call("get_current_energy")),
		float(_player.call("get_max_energy")),
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
	var views := get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	if not views.is_empty():
		var view := views[0] as Node
		if view != null and view.has_method("project_world_to_screen"):
			screen_position = view.call("project_world_to_screen", logical_anchor) as Vector2
	position = (screen_position - size * 0.5).round()
	if not _player.visible:
		visible = false


func _draw() -> void:
	var bar_rect := get_skill_slot_rect()
	draw_rect(bar_rect, ENERGY_TRACK, true)
	var ratio := get_energy_ratio()
	if ratio > 0.001:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), ENERGY_FILL, true)
	draw_rect(bar_rect, ENERGY_EDGE, false, 1.5, false)
	draw_texture_rect(SKILL_ICON_TEXTURE, get_skill_icon_rect(bar_rect), false)


func get_skill_slot_rect() -> Rect2:
	var anchor := hud_size * 0.5 + ENERGY_BAR_SCREEN_OFFSET
	return Rect2(anchor - ENERGY_BAR_SIZE * 0.5, ENERGY_BAR_SIZE)


func get_skill_icon_rect(bar_rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(bar_rect.position.x - HUD_ICON_GAP - HUD_ICON_SIZE.x, bar_rect.get_center().y - HUD_ICON_SIZE.y * 0.5),
		HUD_ICON_SIZE,
	)


func get_skill_icon_texture() -> Texture2D:
	return SKILL_ICON_TEXTURE
