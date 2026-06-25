extends RefCounted

var _owner: Node2D
var _bounds_shape_path: NodePath
var _grid_dim: int = 3
var _zone_count: int = 9
var _interactive_zone_ids: Array[int] = []

func setup(
	owner_node: Node2D,
	bounds_shape_path: NodePath,
	grid_dim: int,
	zone_count: int,
	interactive_zone_ids: Array[int]
) -> void:
	_owner = owner_node
	_bounds_shape_path = bounds_shape_path
	_grid_dim = maxi(grid_dim, 1)
	_zone_count = maxi(zone_count, 1)
	_interactive_zone_ids = interactive_zone_ids.duplicate()

func get_bounds_local_rect() -> Rect2:
	if _owner == null or not is_instance_valid(_owner):
		return Rect2()
	var shape_node := _owner.get_node_or_null(_bounds_shape_path) as CollisionShape2D
	if shape_node == null:
		return Rect2()
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2()
	var abs_scale := shape_node.scale.abs()
	var size := Vector2(rect_shape.size.x * abs_scale.x, rect_shape.size.y * abs_scale.y)
	return Rect2(shape_node.position - size * 0.5, size)

func get_zone_rect_local(zone_id: int) -> Rect2:
	if zone_id < 0 or zone_id >= _zone_count:
		return Rect2()
	var bounds := get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Rect2()
	var zone_w := bounds.size.x / float(_grid_dim)
	var zone_h := bounds.size.y / float(_grid_dim)
	var row := int(zone_id / _grid_dim)
	var col := zone_id % _grid_dim
	return Rect2(
		bounds.position + Vector2(float(col) * zone_w, float(row) * zone_h),
		Vector2(zone_w, zone_h)
	)

func get_zone_center_global(zone_id: int) -> Vector2:
	if _owner == null or not is_instance_valid(_owner):
		return Vector2.ZERO
	var zone_rect := get_zone_rect_local(zone_id)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		if _owner.has_method("get_spawn_position"):
			return _owner.call("get_spawn_position")
		return _owner.global_position
	return _owner.to_global(zone_rect.get_center())

func get_zone_id_for_global_point(global_pos: Vector2) -> int:
	if _owner == null or not is_instance_valid(_owner):
		return -1
	var bounds := get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return -1
	var local_pos := _owner.to_local(global_pos)
	if not bounds.has_point(local_pos):
		return -1
	var zone_w := bounds.size.x / float(_grid_dim)
	var zone_h := bounds.size.y / float(_grid_dim)
	if zone_w <= 0.0 or zone_h <= 0.0:
		return -1
	var col := clampi(int(floor((local_pos.x - bounds.position.x) / zone_w)), 0, _grid_dim - 1)
	var row := clampi(int(floor((local_pos.y - bounds.position.y) / zone_h)), 0, _grid_dim - 1)
	return row * _grid_dim + col

func zone_opens_interaction(zone_id: int) -> bool:
	return _interactive_zone_ids.has(zone_id)
