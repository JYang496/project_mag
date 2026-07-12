class_name BillboardVisual2D
extends Node2D

const FixedObliqueProjectionType := preload("res://Visual/Oblique/fixed_oblique_projection_2d.gd")

enum BillboardMode { UPRIGHT, DIRECTIONAL, SCREEN_UI }

@export var mode: BillboardMode = BillboardMode.UPRIGHT
@export var extra_scale: Vector2 = Vector2.ONE
@export var enabled: bool = true
@export var hide_behind_camera: bool = true
@export_range(0.0, 1.0, 0.05) var perspective_scale_amount: float = 0.0
@export_range(0.5, 1.0, 0.01) var perspective_min_scale: float = 0.95
@export_range(1.0, 1.5, 0.01) var perspective_max_scale: float = 1.05
var _base_transform := Transform2D.IDENTITY
var _last_applied_transform := Transform2D.IDENTITY
var _has_applied_transform: bool = false
var screen_feedback_offset: Vector2 = Vector2.ZERO
var screen_feedback_rotation: float = 0.0
var screen_offset: Vector2 = Vector2.ZERO
var _hybrid_view_cache: Node
var _projection_hidden: bool = false
var _visible_before_projection_hide: bool = true

func _ready() -> void:
	_base_transform = transform
	_apply_compensation()

func _process(_delta: float) -> void:
	_apply_compensation()

func _apply_compensation() -> void:
	var hybrid_view := _get_hybrid_view()
	if hybrid_view != null:
		_capture_external_basis_change()
		transform = _base_transform
		var parent_2d := get_parent() as Node2D
		if parent_2d != null:
			var logical_anchor := parent_2d.global_transform * _base_transform.origin
			if hide_behind_camera and not bool(hybrid_view.call("can_project_world_point", logical_anchor)):
				_set_projection_hidden(true)
				return
			_set_projection_hidden(false)
			global_position = hybrid_view.call("project_world_to_canvas", logical_anchor, get_viewport()) as Vector2
			_apply_optional_perspective_scale(hybrid_view.call("project_world_to_screen", logical_anchor) as Vector2)
			if mode == BillboardMode.DIRECTIONAL:
				var logical_axis := Vector2.RIGHT.rotated(parent_2d.global_rotation)
				var screen_axis := hybrid_view.call("world_vector_to_screen", logical_axis, logical_anchor) as Vector2
				if screen_axis.length_squared() > 0.0001:
					global_rotation = screen_axis.angle() + _base_transform.get_rotation()
			else:
				global_rotation = _base_transform.get_rotation()
			var canvas := get_viewport().get_canvas_transform()
			global_position += canvas.basis_xform_inv(screen_offset + screen_feedback_offset)
			global_rotation += screen_feedback_rotation
		_last_applied_transform = transform
		_has_applied_transform = true
		return
	_capture_external_transform_change()
	if not enabled:
		transform = _base_transform
		_last_applied_transform = transform
		_has_applied_transform = true
		return
	var compensation: Transform2D = FixedObliqueProjectionType.get_billboard_compensation_transform()
	var visual_scale := Transform2D(Vector2(extra_scale.x, 0.0), Vector2(0.0, extra_scale.y), Vector2.ZERO)
	var origin := _base_transform.origin
	transform = compensation * visual_scale * Transform2D(_base_transform.x, _base_transform.y, Vector2.ZERO)
	transform.origin = origin
	_last_applied_transform = transform
	_has_applied_transform = true

func _capture_external_transform_change() -> void:
	if not _has_applied_transform or _transforms_are_equal(transform, _last_applied_transform):
		return
	if not enabled:
		_base_transform = transform
		return
	# Player and inherited NPC scenes are allowed to resize/reposition their
	# sprites after _ready(). Convert that authored transform back out of the
	# last billboard compensation instead of restoring the scene-file scale.
	var compensation: Transform2D = FixedObliqueProjectionType.get_billboard_compensation_transform()
	var visual_scale := Transform2D(Vector2(extra_scale.x, 0.0), Vector2(0.0, extra_scale.y), Vector2.ZERO)
	var compensated_basis := compensation * visual_scale
	var current_basis := Transform2D(transform.x, transform.y, Vector2.ZERO)
	var logical_basis := compensated_basis.affine_inverse() * current_basis
	_base_transform = Transform2D(logical_basis.x, logical_basis.y, transform.origin)

func _capture_external_basis_change() -> void:
	if not _has_applied_transform:
		return
	if transform.x.is_equal_approx(_last_applied_transform.x) and transform.y.is_equal_approx(_last_applied_transform.y):
		return
	# Hybrid projection owns visual position. Only externally authored scale or
	# rotation is accepted; projected origins must never become logical anchors.
	_base_transform.x = transform.x
	_base_transform.y = transform.y

func _transforms_are_equal(a: Transform2D, b: Transform2D) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.origin.is_equal_approx(b.origin)

func _get_hybrid_view() -> Node:
	if _hybrid_view_cache != null and is_instance_valid(_hybrid_view_cache) and _hybrid_view_cache.is_inside_tree():
		return _hybrid_view_cache
	if not is_inside_tree():
		return null
	var views := get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	_hybrid_view_cache = views[0] as Node if not views.is_empty() else null
	return _hybrid_view_cache

func set_logical_local_position(logical_position: Vector2) -> void:
	_base_transform.origin = logical_position

func set_screen_offset(value: Vector2) -> void:
	screen_offset = value

func reset_projection_state() -> void:
	screen_feedback_offset = Vector2.ZERO
	screen_feedback_rotation = 0.0
	screen_offset = Vector2.ZERO
	_hybrid_view_cache = null
	_set_projection_hidden(false)

func _set_projection_hidden(hidden: bool) -> void:
	if hidden == _projection_hidden:
		return
	_projection_hidden = hidden
	if hidden:
		_visible_before_projection_hide = visible
		visible = false
	else:
		visible = _visible_before_projection_hide

func _exit_tree() -> void:
	_hybrid_view_cache = null

func world_direction_to_screen(direction: Vector2) -> Vector2:
	var hybrid_view := _get_hybrid_view()
	var parent_2d := get_parent() as Node2D
	if hybrid_view == null or parent_2d == null or direction == Vector2.ZERO:
		return direction
	var logical_anchor := parent_2d.global_transform * _base_transform.origin
	return (hybrid_view.call("world_vector_to_screen", direction, logical_anchor) as Vector2).normalized()

func _apply_optional_perspective_scale(screen_position: Vector2) -> void:
	if perspective_scale_amount <= 0.0:
		return
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var depth := clampf(screen_position.y / viewport_height, 0.0, 1.0)
	var target_scale := lerpf(perspective_min_scale, perspective_max_scale, depth)
	var applied_scale := lerpf(1.0, target_scale, perspective_scale_amount)
	scale *= applied_scale
