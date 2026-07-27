extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const BoundaryBuilderType := preload("res://Visual/Oblique/board_support_boundary_builder.gd")
const PlatformRendererType := preload("res://Visual/Oblique/board_platform_renderer.gd")

class DummyView:
	extends Node3D
	var world_scale := 0.01
	var _board_visual_active := true
	var _ground_root: Node3D

	func _init() -> void:
		_ground_root = Node3D.new()
		_ground_root.name = "GroundMeshes"
		add_child(_ground_root)

class DummyCell:
	extends Node2D
	var board_enabled := true

	func configure(cell_size: Vector2, cell_position: Vector2) -> void:
		position = cell_position
		var texture_root := Node2D.new()
		texture_root.name = "Texture"
		texture_root.position = cell_size * 0.5
		add_child(texture_root)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		var texture := GradientTexture2D.new()
		texture.width = maxi(roundi(cell_size.x), 1)
		texture.height = maxi(roundi(cell_size.y), 1)
		sprite.texture = texture
		texture_root.add_child(sprite)

var _failed := false
var _created_nodes: Array[Node] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_regular_grid_outline()
	_test_mixed_cell_sizes_and_partial_shared_edge()
	_test_low_profile_geometry_contract()
	_test_transition_density_and_guards()
	await _test_renderer_runtime_model()
	if _failed:
		print("FAIL: board platform support")
	else:
		print("PASS: board platform support")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, Callable(), _created_nodes)


func _test_regular_grid_outline() -> void:
	var rects: Array[Rect2] = []
	for y in range(3):
		for x in range(3):
			rects.append(Rect2(Vector2(x, y) * 510.0, Vector2(510.0, 510.0)))
	var model := BoundaryBuilderType.build_model(rects, 510.0)
	var segments := model.get("segments", []) as Array
	_assert_equal(4, segments.size(), "A complete 3x3 board must merge into four continuous outer edges.")
	_assert_near(6120.0, float(model.get("perimeter", 0.0)), 0.01, "A complete 3x3 board must have the expected perimeter.")
	_assert_closed_outline(segments, "Complete 3x3 board")


func _test_mixed_cell_sizes_and_partial_shared_edge() -> void:
	var rects := [
		Rect2(Vector2.ZERO, Vector2(512.0, 512.0)),
		Rect2(Vector2(512.0, 128.0), Vector2(256.0, 256.0)),
	]
	var model := BoundaryBuilderType.build_model(rects, 256.0)
	var segments := model.get("segments", []) as Array
	_assert_near(2560.0, float(model.get("perimeter", 0.0)), 0.01, "Partial shared edges must be removed from mixed-size cell perimeter.")
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var is_internal_shared_edge := absf(start.x - 512.0) <= 0.01 \
			and absf(end.x - 512.0) <= 0.01 \
			and minf(start.y, end.y) < 384.0 - 0.01 \
			and maxf(start.y, end.y) > 128.0 + 0.01
		_assert_true(not is_internal_shared_edge, "Mixed-size cells must not create a support wall on their shared edge.")
	_assert_closed_outline(segments, "Mixed-size board")


func _test_low_profile_geometry_contract() -> void:
	_assert_true(PlatformRendererType.CONTACT_RIM_TOP_Y > 0.0, "The contact rim must cover the floor seam from above.")
	_assert_true(
		PlatformRendererType.LOW_PROFILE_RAIL_TOP_Y <= PlatformRendererType.CONTACT_RIM_TOP_Y,
		"The neutral rail must meet the contact rim without protruding above it."
	)
	_assert_true(
		PlatformRendererType.LOW_PROFILE_RAIL_BOTTOM_Y < PlatformRendererType.CONTACT_RIM_BOTTOM_Y,
		"The rail must provide visible depth below the contact rim."
	)
	var rail_height := PlatformRendererType.LOW_PROFILE_RAIL_TOP_Y - PlatformRendererType.LOW_PROFILE_RAIL_BOTTOM_Y
	_assert_true(rail_height <= 0.32, "Version 2 rail must remain low-profile instead of restoring the tall platform skirt.")
	_assert_true(
		PlatformRendererType.TRANSITION_BAND_WIDTH_2D <= 56.0,
		"Version 2 transition must remain a single compact band."
	)
	_assert_true(
		_max_channel_delta(PlatformRendererType.RAIL_COLOR) <= 0.03,
		"The main rail must remain hue-neutral for multi-color boards."
	)
	_assert_equal(
		PackedStringArray(["left_cap", "plain_middle", "detail_middle_a", "right_cap"]),
		PlatformRendererType.build_skirt_module_sequence(512.0),
		"The preserved lower skirt must retain its original modular sequence."
	)
	_assert_true(
		PlatformRendererType.CORNER_TRANSITION_LENGTH_2D >= 48.0 \
			and PlatformRendererType.CORNER_TRANSITION_LENGTH_2D <= 64.0,
		"The lower corner adapter must use the reviewed 48-64 pixel transition length."
	)
	_assert_near(0.85, PlatformRendererType.SKIRT_TOP_HIGHLIGHT_DIM, 0.001, "The skirt top highlight must be reduced by 15%.")


func _test_transition_density_and_guards() -> void:
	var view := DummyView.new()
	view.name = "TransitionContractView"
	add_child(view)
	_created_nodes.append(view)
	var renderer := PlatformRendererType.new()
	renderer.setup(view)
	var accepted_counts := PackedInt32Array()
	for outward_ratio in [0.1, 0.5, 0.9]:
		var accepted := 0
		for slot_index in range(2048):
			var hash_value := renderer._transition_hash(0, 0, slot_index)
			if renderer._transition_accepts(float(outward_ratio), hash_value):
				accepted += 1
		accepted_counts.append(accepted)
	_assert_true(
		accepted_counts[0] > accepted_counts[1] and accepted_counts[1] > accepted_counts[2],
		"Transition density must fall continuously with actual outward distance."
	)
	var generated_sizes := {}
	for sample_index in range(128):
		var size := renderer._transition_tile_size(renderer._transition_hash(0, 0, sample_index))
		generated_sizes[size] = true
	_assert_true(
		generated_sizes.has(4.0) and generated_sizes.has(6.0) and generated_sizes.has(8.0),
		"Irregular transition clusters must mix 4, 6, and 8 pixel tiles."
	)
	var normal_layout := PlatformRendererType.calculate_transition_slot_layout(512.0, 8.0, 12.0)
	_assert_equal(43, int(normal_layout.get("count", 0)), "A normal cell edge must keep a dense transition cadence.")
	_assert_true(not bool(normal_layout.get("guard_triggered", true)), "Normal geometry must not trigger transition guards.")
	var extreme_layout := PlatformRendererType.calculate_transition_slot_layout(1.0e9, 8.0, 12.0)
	_assert_equal(
		PlatformRendererType.MAX_TRANSITION_SLOTS_PER_ROW,
		int(extreme_layout.get("count", 0)),
		"Extreme geometry must remain bounded per transition row."
	)
	_assert_true(bool(extreme_layout.get("guard_triggered", false)), "Capped transition geometry must expose guard diagnostics.")
	var invalid_layout := PlatformRendererType.calculate_transition_slot_layout(INF, 8.0, 12.0)
	_assert_equal(0, int(invalid_layout.get("count", -1)), "Non-finite geometry must allocate no transition tiles.")
	_assert_true(bool(invalid_layout.get("guard_triggered", false)), "Rejected non-finite geometry must remain diagnosable.")
	renderer.clear()


func _test_renderer_runtime_model() -> void:
	var board := Node2D.new()
	board.name = "VariableSizeBoard"
	add_child(board)
	_created_nodes.append(board)
	var first := DummyCell.new()
	first.configure(Vector2(512.0, 512.0), Vector2.ZERO)
	board.add_child(first)
	var second := DummyCell.new()
	second.configure(Vector2(256.0, 512.0), Vector2(512.0, 0.0))
	board.add_child(second)
	var inactive := DummyCell.new()
	inactive.board_enabled = false
	inactive.configure(Vector2(768.0, 256.0), Vector2(0.0, 512.0))
	board.add_child(inactive)
	var view := DummyView.new()
	view.name = "DummyHybridView"
	add_child(view)
	_created_nodes.append(view)
	await get_tree().process_frame
	var renderer := PlatformRendererType.new()
	renderer.setup(view)
	renderer.rebuild([first, second, inactive])
	var model := renderer.get_last_model()
	_assert_near(2560.0, float(model.get("perimeter", 0.0)), 0.01, "Runtime renderer must derive its outline from actual sprite sizes.")
	_assert_true(int(model.get("low_profile_rail_segment_count", 0)) > 0, "Runtime renderer must create the continuous low-profile rail.")
	_assert_true(int(model.get("transition_tile_count", 0)) > 0, "Runtime renderer must create the compact transition band.")
	_assert_true(int(model.get("front_skirt_module_count", 0)) > 0, "Runtime renderer must preserve the original lower skirt.")
	_assert_true(not bool(model.get("transition_guard_triggered", true)), "Normal mixed-size geometry must remain below transition safety limits.")
	var outward_ratios := model.get("transition_outward_ratios", PackedFloat32Array()) as PackedFloat32Array
	var tile_sizes := model.get("transition_tile_sizes", PackedFloat32Array()) as PackedFloat32Array
	_assert_true(not outward_ratios.is_empty(), "Runtime transition diagnostics must retain continuous outward positions.")
	_assert_equal(int(model.get("transition_tile_count", 0)), outward_ratios.size(), "Every transition tile must record its outward fade ratio.")
	_assert_equal(outward_ratios.size(), tile_sizes.size(), "Every transition tile must record its irregular size.")
	var rail_edges := model.get("low_profile_rail_edges", PackedStringArray()) as PackedStringArray
	var transition_edges := model.get("transition_band_edges", PackedStringArray()) as PackedStringArray
	_assert_true(not rail_edges.has("bottom"), "The new low-profile rail must never cover the original lower boundary.")
	_assert_true(not transition_edges.has("bottom"), "The new transition band must never render below the board.")
	for required_name in [
		"BoardSupportContactRim",
		"BoardSupportFrontSkirt",
		"BoardSupportLowProfileRail",
		"BoardSupportTransitionBand",
	]:
		var visual := view._ground_root.get_node_or_null(required_name) as GeometryInstance3D
		_assert_true(visual != null, "Runtime support must create %s." % required_name)
		if visual != null:
			_assert_true(bool(visual.get_meta(&"hybrid_board_visual", false)), "%s must follow board visibility and recentering." % required_name)
			_assert_true(bool(visual.get_meta(&"board_support_visual", false)), "%s must be identifiable as support geometry." % required_name)
	var rail := view._ground_root.get_node_or_null("BoardSupportLowProfileRail") as MeshInstance3D
	if rail != null and rail.mesh != null:
		var bounds := rail.mesh.get_aabb()
		_assert_near(PlatformRendererType.LOW_PROFILE_RAIL_TOP_Y, bounds.end.y, 0.001, "Rail top must retain its specified profile.")
		_assert_near(PlatformRendererType.LOW_PROFILE_RAIL_BOTTOM_Y, bounds.position.y, 0.001, "Rail bottom must retain its specified shallow depth.")
		var material := rail.mesh.surface_get_material(0) as StandardMaterial3D
		_assert_true(material != null and material.albedo_texture == null, "Neutral rail must use a texture-free material independent of cell colors.")
		if material != null:
			_assert_true(_max_channel_delta(material.albedo_color) <= 0.03, "Runtime rail material must remain hue-neutral.")
		var board_bottom_world := 512.0 * view.world_scale
		_assert_true(
			bounds.end.z <= board_bottom_world + PlatformRendererType.EDGE_OVERLAP_WORLD + 0.001,
			"Side rails may meet the lower corners but must not extend across the lower boundary."
		)
	var band := view._ground_root.get_node_or_null("BoardSupportTransitionBand") as MeshInstance3D
	if band != null and band.mesh != null:
		var arrays := band.mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		_assert_true(not vertices.is_empty(), "Transition band must contain deterministic pixel tiles.")
		_assert_equal(vertices.size(), colors.size(), "Every transition vertex must carry an explicit neutral or restrained accent color.")
		var material := band.mesh.surface_get_material(0) as StandardMaterial3D
		_assert_true(material != null and material.vertex_color_use_as_albedo, "Transition band must render its compact per-tile fade colors.")
		var band_bounds := band.mesh.get_aabb()
		_assert_true(
			band_bounds.end.z <= 512.0 * view.world_scale + 0.001,
			"Transition pixels must stop at the lower corners instead of covering the lower boundary."
		)
	var skirt := view._ground_root.get_node_or_null("BoardSupportFrontSkirt") as MeshInstance3D
	if skirt != null and skirt.mesh != null:
		var skirt_material := skirt.mesh.surface_get_material(0) as ShaderMaterial
		_assert_true(skirt_material != null and skirt_material.get_shader_parameter("skirt_texture") is Texture2D, "The preserved lower skirt must keep its authored pixel atlas.")
		if skirt_material != null:
			_assert_near(
				PlatformRendererType.SKIRT_TOP_HIGHLIGHT_DIM,
				float(skirt_material.get_shader_parameter("top_highlight_dim")),
				0.001,
				"The skirt shader must apply the reviewed 15% highlight reduction."
			)
			_assert_true(skirt_material.shader.code.contains("filter_nearest"), "The skirt shader must retain nearest-neighbor atlas filtering.")
		var skirt_bounds := skirt.mesh.get_aabb()
		_assert_near(PlatformRendererType.SKIRT_TOP_Y, skirt_bounds.end.y, 0.001, "The original lower skirt must still meet the board top.")
		_assert_near(PlatformRendererType.SKIRT_BOTTOM_Y, skirt_bounds.position.y, 0.001, "The original lower skirt depth must remain unchanged.")
		var skirt_arrays := skirt.mesh.surface_get_arrays(0)
		var skirt_vertices := skirt_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		_assert_true(
			_has_corner_ramp_span(skirt_vertices, view.world_scale),
			"The lower skirt end caps must ramp from rail depth to full skirt depth over the reviewed corner span."
		)
	var active_rects := renderer.collect_active_cell_rects([first, second])
	for footprint_variant in model.get("transition_footprints", []):
		var footprint := footprint_variant as Rect2
		for active_rect in active_rects:
			_assert_true(
				not footprint.grow(-0.05).intersects(active_rect.grow(-0.05), false),
				"Transition tiles must remain outside active board geometry."
			)
	for retired_name in ["BoardSupportFragmentBelt"]:
		_assert_true(view._ground_root.get_node_or_null(retired_name) == null, "Version 2 must not recreate retired support visual: %s" % retired_name)
	renderer.clear()


func _has_corner_ramp_span(vertices: PackedVector3Array, world_scale: float) -> bool:
	var shallow_x := INF
	for vertex in vertices:
		if absf(vertex.y - PlatformRendererType.LOW_PROFILE_RAIL_BOTTOM_Y) <= 0.001:
			shallow_x = minf(shallow_x, vertex.x)
	if not is_finite(shallow_x):
		return false
	var expected_span := PlatformRendererType.CORNER_TRANSITION_LENGTH_2D * world_scale
	for vertex in vertices:
		if absf(vertex.y - PlatformRendererType.SKIRT_BOTTOM_Y) > 0.001:
			continue
		if absf(absf(vertex.x - shallow_x) - expected_span) <= 0.02:
			return true
	return false


func _max_channel_delta(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))


func _assert_closed_outline(segments: Array, context: String) -> void:
	var endpoint_counts: Dictionary = {}
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		for point in [segment.get("start", Vector2.ZERO), segment.get("end", Vector2.ZERO)]:
			var value := point as Vector2
			var key := "%.3f:%.3f" % [value.x, value.y]
			endpoint_counts[key] = int(endpoint_counts.get(key, 0)) + 1
	for key in endpoint_counts:
		_assert_equal(2, int(endpoint_counts[key]), "%s outline endpoint must join exactly two edges without a crack: %s" % [context, key])


func _assert_near(expected: float, actual: float, tolerance: float, message: String) -> void:
	_assert_true(absf(expected - actual) <= tolerance, "%s Expected=%.4f Actual=%.4f" % [message, expected, actual])


func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
