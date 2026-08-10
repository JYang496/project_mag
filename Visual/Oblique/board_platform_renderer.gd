class_name BoardPlatformRenderer
extends RefCounted

const BoundaryBuilderType := preload("res://Visual/Oblique/board_support_boundary_builder.gd")
const SkirtAtlas := preload(
	"res://Visual/Oblique/assets/board_support/industrial_board_skirt_atlas.png"
)

## Version 3: a low-profile graphite frame plus an authored, worn industrial
## skirt. The skirt repeats the floor's blue-gray steel, plate seams, rivet
## scale, and muted safety-orange lip; cyan remains a sparse equipment signal.
const DEFAULT_BOUNDARY_SAMPLE_2D := 512.0
const CONTACT_RIM_WIDTH_2D := 8.0
const CONTACT_RIM_TOP_Y := 0.012
const CONTACT_RIM_BOTTOM_Y := -0.030
const UNDERLAYER_WIDTH_2D := 18.0
const UNDERLAYER_TOP_Y := -0.036
const UNDERLAYER_BOTTOM_Y := -0.420
const LOW_PROFILE_RAIL_WIDTH_2D := 14.0
const LOW_PROFILE_RAIL_TOP_Y := 0.004
const LOW_PROFILE_RAIL_BOTTOM_Y := -0.280
const OUTER_OUTLINE_OFFSET_2D := 14.0
const OUTER_OUTLINE_WIDTH_2D := 3.0
const OUTER_OUTLINE_TOP_Y := 0.008
const OUTER_OUTLINE_BOTTOM_Y := -0.090
const CORNER_NODE_SIZE_2D := 22.0
const CORNER_NODE_OFFSET_2D := 7.0
const CORNER_NODE_BOTTOM_Y := -0.220
const CORNER_NODE_TOP_Y := 0.010
const CORNER_CORE_SIZE_2D := 10.0
const CORNER_CORE_TOP_Y := 0.018
const SIGNAL_TRACE_WIDTH_2D := 2.0
const SIGNAL_TRACE_LENGTH_2D := 8.0
const SIGNAL_TRACE_INTERVAL_2D := 192.0
const SIGNAL_TRACE_OFFSET_2D := 9.0
const SIGNAL_TRACE_BOTTOM_Y := 0.009
const SIGNAL_TRACE_TOP_Y := 0.015
const TRANSITION_BAND_WIDTH_2D := 56.0
const TRANSITION_TILE_MIN_SIZE_2D := 4.0
const TRANSITION_TILE_MAX_SIZE_2D := 8.0
const TRANSITION_TILE_STRIDE_2D := 12.0
const TRANSITION_CANDIDATES_PER_SLOT := 5
const TRANSITION_PLANE_Y := -0.010
const EDGE_OVERLAP_WORLD := 0.010
const MAX_TRANSITION_SLOTS_PER_ROW := 256
const MAX_TRANSITION_TOTAL_TILES := 4096
const SKIRT_LOGICAL_MODULE_WIDTH := 128.0
const SKIRT_TOP_Y := 0.012
const SKIRT_BOTTOM_Y := -0.860
# Keep the authored facade in front of the 18px structural underlayer. The
# former 0.012 offset left the dark collision-support prism closer to the
# oblique camera, visually replacing the atlas with one flat black slab.
const SKIRT_OUTWARD_OFFSET_WORLD := 0.200
const SKIRT_ATLAS_COLUMNS := 4
const SKIRT_ATLAS_ROWS := 4
const CORNER_TRANSITION_LENGTH_2D := 56.0
const SKIRT_TOP_HIGHLIGHT_DIM := 0.85
const ATLAS_PIXEL_SIZE := 256.0
const ATLAS_UV_INSET_PIXELS := 0.5
const MAX_SKIRT_MODULES_PER_SEGMENT := 128

const CONTACT_RIM_COLOR := Color(0.13, 0.16, 0.19, 1.0)
const UNDERLAYER_COLOR := Color(0.018, 0.026, 0.034, 1.0)
const RAIL_COLOR := Color(0.045, 0.058, 0.070, 1.0)
const OUTER_OUTLINE_COLOR := Color(0.10, 0.14, 0.17, 1.0)
const CORNER_NODE_COLOR := Color(0.11, 0.15, 0.17, 1.0)
const STRUCTURE_SIGNAL_COLOR := Color(0.025, 0.42, 0.54, 1.0)
const TRANSITION_NEAR_COLOR := Color(0.16, 0.19, 0.21, 1.0)
const TRANSITION_FAR_COLOR := Color(0.032, 0.044, 0.054, 1.0)
const TRANSITION_ACCENT_COLOR := Color(0.035, 0.32, 0.42, 1.0)

var _view: Node
var _visual_nodes: Array[Node3D] = []
var _last_model: Dictionary = {}


func setup(view: Node) -> void:
	_view = view


func rebuild(cells: Array) -> void:
	clear()
	if not _is_ready():
		return
	var rects := collect_active_cell_rects(cells)
	_last_model = BoundaryBuilderType.build_model(rects, DEFAULT_BOUNDARY_SAMPLE_2D)
	var segments := _last_model.get("segments", []) as Array
	if segments.is_empty():
		return
	_last_model["underlayer_segment_count"] = _create_underlayer(segments)
	_create_contact_rim(segments)
	_last_model["outer_outline_segment_count"] = _create_outer_outline(segments)
	var front_skirt_result := _create_front_skirt(segments)
	_last_model["front_skirt_module_count"] = int(front_skirt_result.get("count", 0))
	_last_model["front_skirt_sequences"] = front_skirt_result.get("sequences", [])
	var upper_and_side_segments := segments.filter(func(segment_variant: Variant) -> bool:
		return (segment_variant as Dictionary).get("edge", &"") != &"bottom"
	)
	_last_model["low_profile_rail_edges"] = _segment_edge_names(upper_and_side_segments)
	_last_model["transition_band_edges"] = _segment_edge_names(upper_and_side_segments)
	_last_model["low_profile_rail_segment_count"] = _create_low_profile_rail(upper_and_side_segments)
	var transition_result := _create_transition_band(upper_and_side_segments, rects)
	_last_model["transition_tile_count"] = int(transition_result.get("count", 0))
	_last_model["transition_footprints"] = transition_result.get("footprints", [])
	_last_model["transition_outward_ratios"] = transition_result.get("outward_ratios", PackedFloat32Array())
	_last_model["transition_tile_sizes"] = transition_result.get("tile_sizes", PackedFloat32Array())
	_last_model["transition_guard_triggered"] = bool(transition_result.get("guard_triggered", false))
	_last_model["transition_rejected_segment_count"] = int(transition_result.get("rejected_segments", 0))
	_last_model["transition_capped_row_count"] = int(transition_result.get("capped_rows", 0))
	var corner_result := _create_corner_nodes(segments)
	_last_model["corner_node_count"] = int(corner_result.get("count", 0))
	_last_model["corner_node_points"] = corner_result.get("points", PackedVector2Array())
	_last_model["signal_trace_count"] = _create_signal_traces(segments)


static func build_skirt_module_sequence(segment_length: float) -> PackedStringArray:
	var sequence := PackedStringArray()
	if not is_finite(segment_length) or segment_length <= 0.0:
		return sequence
	var module_count := clampi(
		roundi(segment_length / SKIRT_LOGICAL_MODULE_WIDTH),
		2,
		MAX_SKIRT_MODULES_PER_SEGMENT
	)
	for index in range(module_count):
		if index == 0:
			sequence.append("left_cap")
		elif index == module_count - 1:
			sequence.append("right_cap")
		elif index % 4 == 0:
			sequence.append("seam_middle")
		elif index % 4 == 2:
			var board_index := floori(float(index) / 4.0)
			sequence.append("detail_middle_a" if board_index % 2 == 0 else "detail_middle_b")
		else:
			sequence.append("plain_middle")
	return sequence


func clear() -> void:
	for node in _visual_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	_visual_nodes.clear()
	_last_model = {}


func get_last_model() -> Dictionary:
	return _last_model.duplicate(true)


func collect_active_cell_rects(cells: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell_variant in cells:
		var cell := cell_variant as Node2D
		if cell == null or not bool(cell.get("board_enabled")):
			continue
		var sprite := cell.get_node_or_null("Texture/Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var rect := _sprite_global_aabb(sprite)
		if rect.position.is_finite() and rect.size.is_finite() \
				and rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _sprite_global_aabb(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var local_corners := PackedVector2Array([
		local_rect.position,
		Vector2(local_rect.end.x, local_rect.position.y),
		local_rect.end,
		Vector2(local_rect.position.x, local_rect.end.y),
	])
	var first := sprite.global_transform * local_corners[0]
	var minimum := first
	var maximum := first
	for index in range(1, local_corners.size()):
		var point := sprite.global_transform * local_corners[index]
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _create_contact_rim(segments: Array) -> void:
	var boxes: Array[AABB] = []
	for segment_variant in segments:
		boxes.append(
			_edge_prism(
				segment_variant as Dictionary,
				CONTACT_RIM_WIDTH_2D,
				CONTACT_RIM_BOTTOM_Y,
				CONTACT_RIM_TOP_Y
			)
		)
	_add_box_mesh("BoardSupportContactRim", boxes, _solid_material(CONTACT_RIM_COLOR))


func _create_underlayer(segments: Array) -> int:
	var boxes: Array[AABB] = []
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		if not _valid_segment(segment):
			continue
		boxes.append(
			_edge_prism(
				segment,
				UNDERLAYER_WIDTH_2D,
				UNDERLAYER_BOTTOM_Y,
				UNDERLAYER_TOP_Y
			)
		)
	_add_box_mesh("BoardSupportDarkUnderlayer", boxes, _solid_material(UNDERLAYER_COLOR))
	return boxes.size()


func _create_outer_outline(segments: Array) -> int:
	var boxes: Array[AABB] = []
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		if not _valid_segment(segment):
			continue
		var outline_segment := _offset_segment(segment, OUTER_OUTLINE_OFFSET_2D)
		boxes.append(
			_edge_prism(
				outline_segment,
				OUTER_OUTLINE_WIDTH_2D,
				OUTER_OUTLINE_BOTTOM_Y,
				OUTER_OUTLINE_TOP_Y
			)
		)
	_add_box_mesh("BoardSupportContinuousOutline", boxes, _solid_material(OUTER_OUTLINE_COLOR))
	return boxes.size()


func _create_front_skirt(segments: Array) -> Dictionary:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sequences: Array[PackedStringArray] = []
	var module_total := 0
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		if segment.get("edge", &"") != &"bottom":
			continue
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var outward := segment.get("outward", Vector2.DOWN) as Vector2
		if not start.is_finite() or not end.is_finite() or not outward.is_finite():
			continue
		var length := start.distance_to(end)
		if not is_finite(length) or length <= 1.0:
			continue
		var direction := (end - start) / length
		var sequence := build_skirt_module_sequence(length)
		var module_width := length / float(sequence.size())
		for index in range(sequence.size()):
			var module_start := start + direction * (module_width * float(index))
			var module_end := start + direction * (module_width * float(index + 1))
			_append_skirt_quad(vertices, uvs, indices, module_start, module_end, outward, sequence[index])
		module_total += sequence.size()
		sequences.append(sequence)
	if vertices.is_empty():
		return {"count": 0, "sequences": sequences}
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _skirt_atlas_material())
	_add_mesh_instance("BoardSupportFrontSkirt", mesh)
	return {"count": module_total, "sequences": sequences}


func _append_skirt_quad(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	module_start: Vector2,
	module_end: Vector2,
	outward: Vector2,
	module_name: String
) -> void:
	var world_scale := _world_scale()
	var outward_offset := outward * (SKIRT_OUTWARD_OFFSET_WORLD / world_scale)
	var start := module_start + outward_offset
	var end := module_end + outward_offset
	var length := start.distance_to(end)
	if length <= 0.001:
		return
	var direction := (end - start) / length
	var ramp_length := minf(CORNER_TRANSITION_LENGTH_2D, length)
	var ramp_ratio := ramp_length / length
	if module_name == "left_cap":
		var ramp_end := start + direction * ramp_length
		_append_skirt_section(
			vertices, uvs, indices, start, ramp_end,
			LOW_PROFILE_RAIL_BOTTOM_Y, SKIRT_BOTTOM_Y,
			module_name, 0.0, ramp_ratio
		)
		if ramp_length < length - 0.001:
			_append_skirt_section(
				vertices, uvs, indices, ramp_end, end,
				SKIRT_BOTTOM_Y, SKIRT_BOTTOM_Y,
				module_name, ramp_ratio, 1.0
			)
		return
	if module_name == "right_cap":
		var ramp_start := end - direction * ramp_length
		if ramp_length < length - 0.001:
			_append_skirt_section(
				vertices, uvs, indices, start, ramp_start,
				SKIRT_BOTTOM_Y, SKIRT_BOTTOM_Y,
				module_name, 0.0, 1.0 - ramp_ratio
			)
		_append_skirt_section(
			vertices, uvs, indices, ramp_start, end,
			SKIRT_BOTTOM_Y, LOW_PROFILE_RAIL_BOTTOM_Y,
			module_name, 1.0 - ramp_ratio, 1.0
		)
		return
	_append_skirt_section(
		vertices, uvs, indices, start, end,
		SKIRT_BOTTOM_Y, SKIRT_BOTTOM_Y,
		module_name, 0.0, 1.0
	)


func _append_skirt_section(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	start: Vector2,
	end: Vector2,
	bottom_start_y: float,
	bottom_end_y: float,
	module_name: String,
	local_u0: float,
	local_u1: float
) -> void:
	var world_scale := _world_scale()
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(start.x * world_scale, SKIRT_TOP_Y, start.y * world_scale),
		Vector3(end.x * world_scale, SKIRT_TOP_Y, end.y * world_scale),
		Vector3(end.x * world_scale, bottom_end_y, end.y * world_scale),
		Vector3(start.x * world_scale, bottom_start_y, start.y * world_scale),
	]))
	var atlas_cell := _skirt_atlas_cell(module_name)
	var inset := ATLAS_UV_INSET_PIXELS / ATLAS_PIXEL_SIZE
	var cell_u := 1.0 / float(SKIRT_ATLAS_COLUMNS)
	var cell_v := 1.0 / float(SKIRT_ATLAS_ROWS)
	var cell_u0 := float(atlas_cell.x) * cell_u + inset
	var cell_u1 := float(atlas_cell.x + 1) * cell_u - inset
	var u0 := lerpf(cell_u0, cell_u1, local_u0)
	var u1 := lerpf(cell_u0, cell_u1, local_u1)
	var v0 := float(atlas_cell.y) * cell_v + inset
	var v1 := float(atlas_cell.y + 1) * cell_v - inset
	uvs.append_array(PackedVector2Array([
		Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1),
	]))
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _skirt_atlas_cell(module_name: String) -> Vector2i:
	match module_name:
		"left_cap":
			return Vector2i(0, 0)
		"plain_middle":
			return Vector2i(1, 0)
		"seam_middle":
			return Vector2i(2, 0)
		"detail_middle_a":
			return Vector2i(3, 0)
		"detail_middle_b":
			return Vector2i(0, 1)
		"right_cap":
			return Vector2i(1, 1)
		_:
			return Vector2i(1, 0)


func _create_low_profile_rail(segments: Array) -> int:
	var boxes: Array[AABB] = []
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var outward := segment.get("outward", Vector2.ZERO) as Vector2
		if not start.is_finite() or not end.is_finite() or not outward.is_finite():
			continue
		if start.distance_to(end) <= 1.0:
			continue
		boxes.append(
			_edge_prism(
				segment,
				LOW_PROFILE_RAIL_WIDTH_2D,
				LOW_PROFILE_RAIL_BOTTOM_Y,
				LOW_PROFILE_RAIL_TOP_Y
			)
		)
	_add_box_mesh("BoardSupportLowProfileRail", boxes, _solid_material(RAIL_COLOR))
	return boxes.size()


func _create_corner_nodes(segments: Array) -> Dictionary:
	var corner_data: Dictionary = {}
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		if not _valid_segment(segment):
			continue
		var outward := segment.get("outward", Vector2.ZERO) as Vector2
		for point_variant in [segment.get("start", Vector2.ZERO), segment.get("end", Vector2.ZERO)]:
			var point := point_variant as Vector2
			var key := "%.3f:%.3f" % [point.x, point.y]
			if not corner_data.has(key):
				corner_data[key] = {"point": point, "outward_sum": Vector2.ZERO}
			var entry := corner_data[key] as Dictionary
			entry["outward_sum"] = (entry.get("outward_sum", Vector2.ZERO) as Vector2) + outward
			corner_data[key] = entry
	var base_boxes: Array[AABB] = []
	var core_boxes: Array[AABB] = []
	var points := PackedVector2Array()
	for key_variant in corner_data:
		var entry := corner_data[key_variant] as Dictionary
		var point := entry.get("point", Vector2.ZERO) as Vector2
		var outward_sum := entry.get("outward_sum", Vector2.ZERO) as Vector2
		var direction := outward_sum.normalized() if outward_sum.length_squared() > 0.001 else Vector2.ZERO
		var center := point + direction * CORNER_NODE_OFFSET_2D
		base_boxes.append(_point_prism(center, CORNER_NODE_SIZE_2D, CORNER_NODE_BOTTOM_Y, CORNER_NODE_TOP_Y))
		core_boxes.append(_point_prism(center, CORNER_CORE_SIZE_2D, CORNER_NODE_TOP_Y, CORNER_CORE_TOP_Y))
		points.append(center)
	_add_box_mesh("BoardSupportCornerNodes", base_boxes, _solid_material(CORNER_NODE_COLOR))
	_add_box_mesh("BoardSupportCornerSignals", core_boxes, _solid_material(STRUCTURE_SIGNAL_COLOR))
	return {"count": points.size(), "points": points}


func _create_signal_traces(segments: Array) -> int:
	var boxes: Array[AABB] = []
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		if not _valid_segment(segment):
			continue
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var length := start.distance_to(end)
		var direction := (end - start) / length
		var trace_count := maxi(1, floori(length / SIGNAL_TRACE_INTERVAL_2D))
		for trace_index in range(trace_count):
			var ratio := (float(trace_index) + 0.5) / float(trace_count)
			var center_distance := length * ratio
			var half_length := minf(SIGNAL_TRACE_LENGTH_2D * 0.5, length * 0.2)
			var trace_segment := segment.duplicate()
			trace_segment["start"] = start + direction * (center_distance - half_length)
			trace_segment["end"] = start + direction * (center_distance + half_length)
			trace_segment = _offset_segment(trace_segment, SIGNAL_TRACE_OFFSET_2D)
			boxes.append(
				_edge_prism(
					trace_segment,
					SIGNAL_TRACE_WIDTH_2D,
					SIGNAL_TRACE_BOTTOM_Y,
					SIGNAL_TRACE_TOP_Y
				)
			)
	_add_box_mesh("BoardSupportSignalTraces", boxes, _solid_material(STRUCTURE_SIGNAL_COLOR))
	return boxes.size()


func _segment_edge_names(segments: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for segment_variant in segments:
		var edge := String((segment_variant as Dictionary).get("edge", &""))
		if edge != "" and not result.has(edge):
			result.append(edge)
	return result


func _create_transition_band(segments: Array, board_rects: Array[Rect2] = []) -> Dictionary:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var result := {
		"count": 0,
		"footprints": [],
		"outward_ratios": PackedFloat32Array(),
		"tile_sizes": PackedFloat32Array(),
		"guard_triggered": false,
		"rejected_segments": 0,
		"capped_rows": 0,
	}
	var total_limit_reached := false
	for segment_index in range(segments.size()):
		var segment := segments[segment_index] as Dictionary
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var outward := segment.get("outward", Vector2.ZERO) as Vector2
		if not start.is_finite() or not end.is_finite() or not outward.is_finite():
			result["guard_triggered"] = true
			result["rejected_segments"] = int(result["rejected_segments"]) + 1
			continue
		var length := start.distance_to(end)
		if not is_finite(length) or length <= 1.0:
			if not is_finite(length):
				result["guard_triggered"] = true
				result["rejected_segments"] = int(result["rejected_segments"]) + 1
			continue
		var tangent := (end - start) / length
		var slot_layout := calculate_transition_slot_layout(
			length,
			TRANSITION_TILE_MAX_SIZE_2D,
			TRANSITION_TILE_STRIDE_2D
		)
		if bool(slot_layout.get("guard_triggered", false)):
			result["guard_triggered"] = true
			result["capped_rows"] = int(result["capped_rows"]) + 1
		var slot_count := int(slot_layout.get("count", 0))
		var slot_stride := float(slot_layout.get("stride", TRANSITION_TILE_STRIDE_2D))
		for slot_index in range(slot_count):
			for candidate_index in range(TRANSITION_CANDIDATES_PER_SLOT):
				if int(result["count"]) >= MAX_TRANSITION_TOTAL_TILES:
					result["guard_triggered"] = true
					total_limit_reached = true
					break
				var hash_value := _transition_hash(segment_index, candidate_index, slot_index)
				var outward_ratio := _transition_outward_ratio(hash_value)
				var acceptance_hash := _transition_hash(segment_index + 19, candidate_index + 11, slot_index + 23)
				if not _transition_accepts(outward_ratio, acceptance_hash):
					continue
				var tile_size := _transition_tile_size(hash_value, outward_ratio)
				var tangent_jitter_hash := _transition_hash(segment_index + 31, candidate_index + 7, slot_index + 13)
				var tangent_jitter := float(tangent_jitter_hash % 9 - 4)
				var cursor := tile_size * 0.5 + slot_stride * float(slot_index) + tangent_jitter
				cursor = clampf(cursor, tile_size * 0.5, length - tile_size * 0.5)
				var inner_center := LOW_PROFILE_RAIL_WIDTH_2D + tile_size * 0.5
				var outer_center := TRANSITION_BAND_WIDTH_2D - tile_size * 0.5
				var outward_distance := lerpf(inner_center, outer_center, outward_ratio)
				var center := start + tangent * cursor + outward * outward_distance
				var footprint := _transition_footprint(center, tangent, tile_size)
				if _footprint_overlaps_board(footprint, board_rects):
					continue
				var color := _transition_tile_color(outward_ratio, hash_value)
				_append_ground_tile(vertices, colors, indices, center, tangent, outward, tile_size, color)
				(result["footprints"] as Array).append(footprint)
				var recorded_ratios := result["outward_ratios"] as PackedFloat32Array
				recorded_ratios.append(outward_ratio)
				result["outward_ratios"] = recorded_ratios
				var recorded_sizes := result["tile_sizes"] as PackedFloat32Array
				recorded_sizes.append(tile_size)
				result["tile_sizes"] = recorded_sizes
				result["count"] = int(result["count"]) + 1
			if total_limit_reached:
				break
		if total_limit_reached:
			break
	if vertices.is_empty():
		return result
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _transition_material())
	_add_mesh_instance("BoardSupportTransitionBand", mesh)
	return result


static func calculate_transition_slot_layout(
	segment_length: float,
	tile_size: float,
	requested_stride: float
) -> Dictionary:
	if not is_finite(segment_length) or not is_finite(tile_size) \
			or not is_finite(requested_stride) or segment_length <= 0.0 \
			or tile_size <= 0.0 or requested_stride <= 0.0:
		return {"count": 0, "stride": 0.0, "guard_triggered": true}
	var available_distance := maxf(segment_length - tile_size, 0.0)
	var uncapped_last_slot_distance := requested_stride * float(MAX_TRANSITION_SLOTS_PER_ROW - 1)
	if available_distance > uncapped_last_slot_distance:
		return {
			"count": MAX_TRANSITION_SLOTS_PER_ROW,
			"stride": available_distance / float(MAX_TRANSITION_SLOTS_PER_ROW - 1),
			"guard_triggered": true,
		}
	return {
		"count": floori((available_distance + 0.01) / requested_stride) + 1,
		"stride": requested_stride,
		"guard_triggered": false,
	}


func _transition_hash(segment_index: int, row_index: int, slot_index: int) -> int:
	return abs(
		(segment_index + 1) * 73856093 \
			^ (row_index + 3) * 19349663 \
			^ (slot_index + 7) * 83492791
	)


func _transition_outward_ratio(hash_value: int) -> float:
	return float(hash_value % 997) / 996.0


func _transition_accepts(outward_ratio: float, hash_value: int) -> bool:
	var distance_ratio := clampf(outward_ratio, 0.0, 1.0)
	# About one third fewer fragments overall than the former 0.96 -> 0.32
	# distribution, with a steeper falloff that reads as authored clusters.
	var threshold := lerpf(0.72, 0.10, distance_ratio)
	var roll := float(hash_value % 1000) / 999.0
	return roll <= threshold


func _transition_tile_size(hash_value: int, outward_ratio: float = 0.0) -> float:
	var base_size := TRANSITION_TILE_MIN_SIZE_2D
	match hash_value % 3:
		0:
			base_size = 4.0
		1:
			base_size = 6.0
		_:
			base_size = 8.0
	var distance_ratio := clampf(outward_ratio, 0.0, 1.0)
	var distance_size_cap := lerpf(
		TRANSITION_TILE_MAX_SIZE_2D,
		TRANSITION_TILE_MIN_SIZE_2D,
		distance_ratio
	)
	return maxf(
		TRANSITION_TILE_MIN_SIZE_2D,
		floorf(minf(base_size, distance_size_cap) * 0.5) * 2.0
	)


func _transition_tile_color(outward_ratio: float, hash_value: int) -> Color:
	if hash_value % 31 == 0:
		return TRANSITION_ACCENT_COLOR.lerp(TRANSITION_FAR_COLOR, outward_ratio * 0.55)
	return TRANSITION_NEAR_COLOR.lerp(TRANSITION_FAR_COLOR, clampf(outward_ratio, 0.0, 1.0))


func _append_ground_tile(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	center: Vector2,
	tangent: Vector2,
	outward: Vector2,
	tile_size: float,
	color: Color
) -> void:
	var world_scale := _world_scale()
	var tangent_half := tangent * tile_size * 0.5
	var outward_half := outward * tile_size * 0.5
	var corners := PackedVector2Array([
		center - tangent_half - outward_half,
		center + tangent_half - outward_half,
		center + tangent_half + outward_half,
		center - tangent_half + outward_half,
	])
	var base := vertices.size()
	for corner in corners:
		vertices.append(Vector3(corner.x * world_scale, TRANSITION_PLANE_Y, corner.y * world_scale))
		colors.append(color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _transition_footprint(center: Vector2, tangent: Vector2, tile_size: float) -> Rect2:
	var size := Vector2(tile_size, tile_size)
	if absf(tangent.y) > absf(tangent.x):
		size = Vector2(tile_size, tile_size)
	return Rect2(center - size * 0.5, size)


func _footprint_overlaps_board(footprint: Rect2, board_rects: Array[Rect2]) -> bool:
	var inset_footprint := footprint.grow(-0.05)
	for board_rect in board_rects:
		if inset_footprint.intersects(board_rect.grow(-0.05), false):
			return true
	return false


func _transition_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _skirt_atlas_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D skirt_texture : source_color, filter_nearest, repeat_disable;
uniform float top_highlight_dim : hint_range(0.0, 1.0) = 0.85;
uniform float atlas_rows = 4.0;

void fragment() {
	vec4 texel = texture(skirt_texture, UV);
	float local_v = fract(UV.y * atlas_rows);
	float top_highlight = 1.0 - step(0.18, local_v);
	float brightness = mix(1.0, top_highlight_dim, top_highlight);
	ALBEDO = texel.rgb * brightness;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("skirt_texture", SkirtAtlas)
	material.set_shader_parameter("top_highlight_dim", SKIRT_TOP_HIGHLIGHT_DIM)
	material.set_shader_parameter("atlas_rows", float(SKIRT_ATLAS_ROWS))
	return material


func _valid_segment(segment: Dictionary) -> bool:
	var start := segment.get("start", Vector2.ZERO) as Vector2
	var end := segment.get("end", Vector2.ZERO) as Vector2
	var outward := segment.get("outward", Vector2.ZERO) as Vector2
	return start.is_finite() and end.is_finite() and outward.is_finite() \
		and start.distance_to(end) > 1.0


func _offset_segment(segment: Dictionary, distance_2d: float) -> Dictionary:
	var shifted := segment.duplicate()
	var outward := segment.get("outward", Vector2.ZERO) as Vector2
	var offset := outward * distance_2d
	shifted["start"] = (segment.get("start", Vector2.ZERO) as Vector2) + offset
	shifted["end"] = (segment.get("end", Vector2.ZERO) as Vector2) + offset
	return shifted


func _point_prism(point: Vector2, size_2d: float, bottom_y: float, top_y: float) -> AABB:
	var world_scale := _world_scale()
	var half_size := size_2d * world_scale * 0.5
	return AABB(
		Vector3(point.x * world_scale - half_size, bottom_y, point.y * world_scale - half_size),
		Vector3(size_2d * world_scale, top_y - bottom_y, size_2d * world_scale)
	)


func _edge_prism(segment: Dictionary, width_2d: float, bottom_y: float, top_y: float) -> AABB:
	var world_scale := _world_scale()
	var start := segment.get("start", Vector2.ZERO) as Vector2
	var end := segment.get("end", Vector2.ZERO) as Vector2
	var outward := segment.get("outward", Vector2.ZERO) as Vector2
	var width := width_2d * world_scale
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	if absf(end.x - start.x) >= absf(end.y - start.y):
		minimum.x = minf(start.x, end.x) * world_scale - EDGE_OVERLAP_WORLD
		maximum.x = maxf(start.x, end.x) * world_scale + EDGE_OVERLAP_WORLD
		var z := start.y * world_scale
		minimum.z = z - width if outward.y < 0.0 else z - EDGE_OVERLAP_WORLD
		maximum.z = z + EDGE_OVERLAP_WORLD if outward.y < 0.0 else z + width
	else:
		minimum.z = minf(start.y, end.y) * world_scale - EDGE_OVERLAP_WORLD
		maximum.z = maxf(start.y, end.y) * world_scale + EDGE_OVERLAP_WORLD
		var x := start.x * world_scale
		minimum.x = x - width if outward.x < 0.0 else x - EDGE_OVERLAP_WORLD
		maximum.x = x + EDGE_OVERLAP_WORLD if outward.x < 0.0 else x + width
	minimum.y = bottom_y
	maximum.y = top_y
	return AABB(minimum, maximum - minimum)


func _add_box_mesh(mesh_name: String, boxes: Array[AABB], material: Material) -> void:
	if boxes.is_empty():
		return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for box in boxes:
		_append_box(vertices, indices, box)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_add_mesh_instance(mesh_name, mesh)


func _append_box(vertices: PackedVector3Array, indices: PackedInt32Array, box: AABB) -> void:
	var p := box.position
	var e := box.end
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(p.x, p.y, p.z), Vector3(e.x, p.y, p.z), Vector3(e.x, e.y, p.z), Vector3(p.x, e.y, p.z),
		Vector3(p.x, p.y, e.z), Vector3(e.x, p.y, e.z), Vector3(e.x, e.y, e.z), Vector3(p.x, e.y, e.z),
	]))
	indices.append_array(PackedInt32Array([
		base, base + 2, base + 1, base, base + 3, base + 2,
		base + 4, base + 5, base + 6, base + 4, base + 6, base + 7,
		base, base + 4, base + 7, base, base + 7, base + 3,
		base + 1, base + 2, base + 6, base + 1, base + 6, base + 5,
		base + 3, base + 7, base + 6, base + 3, base + 6, base + 2,
		base, base + 1, base + 5, base, base + 5, base + 4,
	]))


func _add_mesh_instance(mesh_name: String, mesh: Mesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	_add_geometry(instance)


func _add_geometry(instance: GeometryInstance3D) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(&"hybrid_board_visual", true)
	instance.set_meta(&"board_support_visual", true)
	instance.visible = bool(_view.get("_board_visual_active"))
	_view._ground_root.add_child(instance)
	_visual_nodes.append(instance)


func _solid_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _world_scale() -> float:
	return maxf(float(_view.get("world_scale")), 0.0001)


func _is_ready() -> bool:
	return _view != null \
		and is_instance_valid(_view) \
		and _view.get("_ground_root") != null \
		and is_instance_valid(_view._ground_root)
