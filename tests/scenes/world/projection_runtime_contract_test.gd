extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const AFFILIATION_MARKER := preload("res://Combat/visual/affiliation_marker.gd")
const PLAYER_AMMO_HUD := preload("res://Player/Mechas/scripts/player_ammo_hud.gd")
const ELITE_ROLLING_BALL := preload("res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const WEAPON_SCENE := preload("res://Player/Weapons/weapon_ranger.tscn")
const FRIENDLY_SCENE := preload("res://Npc/friendly/scenes/friendly_npc.tscn")
const UNIT_BILLBOARD_SOURCE := preload("res://Visual/Oblique/unit_billboard_visual_2d.gd")
const UNIT_BILLBOARD_SHADER := preload("res://Shaders/unit_billboard_3d.gdshader")
const BEACON_PROJECTED_VISUAL := preload("res://World/battle_contract/beacon_projected_visual.gd")
const OFFSCREEN_GEOMETRY := preload("res://Visual/Oblique/offscreen_indicator_geometry.gd")
const BEACON_PLAYER_FOREGROUND := preload("res://World/battle_contract/beacon_player_foreground.gd")
const TACTICAL_BEACON_SCENE := preload("res://World/battle_contract/tactical_beacon.tscn")
const REST_ZONE_SHADER := preload("res://Shaders/rest_area_zone_ground.gdshader")
const CELL_ACTIVATION_VISUAL := preload("res://Board/Cells/cell_activation_visual.gd")

class DummyBoard:
	extends Node2D
	var cells: Array = []

class DummyRestArea:
	extends Node2D
	var selected_zone_id := 4
	var hover_zone_id := -1

	func _get_zone_rect_local(_zone_id: int) -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(160.0, 160.0))

class DummyAuraSource:
	extends Node2D

	func get_hybrid_aura_visual() -> Dictionary:
		return {
			"visible": true,
			"radius": 120.0,
			"line_width": 4.0,
			"line_color": Color.RED,
			"fill_color": Color(1.0, 0.0, 0.0, 0.1),
		}

var _failed := false


func _ready() -> void:
	var board := DummyBoard.new()
	board.name = "Board"
	add_child(board)

	var view := HYBRID_VIEW.new()
	view.board_path = NodePath("../Board")
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_activation_outline_stays_below_units(view)
	_expect_rest_zone_sync_without_retired_hold_state(view)
	_expect_aura_registration_initializes_transform(view)
	_expect_player_ammo_arc_contract()

	var points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(120.0, -90.0),
		Vector2(-240.0, 310.0),
	]
	for point in points:
		var projected := view.project_world_to_screen(point)
		var round_trip := view.screen_to_world_2d(projected)
		_expect(
			round_trip.distance_to(point) < 0.25,
			"projection round trip failed for %s: %s" % [point, round_trip]
		)

	var screen_right := view.world_vector_to_screen(Vector2.RIGHT, Vector2.ZERO)
	_expect(screen_right.length_squared() > 0.01, "world direction must produce a screen direction")

	var marker_owner := Node2D.new()
	marker_owner.position = Vector2(180.0, 120.0)
	add_child(marker_owner)
	var marker := AFFILIATION_MARKER.new()
	marker.position = Vector2(0.0, 8.0)
	marker_owner.add_child(marker)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_marker_matches_ground(marker, marker_owner, view)
	marker_owner.position += Vector2(-320.0, 90.0)
	await get_tree().process_frame
	_expect_marker_matches_ground(marker, marker_owner, view)

	view.configure(56.0, -4.0, 20.0)
	await get_tree().process_frame
	_expect(view.can_project_world_point(Vector2.ZERO), "camera must remain projectable after reconfigure")
	_expect_marker_matches_ground(marker, marker_owner, view)

	var marker_id := marker.get_instance_id()
	marker_owner.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var ground_markers := view.get("_affiliation_marker_meshes") as Dictionary
	_expect(not ground_markers.has(marker_id), "freed affiliation marker must leave ground registry")

	var elite := ELITE_ROLLING_BALL.instantiate() as BaseEnemy
	elite.process_mode = Node.PROCESS_MODE_DISABLED
	elite.position = Vector2(90.0, -40.0)
	add_child(elite)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_elite_ground_visual_sizes(elite, view)
	var elite_body := elite.get_node("Body") as Node2D
	_expect_unit_billboard_anchor(elite, elite_body, view, "elite enemy")
	await _expect_fixed_pixel_billboard_at_camera_angles(elite, elite_body, view)
	elite.damage_feedback.play_hit_flash()
	await get_tree().process_frame
	_expect_billboard_feedback(elite_body, view)
	var elite_body_id := elite_body.get_instance_id()
	elite.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_unit_billboard_removed(elite_body_id, view, "elite enemy")

	for unit_case in [
		{"scene": PLAYER_SCENE, "label": "player"},
		{"scene": FRIENDLY_SCENE, "label": "friendly NPC"},
	]:
		var unit := (unit_case.scene as PackedScene).instantiate() as Node2D
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(unit)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_unit_marker_matches_shadow(unit, view, str(unit_case.label))
		var body_sources: Array[Node2D] = []
		if str(unit_case.label) == "player":
			var ammo_layer := unit.get_node_or_null("PlayerHudLayer") as CanvasLayer
			var ammo_hud := unit.get_node_or_null("PlayerHudLayer/AmmoHud") as Control
			_expect(ammo_layer != null and ammo_layer.layer == 0, "player ammo HUD must share the world canvas layer and remain below UI")
			_expect(ammo_hud != null and ammo_hud.get_script() == PLAYER_AMMO_HUD, "player must expose a dedicated screen-space ammo HUD")
			var marker_config := unit.get_node("AffiliationMarker").call("get_hybrid_ground_marker_config") as Dictionary
			_expect(not marker_config.has("ammo_ratio"), "ground affiliation marker must not own ammo HUD state")
			body_sources.assign([
				unit.get_node("MechaSprite") as Node2D,
				unit.get_node("MechaMoveSprite") as Node2D,
			])
		else:
			body_sources.assign([unit.get_node("Body") as Node2D])
		for source in body_sources:
			_expect_unit_billboard_anchor(unit, source, view, "%s %s" % [unit_case.label, source.name])
		if str(unit_case.label) == "player":
			await _expect_player_compatibility_switch(body_sources[0], body_sources[1], view)
			_expect_beacon_visual_respects_player(unit, view)
		var source_ids: Array[int] = []
		for source in body_sources:
			source_ids.append(source.get_instance_id())
		unit.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		for source_id in source_ids:
			_expect_unit_billboard_removed(source_id, view, str(unit_case.label))

	await _expect_weapon_uses_depth_tested_billboard(view)

	await _expect_dense_billboard_pooling(view)
	await get_tree().process_frame

	print("FAIL hybrid projection runtime contract" if _failed else "PASS hybrid projection runtime contract")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _expect_activation_outline_stays_below_units(view: Node) -> void:
	var cell := Node2D.new()
	cell.name = "ActivationLayerCell"
	add_child(cell)
	var activation := CELL_ACTIVATION_VISUAL.new()
	activation.name = "ActivationVisual"
	cell.add_child(activation)
	view.call("_create_activation_mesh", cell, Vector2(256.0, 256.0), Vector2(512.0, 512.0))
	var material := view.get("_activation_material") as ShaderMaterial
	_expect(material != null, "cell activation outline must create its ground material")
	_expect(
		material != null and material.render_priority == 1,
		"cell activation outline must render above terrain and before unit billboards"
	)
	var entries := view.get("_activation_meshes") as Dictionary
	var entry := entries.get(cell.get_instance_id(), {}) as Dictionary
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(mesh != null and mesh.mesh is QuadMesh, "cell activation outline must use one complete quad for all four edges")
	_expect(
		mesh != null and is_equal_approx(mesh.position.y, 0.024),
		"cell activation outline must sit above the 0.012 structural-border top surface"
	)
	if mesh != null:
		mesh.queue_free()
	entries.erase(cell.get_instance_id())
	cell.queue_free()


func _expect_rest_zone_sync_without_retired_hold_state(view: Node) -> void:
	var rest_area := DummyRestArea.new()
	add_child(rest_area)
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = REST_ZONE_SHADER
	quad.material = material
	mesh.mesh = quad
	var ground_root := view.get("_ground_root") as Node3D
	ground_root.add_child(mesh)
	view.set("_rest_area", rest_area)
	var rest_zone_meshes := view.get("_rest_zone_meshes") as Dictionary
	rest_zone_meshes.clear()
	rest_zone_meshes[4] = {"mesh": mesh}
	view.call("_sync_rest_zone_meshes")
	_expect(mesh.visible, "rest-zone sync must work without retired hold-state properties")
	rest_zone_meshes.clear()
	view.set("_rest_area", null)
	ground_root.remove_child(mesh)
	mesh.free()
	remove_child(rest_area)
	rest_area.free()


func _expect_aura_registration_initializes_transform(view: Node) -> void:
	var source := DummyAuraSource.new()
	source.position = Vector2(275.0, -135.0)
	add_child(source)
	view.call("_register_enemy_support_visual", source)
	var entries := view.get("_enemy_aura_meshes") as Dictionary
	var entry := entries.get(source.get_instance_id(), {}) as Dictionary
	var outline := entry.get("outline") as MeshInstance3D
	var fill := entry.get("fill") as MeshInstance3D
	var expected_ground := view.call("world_2d_to_3d", source.global_position) as Vector3
	_expect(
		outline != null and outline.position.distance_to(expected_ground + Vector3.UP * 0.020) < 0.001,
		"new enemy aura outline must be positioned before its first rendered frame",
	)
	_expect(
		fill != null and fill.position.distance_to(expected_ground + Vector3.UP * 0.021) < 0.001,
		"new enemy aura fill must be positioned before its first rendered frame",
	)
	_expect(outline != null and outline.visible, "new visible enemy aura must be initialized immediately")
	source.queue_free()


func _expect_beacon_visual_respects_player(player: Node2D, view: Node) -> void:
	var beacon := TACTICAL_BEACON_SCENE.instantiate() as Area2D
	var beacon_shape := (beacon.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var ground_visual := beacon.get_node("OuterGround")
	_expect(beacon_shape != null and beacon_shape.size == Vector2(140.0, 140.0), "beacon presence detection must use the 140x140 square protocol footprint")
	_expect(int(ground_visual.get("visual_shape")) == 1 and ground_visual.get("rectangle_size") == beacon_shape.size, "beacon ground rendering must match its square collision footprint")
	beacon.free()
	var visual := BEACON_PROJECTED_VISUAL.new() as Control
	add_child(visual)
	var protocol_texture := load("res://asset/images/effects/protocol/protocol_square_topdown.png") as Texture2D
	_expect(protocol_texture != null, "beacon projected visual must load the top-down square protocol texture")
	_expect(protocol_texture != null and protocol_texture.get_size() == Vector2(128.0, 128.0), "top-down protocol texture must retain the effect_large 128x128 grid")
	var projection_target := Node2D.new()
	projection_target.position = Vector2(180.0, -90.0)
	projection_target.rotation = 0.17
	add_child(projection_target)
	visual.configure(projection_target, &"operation", 1, Vector2(140.0, 140.0))
	var marker_safe_rect := Rect2(Vector2(54.0, 54.0), Vector2(1172.0, 612.0))
	_expect(OFFSCREEN_GEOMETRY.make_safe_rect(Vector2(1280.0, 720.0)) == marker_safe_rect, "offscreen target types must share the protocol marker safe area")
	var right_state := OFFSCREEN_GEOMETRY.resolve(Vector2(1400.0, 360.0), Vector2(1280.0, 720.0), marker_safe_rect)
	_expect(not bool(right_state.get("is_inside_viewport", true)), "an enemy beyond the viewport must resolve as offscreen")
	_expect((right_state.get("edge_position") as Vector2).is_equal_approx(Vector2(1226.0, 360.0)), "offscreen guidance must clamp to the right protocol-safe edge")
	var inside_state := OFFSCREEN_GEOMETRY.resolve(Vector2(1200.0, 360.0), Vector2(1280.0, 720.0), marker_safe_rect)
	_expect(bool(inside_state.get("is_inside_viewport", false)), "a visible enemy must not be treated as offscreen even outside the inset arrow area")
	var marker_activation_rect := visual.call("_world_marker_activation_rect", marker_safe_rect) as Rect2
	_expect(marker_activation_rect == marker_safe_rect.grow(48.0), "protocol detail activation must extend 48px beyond the offscreen-arrow safe area")
	_expect(marker_activation_rect.has_point(Vector2(20.0, marker_safe_rect.get_center().y)), "protocol detail must render while its center is near the screen edge")
	_expect(not marker_activation_rect.has_point(Vector2(-1.0, marker_safe_rect.get_center().y)), "protocol detail must still yield to the offscreen arrow once its center leaves the viewport")
	var projected_footprint := visual.call("_projected_footprint_points") as PackedVector2Array
	var half := Vector2(70.0, 70.0)
	var local_corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	_expect(projected_footprint.size() == 4, "protocol texture and progress must use four projected world corners")
	for index in range(local_corners.size()):
		var expected_corner := view.call("project_world_to_screen", projection_target.global_transform * local_corners[index]) as Vector2
		_expect(projected_footprint[index].distance_to(expected_corner) < 0.001, "protocol footprint corner %d must use the camera's direct world projection" % index)
	var progress_perimeter := visual.call("_closed_footprint", projected_footprint) as PackedVector2Array
	_expect(progress_perimeter.size() == 5 and progress_perimeter[4] == projected_footprint[0], "protocol progress must close the same four projected corners without a hand-authored trapezoid")
	for index in range(projected_footprint.size()):
		_expect(progress_perimeter[index] == projected_footprint[index], "protocol progress corner %d must match the texture footprint exactly" % index)
	var occlusion_rect := visual.call("_player_occlusion_rect") as Rect2
	var idle_source := player.get_node("MechaSprite") as Node2D
	var config := idle_source.call("get_unit_billboard_config") as Dictionary
	var local_ground_anchor := config.get("local_ground_anchor", Vector2.ZERO) as Vector2
	var player_anchor := view.call("project_world_to_screen", player.global_transform * local_ground_anchor) as Vector2
	_expect(occlusion_rect.size.x > 0.0 and occlusion_rect.size.y > 0.0, "beacon visual must reserve the active player billboard bounds")
	_expect(occlusion_rect.has_point(player_anchor - Vector2(0.0, 4.0)), "beacon occlusion must cover the player from body to ground anchor")
	var center := occlusion_rect.get_center()
	var crossing_line := PackedVector2Array([
		Vector2(occlusion_rect.position.x - 30.0, center.y),
		Vector2(occlusion_rect.position.x - 10.0, center.y),
		center,
		Vector2(occlusion_rect.end.x + 10.0, center.y),
		Vector2(occlusion_rect.end.x + 30.0, center.y),
	])
	var visible_runs := visual.call("_split_polyline_around_rect", crossing_line, occlusion_rect) as Array
	_expect(visible_runs.size() == 1, "beacon progress line must remain one continuous run across the player")
	_expect(
		visible_runs.size() == 1 and (visible_runs[0] as PackedVector2Array) == crossing_line,
		"beacon progress line must not hide or trim points inside the player bounds",
	)
	var foreground := BEACON_PLAYER_FOREGROUND.new() as Control
	add_child(foreground)
	var foreground_state := foreground.call("get_player_draw_state") as Dictionary
	var foreground_rect := foreground_state.get("rect", Rect2()) as Rect2
	_expect(not foreground_state.is_empty(), "beacon layer must provide a player foreground draw state")
	_expect(foreground_state.get("texture") == config.get("texture"), "beacon player foreground must reuse the active billboard frame")
	_expect(
		foreground_rect.has_point(player_anchor - Vector2(0.0, 4.0)),
		"beacon player foreground must cover the same projected player anchor as the protocol visual",
	)
	var foreground_points := foreground_state.get("points", PackedVector2Array()) as PackedVector2Array
	_expect(foreground_points.size() == 4, "beacon player foreground must draw one complete textured quad")
	foreground.queue_free()
	visual.queue_free()
	projection_target.queue_free()


func _expect_player_ammo_arc_contract() -> void:
	var hud := PLAYER_AMMO_HUD.new() as Control
	hud.call("set_ammo_status", 7, 10, true)
	_expect(hud.visible, "player ammo HUD must be visible for ammo-based weapons")
	_expect(is_equal_approx(float(hud.call("get_ammo_ratio")), 0.7), "player ammo HUD must expose the current magazine ratio")
	_expect(hud.get("hud_size") == Vector2(128.0, 64.0), "player ammo HUD must retain a fixed screen-space drawing surface")
	_expect(int(hud.get("segment_count")) == 4, "quarter-ring ammo HUD must keep four readable segments")
	_expect(is_equal_approx(float(hud.get("ring_radius_scale")), 1.30), "quarter-ring ammo HUD must preserve a visible gap outside the affiliation ring")
	_expect(bool(hud.call("has_container_texture")), "player ammo HUD must use its generated raster container asset")
	var sample_track := PackedVector2Array([Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)])
	var half_fill := hud.call("_build_fill_points", sample_track, 0.5) as PackedVector2Array
	_expect(half_fill.size() == 2 and half_fill[0] == sample_track[1] and half_fill[-1] == sample_track[-1], "ammo fill must remain anchored at the left 90-degree end while draining from the right")
	var ribbon := hud.call("_build_ribbon_polygon", sample_track, 4.0) as PackedVector2Array
	_expect(ribbon.size() == 6 and is_equal_approx(ribbon[0].y, ribbon[-1].y), "right 0-degree endpoint must use an upward-facing horizontal square cut")
	var collapsed_ribbon := hud.call(
		"_build_ribbon_polygon",
		PackedVector2Array([Vector2(10.0, 10.0), Vector2(10.0, 10.0)]),
		4.0,
	) as PackedVector2Array
	_expect(
		not bool(hud.call("_is_drawable_polygon", collapsed_ribbon)),
		"collapsed projected ammo paths must be rejected before renderer triangulation",
	)
	hud.call("set_ammo_status", 0, 10, true)
	_expect(hud.visible, "empty magazines must preserve the visible ammo track")
	_expect(is_zero_approx(float(hud.call("get_ammo_ratio"))), "empty magazines must expose zero fill")
	hud.call("set_ammo_status", 5, 10, false)
	_expect(not hud.visible, "non-ammo weapons must hide the ammo HUD")
	hud.free()


func _expect_marker_matches_ground(marker: Node2D, owner: Node2D, view: Node) -> void:
	var logical_anchor := owner.global_transform * Vector2(0.0, 8.0)
	var expected := view.call("world_2d_to_ground_anchor", logical_anchor) as Vector3
	var ground_markers := view.get("_affiliation_marker_meshes") as Dictionary
	var entry := ground_markers.get(marker.get_instance_id()) as Dictionary
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(not marker.visible, "hybrid enemy affiliation marker must hide its 2D fallback")
	_expect(
		mesh != null and mesh.position.distance_to(expected) < 0.001,
		"affiliation ground marker mismatch: actual=%s expected=%s" % [
			mesh.position if mesh != null else Vector3.ZERO,
			expected,
		]
	)
	_expect(mesh != null and mesh.visible, "affiliation ground marker mesh must be visible")
	_expect(
		mesh != null and is_equal_approx(mesh.scale.x * 0.78, 0.2)
		and is_equal_approx(mesh.scale.z * 0.78, 0.2),
		"affiliation ground marker must preserve its 20px world radius"
	)


func _expect_elite_ground_visual_sizes(elite: BaseEnemy, view: Node) -> void:
	var marker := elite.get_node("AffiliationMarker") as Node2D
	var shadow := elite.get_node("GroundShadow") as Polygon2D
	var marker_config := marker.call("get_hybrid_ground_marker_config") as Dictionary
	var marker_footprint := marker_config.get("footprint_size", Vector2.ZERO) as Vector2
	var marker_entries := view.get("_affiliation_marker_meshes") as Dictionary
	var marker_entry := marker_entries.get(marker.get_instance_id()) as Dictionary
	var marker_mesh := marker_entry.get("mesh") as MeshInstance3D
	_expect(
		marker_mesh != null
		and Vector2(
			marker_mesh.scale.x * 2.0 * 0.78 / 0.01,
			marker_mesh.scale.z * 2.0 * 0.78 / 0.01
		).is_equal_approx(marker_footprint),
		"elite ground marker mesh must apply the shadow footprint"
	)
	var shadow_entries := view.get("_shadow_meshes") as Dictionary
	var shadow_entry := shadow_entries.get(shadow.get_instance_id()) as Dictionary
	var shadow_size := shadow_entry.get("size_2d", Vector2.ZERO) as Vector2
	_expect(
		shadow_size.is_equal_approx(Vector2(22.0, 9.0)),
		"elite shadow must derive from its 20x20 HurtBox: actual=%s" % shadow_size
	)
	_expect(
		marker_footprint.is_equal_approx(shadow_size),
		"elite marker contour must exactly match its shadow: marker=%s shadow=%s" % [marker_footprint, shadow_size]
	)


func _expect_unit_marker_matches_shadow(unit: Node2D, view: Node, label: String) -> void:
	var marker := unit.get_node("AffiliationMarker") as Node2D
	var shadow := unit.get_node("GroundShadow") as CanvasItem
	var marker_config := marker.call("get_hybrid_ground_marker_config") as Dictionary
	var marker_size := marker_config.get("footprint_size", Vector2.ZERO) as Vector2
	var expected_line_width := 1.25 if label == "player" else 1.0
	_expect(
		is_equal_approx(float(marker_config.get("line_width", 0.0)), expected_line_width),
		"%s marker must use the narrowed %spx stroke" % [label, expected_line_width]
	)
	var shadow_entries := view.get("_shadow_meshes") as Dictionary
	var shadow_entry := shadow_entries.get(shadow.get_instance_id()) as Dictionary
	var shadow_size := shadow_entry.get("size_2d", Vector2.ZERO) as Vector2
	_expect(
		marker_size.is_equal_approx(shadow_size),
		"%s marker contour must exactly match its shadow: marker=%s shadow=%s" % [label, marker_size, shadow_size]
	)
	var marker_entries := view.get("_affiliation_marker_meshes") as Dictionary
	var marker_entry := marker_entries.get(marker.get_instance_id()) as Dictionary
	var marker_mesh := marker_entry.get("mesh") as MeshInstance3D
	_expect(marker_mesh != null and marker_mesh.visible, "%s marker must render on the hybrid ground plane" % label)
	if marker_mesh != null:
		var rendered_size := Vector2(
			marker_mesh.scale.x * 2.0 * 0.78 / 0.01,
			marker_mesh.scale.z * 2.0 * 0.78 / 0.01
		)
		_expect(
			rendered_size.is_equal_approx(shadow_size),
			"%s rendered marker must preserve shadow width and depth: marker=%s shadow=%s" % [label, rendered_size, shadow_size]
		)


func _unit_billboard_entry(source: Node2D, view: Node) -> Dictionary:
	var renderer := view.get("_unit_billboard_renderer") as RefCounted
	if renderer == null:
		return {}
	var entries := renderer.call("get_debug_entries") as Dictionary
	return entries.get(source.get_instance_id(), {}) as Dictionary


func _expect_unit_billboard_anchor(unit: Node2D, source: Node2D, view: Node, label: String) -> void:
	_expect(source.has_method("get_unit_billboard_config"), "%s must expose billboard config" % label)
	var entry := _unit_billboard_entry(source, view)
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(mesh != null, "%s must register a 3D billboard mesh" % label)
	_expect(source.visibility_layer == 0, "%s 2D compatibility source must leave Canvas visibility" % label)
	if mesh == null:
		return
	var shadow := unit.get_node("GroundShadow") as Node2D
	var logical_anchor := unit.global_transform * shadow.position
	var ground_expected := view.call("world_2d_to_ground_anchor", logical_anchor) as Vector3
	var renderer := view.get("_unit_billboard_renderer") as RefCounted
	var expected := renderer.call("terrain_safe_anchor", ground_expected) as Vector3
	_expect(
		mesh.position.distance_to(expected) < 0.001,
		"%s billboard must use the terrain-safe unit anchor: actual=%s expected=%s" % [label, mesh.position, expected]
	)
	var shadow_entries := view.get("_shadow_meshes") as Dictionary
	var shadow_entry := shadow_entries.get(shadow.get_instance_id(), {}) as Dictionary
	var shadow_mesh := shadow_entry.get("mesh") as MeshInstance3D
	_expect(
		shadow_mesh != null and shadow_mesh.position.distance_to(ground_expected) < 0.001,
		"%s shadow center must share GroundAnchor" % label
	)
	var marker := unit.get_node("AffiliationMarker") as Node2D
	var marker_entries := view.get("_affiliation_marker_meshes") as Dictionary
	var marker_entry := marker_entries.get(marker.get_instance_id(), {}) as Dictionary
	var marker_mesh := marker_entry.get("mesh") as MeshInstance3D
	_expect(
		marker_mesh != null and marker_mesh.position.distance_to(ground_expected) < 0.001,
		"%s ground-ring center must share GroundAnchor" % label
	)
	var config := source.call("get_unit_billboard_config") as Dictionary
	var same_config := source.call("get_unit_billboard_config") as Dictionary
	_expect(is_same(config, same_config), "%s billboard config must be persistent instead of allocated every frame" % label)
	_expect(int(config.get("appearance_version", 0)) == int(same_config.get("appearance_version", -1)), "%s unchanged billboard config must keep a stable version" % label)
	if config.get("texture") != null and bool(config.get("visible", true)):
		_expect(mesh.visible, "%s visible source must render through the 3D billboard" % label)
		var material := mesh.material_override as ShaderMaterial
		_expect(
			material != null and material.shader == UNIT_BILLBOARD_SHADER,
			"%s must use the depth-tested full-facing billboard shader" % label
		)


func _expect_fixed_pixel_billboard_at_camera_angles(unit: Node2D, source: Node2D, view: Node) -> void:
	var camera_configs: Array[Vector3] = [
		Vector3(25.0, -20.0, 8.0),
		Vector3(52.0, 0.0, 20.0),
		Vector3(75.0, 20.0, 35.0),
	]
	for config in camera_configs:
		view.call("configure", config.x, config.y, config.z)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_unit_billboard_anchor(unit, source, view, "elite at camera %s" % config)
		var billboard_entry := _unit_billboard_entry(source, view)
		var mesh := billboard_entry.get("mesh") as MeshInstance3D
		if mesh == null:
			continue
		var source_config := source.call("get_unit_billboard_config") as Dictionary
		var expected_px := source_config.get("visual_size_px", Vector2.ZERO) as Vector2
		var size_world := mesh.get_instance_shader_parameter("billboard_size_world") as Vector2
		var camera := view.get_node("GroundCamera3D") as Camera3D
		var depth := absf((camera.global_transform.affine_inverse() * mesh.position).z)
		var viewport_height := maxf(view.get_viewport().get_visible_rect().size.y, 1.0)
		var units_per_pixel := 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / viewport_height
		var rendered_px := size_world / maxf(units_per_pixel, 0.000001)
		_expect(
			rendered_px.distance_to(expected_px) < 0.05,
			"billboard must preserve fixed pixel size at camera %s: actual=%s expected=%s" % [config, rendered_px, expected_px]
		)
		var bottom_screen := camera.unproject_position(mesh.position)
		var top_screen := camera.unproject_position(
			mesh.position + camera.global_transform.basis.y.normalized() * size_world.y
		)
		_expect(
			absf(bottom_screen.distance_to(top_screen) - expected_px.y) < 0.1,
			"billboard must fully face camera and preserve screen height at camera %s" % config
		)


func _expect_billboard_feedback(source: Node2D, view: Node) -> void:
	var entry := _unit_billboard_entry(source, view)
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(
		mesh != null and float(mesh.get_instance_shader_parameter("flash_amount")) > 0.0,
		"hit feedback must migrate from the compatibility overlay into the 3D billboard"
	)
	var config := source.call("get_unit_billboard_config") as Dictionary
	_expect(
		float(config.get("outline_width_px", 0.0)) > 0.0,
		"elite outline must migrate into the 3D billboard shader"
	)


func _expect_player_compatibility_switch(idle: Node2D, moving: Node2D, view: Node) -> void:
	var idle_mesh := _unit_billboard_entry(idle, view).get("mesh") as MeshInstance3D
	var moving_mesh := _unit_billboard_entry(moving, view).get("mesh") as MeshInstance3D
	_expect(idle_mesh != null and idle_mesh.visible, "player idle visual must initially render in 3D")
	_expect(moving_mesh != null and not moving_mesh.visible, "player move visual must initially remain hidden")
	idle.visible = false
	moving.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(idle_mesh != null and not idle_mesh.visible, "player idle visibility changes must reach 3D")
	_expect(moving_mesh != null and moving_mesh.visible, "player move visibility changes must reach 3D")
	idle.visible = true
	moving.visible = false


func _expect_unit_billboard_removed(source_id: int, view: Node, label: String) -> void:
	var renderer := view.get("_unit_billboard_renderer") as RefCounted
	var entries := renderer.call("get_debug_entries") as Dictionary
	_expect(not entries.has(source_id), "%s freed source must leave the billboard registry" % label)


func _expect_weapon_uses_depth_tested_billboard(view: Node) -> void:
	var orbit_owner := Node2D.new()
	orbit_owner.position = Vector2(25.0, 15.0)
	add_child(orbit_owner)
	var shadow := Node2D.new()
	shadow.name = "GroundShadow"
	shadow.position = Vector2(0.0, 8.0)
	orbit_owner.add_child(shadow)
	var orbit_holder := Node2D.new()
	orbit_owner.add_child(orbit_holder)
	var weapon := WEAPON_SCENE.instantiate() as Node2D
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	weapon.position = Vector2(40.0, -30.0)
	weapon.rotation = 0.4
	orbit_holder.add_child(weapon)
	await get_tree().process_frame
	await get_tree().process_frame
	var sprite := weapon.get_node("Sprite") as Node2D
	var entry := _unit_billboard_entry(sprite, view)
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(mesh != null, "equipped weapon sprite must register in the depth-tested 3D billboard renderer")
	_expect(sprite.visibility_layer == 0, "equipped weapon 2D sprite must hide after 3D registration")
	_expect(is_equal_approx(float(sprite.get("directional_forward_degrees")), -90.0), "weapon billboard must declare the texture muzzle axis as local -Y")
	if mesh != null:
		var fire_direction := Vector2.RIGHT.rotated(weapon.global_rotation - PI * 0.5)
		var projected_fire_direction := view.call("world_vector_to_screen", fire_direction, weapon.global_position) as Vector2
		var rendered_rotation := float(mesh.get_instance_shader_parameter("visual_rotation_radians"))
		var texture_forward_angle := deg_to_rad(float(sprite.get("directional_forward_degrees")))
		var texture_muzzle_axis_3d := Vector2.RIGHT.rotated(-texture_forward_angle)
		var rendered_muzzle_axis_3d := texture_muzzle_axis_3d.rotated(rendered_rotation).normalized()
		var projected_fire_axis_3d := Vector2(projected_fire_direction.x, -projected_fire_direction.y).normalized()
		_expect(
			rendered_muzzle_axis_3d.dot(projected_fire_axis_3d) > 0.999,
			"weapon muzzle axis must match the projected projectile direction: actual=%s expected=%s" % [rendered_muzzle_axis_3d, projected_fire_axis_3d],
		)
		var camera := view.get_node("GroundCamera3D") as Camera3D
		var owner_ground_anchor := view.call("world_2d_to_ground_anchor", orbit_owner.global_transform * shadow.position) as Vector3
		var renderer := view.get("_unit_billboard_renderer") as RefCounted
		var owner_depth_anchor := renderer.call("terrain_safe_anchor", owner_ground_anchor) as Vector3
		var owner_depth := (camera.global_transform.affine_inverse() * owner_depth_anchor).z
		var behind_ground_anchor := view.call("world_2d_to_ground_anchor", orbit_owner.global_transform * Vector2(0.0, 7.5)) as Vector3
		var behind_depth_anchor := renderer.call("terrain_safe_anchor", behind_ground_anchor) as Vector3
		var behind_depth := (camera.global_transform.affine_inverse() * mesh.position).z
		var expected_behind_depth := (camera.global_transform.affine_inverse() * behind_depth_anchor).z
		_expect(absf(behind_depth - expected_behind_depth) < 0.001, "a weapon rendered above the player must use the rear unit depth layer")
		_expect(behind_depth < owner_depth, "a weapon above the player must be farther from the camera and covered by the player")
		_expect(mesh.position.distance_to(behind_ground_anchor) >= 0.49, "rear-orbit weapons must keep terrain-safe view depth clearance")
		weapon.position.x = -40.0
		await get_tree().process_frame
		await get_tree().process_frame
		var opposite_x_depth := (camera.global_transform.affine_inverse() * mesh.position).z
		_expect(absf(opposite_x_depth - behind_depth) < 0.001, "horizontal orbit movement must not change the rear occlusion layer")
		weapon.position = Vector2(40.0, 30.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var front_ground_anchor := view.call("world_2d_to_ground_anchor", orbit_owner.global_transform * Vector2(0.0, 8.5)) as Vector3
		var front_depth_anchor := renderer.call("terrain_safe_anchor", front_ground_anchor) as Vector3
		var front_depth := (camera.global_transform.affine_inverse() * mesh.position).z
		var expected_front_depth := (camera.global_transform.affine_inverse() * front_depth_anchor).z
		_expect(absf(front_depth - expected_front_depth) < 0.001, "a weapon rendered below the player must use the front unit depth layer")
		_expect(front_depth > owner_depth, "a weapon below the player must be closer to the camera and cover the player")
		_expect(is_zero_approx(float(mesh.get_instance_shader_parameter("vertical_anchor_offset"))), "weapon billboard must rotate around its visual center")
		_expect(not is_zero_approx(float(mesh.get_instance_shader_parameter("visual_rotation_radians"))), "directional weapon billboard must preserve projected aiming rotation")
	var source_id := sprite.get_instance_id()
	orbit_owner.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_unit_billboard_removed(source_id, view, "equipped weapon")


func _expect_dense_billboard_pooling(view: Node) -> void:
	var renderer := view.get("_unit_billboard_renderer") as RefCounted
	var texture_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var shared_texture := ImageTexture.create_from_image(texture_image)
	var material_count_before := (renderer.get("_material_cache") as Dictionary).size()
	var stress_root := Node2D.new()
	stress_root.name = "BillboardDensityStress"
	add_child(stress_root)
	var source_ids: Array[int] = []
	for index in 240:
		var owner := Node2D.new()
		owner.position = Vector2(index % 20, index / 20) * 8.0
		stress_root.add_child(owner)
		var shadow := Node2D.new()
		shadow.name = "GroundShadow"
		shadow.position = Vector2(0.0, 2.0)
		owner.add_child(shadow)
		var source := Sprite2D.new()
		source.name = "Body"
		source.texture = shared_texture
		source.set_script(UNIT_BILLBOARD_SOURCE)
		owner.add_child(source)
		source_ids.append(source.get_instance_id())
	await get_tree().process_frame
	await get_tree().process_frame
	var entries := renderer.call("get_debug_entries") as Dictionary
	for source_id in source_ids:
		_expect(entries.has(source_id), "dense unit %s must register" % source_id)
	var material_count_after := (renderer.get("_material_cache") as Dictionary).size()
	_expect(
		material_count_after == material_count_before + 1,
		"240 billboards sharing one texture must share one ShaderMaterial"
	)
	var started_usec := Time.get_ticks_usec()
	renderer.call("sync_late", 0.0)
	var sync_usec := Time.get_ticks_usec() - started_usec
	print("UNIT_BILLBOARD_DENSITY count=240 sync_usec=%d" % sync_usec)
	_expect(sync_usec < 250000, "240-unit billboard sync must remain below the 250ms safety ceiling")
	renderer.set("max_visible_billboards", 32)
	renderer.call("sync_late", 0.0)
	var limited_metrics := renderer.call("get_performance_metrics") as Dictionary
	_expect(int(limited_metrics.get("visible", 0)) <= 32, "billboard renderer must enforce its visible-object budget")
	_expect(int(limited_metrics.get("culled", 0)) > 0, "billboard budget must report culled objects")
	renderer.set("max_visible_billboards", 320)
	stress_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	entries = renderer.call("get_debug_entries") as Dictionary
	for source_id in source_ids:
		_expect(not entries.has(source_id), "dense freed unit %s must unregister" % source_id)
	var available_meshes := renderer.get("_available_meshes") as Array
	_expect(available_meshes.size() >= 240, "dense billboard meshes must return to the recycle pool")
