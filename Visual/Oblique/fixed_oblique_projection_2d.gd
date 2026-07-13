class_name FixedObliqueProjection2D
extends RefCounted

const MIN_VERTICAL_SCALE: float = 0.001
static var _enabled: bool = true
static var _yaw_radians: float = deg_to_rad(-6.0)
static var _vertical_scale: float = 0.90
static var _billboard_scale: float = 1.0
static var _projection := Transform2D.IDENTITY
static var _inverse_projection := Transform2D.IDENTITY
static var _billboard_compensation := Transform2D.IDENTITY

static func configure(enabled: bool, fixed_yaw_degrees: float, ground_vertical_scale: float, billboard_scale: float) -> void:
	var safe_scale := maxf(absf(ground_vertical_scale), MIN_VERTICAL_SCALE)
	var safe_billboard := maxf(absf(billboard_scale), MIN_VERTICAL_SCALE)
	var yaw := deg_to_rad(fixed_yaw_degrees)
	if _enabled == enabled and is_equal_approx(_yaw_radians, yaw) and is_equal_approx(_vertical_scale, safe_scale) and is_equal_approx(_billboard_scale, safe_billboard):
		return
	_enabled = enabled
	_yaw_radians = yaw
	_vertical_scale = safe_scale
	_billboard_scale = safe_billboard
	_rebuild_transforms()

static func world_vector_to_screen(vector: Vector2) -> Vector2:
	return vector if not _enabled or vector == Vector2.ZERO else _projection.basis_xform(vector)

static func screen_vector_to_world(vector: Vector2) -> Vector2:
	return vector if not _enabled or vector == Vector2.ZERO else _inverse_projection.basis_xform(vector)

static func get_billboard_compensation_transform() -> Transform2D:
	return _billboard_compensation

static func get_projected_depth(world_position: Vector2) -> float:
	return world_vector_to_screen(world_position).y

static func get_fixed_yaw_radians() -> float:
	return _yaw_radians if _enabled else 0.0

static func is_enabled() -> bool:
	return _enabled

static func _rebuild_transforms() -> void:
	if not _enabled:
		_projection = Transform2D.IDENTITY
		_inverse_projection = Transform2D.IDENTITY
		_billboard_compensation = Transform2D.IDENTITY
		return
	var rotation_transform := Transform2D(_yaw_radians, Vector2.ZERO)
	var vertical_scale_transform := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, _vertical_scale), Vector2.ZERO)
	_projection = vertical_scale_transform * rotation_transform
	_inverse_projection = _projection.affine_inverse()
	_billboard_compensation = _inverse_projection.scaled(Vector2.ONE * _billboard_scale)
