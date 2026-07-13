extends Node

const ConeSprayScene := preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")

const HybridView := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const HybridCameraDefaultsType := preload("res://Visual/Oblique/hybrid_camera_defaults.gd")
const BaseEnemyScene := preload("res://Npc/enemy/scenes/base_enemy.tscn")
const EliteEnemyScene := preload("res://Npc/enemy/scenes/elite_enemy.tscn")
const ProjectileScene := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const SpearTexture := preload("res://asset/images/weapons/projectiles/spear_projectile.png")
const AreaEffectScene := preload("res://Combat/area_effect/area_effect.tscn")
const HitLabelScene := preload("res://UI/labels/hit_label.tscn")

class DummyCell:
	extends Node2D
	var board_enabled: bool = true

class DummyBoard:
	extends Node2D

	signal active_cells_changed(active_cell_ids: PackedInt32Array)
	signal board_visual_active_changed(active: bool, immediate: bool)
	signal board_recentered(offset: Vector2)

	var _board_active: bool = true
	var cells: Array[Node2D] = []

	func get_cells() -> Array[Node2D]:
		return cells

class DummyRestArea:
	extends Node2D
	var selected_zone_id: int = 4
	var hover_zone_id: int = -1
	var zone4_hold_duration: float = 1.0
	var _zone4_hold_elapsed: float = 0.0

	func _get_zone_rect_local(zone_id: int) -> Rect2:
		var column := zone_id % 3
		var row := zone_id / 3
		return Rect2(Vector2(column, row) * 170.0, Vector2(170.0, 170.0))

func _ready() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = Vector2(320.0, 180.0)
	add_child(player)
	var board := DummyBoard.new()
	board.name = "Board"
	add_child(board)
	var cell := DummyCell.new()
	cell.name = "DummyCell"
	var texture_root := Node2D.new()
	texture_root.name = "Texture"
	cell.add_child(texture_root)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	sprite.texture = texture
	texture_root.add_child(sprite)
	board.add_child(cell)
	board.cells.append(cell)
	var rest_area := DummyRestArea.new()
	rest_area.name = "RestArea"
	rest_area.add_to_group(&"rest_area")
	rest_area.position = Vector2(-180.0, 420.0)
	var rest_texture_root := Node2D.new()
	rest_texture_root.name = "Texture"
	rest_texture_root.position = Vector2(255.0, 255.0)
	rest_area.add_child(rest_texture_root)
	var rest_sprite := Sprite2D.new()
	rest_sprite.name = "Sprite2D"
	rest_sprite.texture = texture
	rest_texture_root.add_child(rest_sprite)
	add_child(rest_area)
	var pending_line := Line2D.new()
	pending_line.points = PackedVector2Array([Vector2.ZERO, Vector2(60.0, 10.0)])
	pending_line.set_meta("hybrid_ground_visible", true)
	add_child(pending_line)
	var failed := false
	HybridGroundRegistration.queue_registration(pending_line, &"register_ground_segment")
	var view := HybridView.new()
	view.board_path = NodePath("../Board")
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	failed = _check((view.get("_segment_meshes") as Dictionary).has(pending_line.get_instance_id()), "visual registered before the View must flush from the pending queue") or failed
	failed = _check(view.get("_mesh_registry") is GroundMeshRegistry, "Hybrid view must delegate registration to GroundMeshRegistry") or failed
	failed = _check(view.get("_board_renderer") is BoardGroundRenderer, "Board and RestArea ground must use BoardGroundRenderer") or failed
	failed = _check(view.get("_connected_renderer") is ConnectedEffectRenderer, "Beam, link and cone visuals must use ConnectedEffectRenderer") or failed
	failed = _check(view.get("_aura_renderer") is AuraRenderer, "Aura and enemy link visuals must use AuraRenderer") or failed
	failed = _check(view.get("_area_renderer") is AreaEffectRenderer, "Area, shadow and telegraph visuals must use AreaEffectRenderer") or failed
	failed = _check(view.process_priority < 0, "Camera3D projection must update before Billboard visuals") or failed
	var late_sync := view.get_node_or_null("LateGroundVisualSync")
	failed = _check(late_sync != null and late_sync.process_priority > 0, "ground attachments must use a separate late sync") or failed
	var shadow_owner := Node2D.new()
	shadow_owner.position = Vector2(90.0, 65.0)
	add_child(shadow_owner)
	var pending_shadow := Polygon2D.new()
	pending_shadow.position = Vector2(0.0, 8.0)
	pending_shadow.polygon = PackedVector2Array([Vector2(-10.0, 0.0), Vector2.ZERO, Vector2(10.0, 0.0), Vector2(0.0, 6.0)])
	shadow_owner.add_child(pending_shadow)
	view.register_shadow(pending_shadow)
	var pending_entry := (view.get("_shadow_meshes") as Dictionary).get(pending_shadow.get_instance_id()) as Dictionary
	var pending_mesh := pending_entry.get("mesh") as MeshInstance3D
	failed = _check(pending_mesh != null and not pending_mesh.visible, "new 3D shadows must stay hidden before their first anchor sync") or failed
	view.sync_late_visuals(0.0)
	failed = _check(pending_mesh != null and pending_mesh.visible, "3D shadows must become visible after their first anchor sync") or failed
	var animated_area := AreaEffectScene.instantiate() as AreaEffect
	var explosion_frames := SpriteFrames.new()
	explosion_frames.add_animation(&"explode")
	explosion_frames.add_frame(&"explode", texture)
	animated_area.visual_enabled = true
	animated_area.use_animated_visual = true
	animated_area.visual_frames = explosion_frames
	animated_area.visual_animation = &"explode"
	animated_area.visual_duration = 1.0
	animated_area.duration = 1.0
	animated_area.draw_enabled = true
	animated_area.position = Vector2(125.0, 90.0)
	add_child(animated_area)
	await get_tree().process_frame
	await get_tree().process_frame
	failed = _check(not animated_area.draw_enabled, "animated explosion must suppress its legacy 2D range circle") or failed
	failed = _check(animated_area.visual_root.visible, "animated explosion visual must remain visible") or failed
	failed = _check(animated_area.visual_root.has_method("set_logical_local_position"), "animated explosion must use an upright billboard") or failed
	failed = _check(not (view.get("_area_meshes") as Dictionary).has(animated_area.get_instance_id()), "animated explosion must not create a duplicate ground range disc") or failed
	var ground_frames := SpriteFrames.new()
	ground_frames.add_animation(&"ground_loop")
	ground_frames.add_frame(&"ground_loop", texture)
	var animated_ground_area := AreaEffectScene.instantiate() as AreaEffect
	animated_ground_area.visual_enabled = true
	animated_ground_area.use_animated_visual = true
	animated_ground_area.animated_visual_is_ground = true
	animated_ground_area.visual_frames = ground_frames
	animated_ground_area.visual_animation = &"ground_loop"
	animated_ground_area.visual_shape = AreaEffect.VisualShape.RECTANGLE
	animated_ground_area.rectangle_size = Vector2(110.0, 60.0)
	animated_ground_area.duration = 1.0
	animated_ground_area.position = Vector2(155.0, 110.0)
	add_child(animated_ground_area)
	await get_tree().process_frame
	view.sync_late_visuals(0.0)
	var ground_area_entry := (view.get("_area_meshes") as Dictionary).get(animated_ground_area.get_instance_id()) as Dictionary
	var ground_area_material := ground_area_entry.get("material") as StandardMaterial3D
	failed = _check(ground_area_material != null and ground_area_material.albedo_texture == texture, "ground animated AreaEffect must upload its current SpriteFrames texture") or failed
	failed = _check(not animated_ground_area.visual_root.visible, "ground animated AreaEffect must hide its duplicate 2D visual") or failed
	var layered_area := AreaEffectScene.instantiate() as AreaEffect
	layered_area.visual_enabled = true
	layered_area.visual_texture = texture
	layered_area.ground_detail_texture = texture
	layered_area.visual_shape = AreaEffect.VisualShape.RECTANGLE
	layered_area.rectangle_size = Vector2(96.0, 64.0)
	layered_area.duration = 1.0
	add_child(layered_area)
	await get_tree().process_frame
	view.sync_late_visuals(0.0)
	var layered_entry := (view.get("_area_meshes") as Dictionary).get(layered_area.get_instance_id()) as Dictionary
	var layered_material := layered_entry.get("material") as ShaderMaterial
	failed = _check(layered_material != null, "AreaEffect with a detail texture must use the layered ground shader") or failed
	if layered_material != null:
		failed = _check(layered_material.get_shader_parameter("detail_texture") == texture, "layered ground shader must receive its detail texture") or failed
		failed = _check(layered_material.get_shader_parameter("flow_speed") == layered_area.ground_flow_speed, "layered ground shader must receive flow parameters") or failed
	var layered_id := layered_area.get_instance_id()
	view.unregister_ground_visual(layered_area)
	failed = _check(not (view.get("_area_meshes") as Dictionary).has(layered_id), "AreaEffect unregister must immediately release its layered mesh") or failed
	var hit_label := HitLabelScene.instantiate()
	hit_label.position = Vector2(300.0, 220.0)
	hit_label.set_target_instance_id(77)
	hit_label.setNumber(12)
	add_child(hit_label)
	await get_tree().process_frame
	var hit_label_start_y: float = hit_label.position.y
	hit_label.merge_damage(8, Color.CYAN)
	failed = _check(hit_label.get_target_instance_id() == 77 and hit_label.get_damage_value() == 20, "HitLabel must retain its target and merge damage") or failed
	await get_tree().create_timer(0.20).timeout
	failed = _check(is_instance_valid(hit_label) and hit_label.position.y < hit_label_start_y, "HitLabel must pop toward screen-up") or failed
	var beam_line := Line2D.new()
	beam_line.points = PackedVector2Array([Vector2.ZERO, Vector2(140.0, 25.0)])
	beam_line.width = 12.0
	beam_line.default_color = Color(0.3, 0.85, 1.0, 0.9)
	beam_line.set_meta("hybrid_ground_visible", true)
	beam_line.set_meta("hybrid_segment_style", &"beam")
	beam_line.set_meta("hybrid_segment_endpoints", true)
	add_child(beam_line)
	view.register_ground_segment(beam_line)
	view.sync_late_visuals(0.0)
	var beam_entry := (view.get("_segment_meshes") as Dictionary).get(beam_line.get_instance_id()) as Dictionary
	failed = _check(beam_entry.get("primitive") is QuadMesh and beam_entry.get("material") is ShaderMaterial, "Beam must use a UV-capable quad and flowing shader") or failed
	failed = _check(beam_entry.get("start_glow") is MeshInstance3D and beam_entry.get("end_glow") is MeshInstance3D, "Beam must create start and end glow meshes") or failed
	var second_beam_line := Line2D.new()
	second_beam_line.points = PackedVector2Array([Vector2.ZERO, Vector2(80.0, -20.0)])
	second_beam_line.width = 7.0
	second_beam_line.set_meta("hybrid_ground_visible", true)
	second_beam_line.set_meta("hybrid_segment_style", &"beam")
	add_child(second_beam_line)
	view.register_ground_segment(second_beam_line)
	view.sync_late_visuals(0.0)
	var second_beam_entry := (view.get("_segment_meshes") as Dictionary).get(second_beam_line.get_instance_id()) as Dictionary
	failed = _check(beam_entry.get("primitive") == second_beam_entry.get("primitive"), "Beam instances must share one QuadMesh resource") or failed
	failed = _check(beam_entry.get("material") == second_beam_entry.get("material"), "Beam instances must share one flowing Material") or failed
	var pooled_beam_mesh := second_beam_entry.get("mesh") as MeshInstance3D
	view.unregister_ground_visual(second_beam_line)
	var third_beam_line := Line2D.new()
	third_beam_line.points = PackedVector2Array([Vector2.ZERO, Vector2(95.0, 5.0)])
	third_beam_line.set_meta("hybrid_ground_visible", true)
	third_beam_line.set_meta("hybrid_segment_style", &"beam")
	add_child(third_beam_line)
	view.register_ground_segment(third_beam_line)
	var third_beam_entry := (view.get("_segment_meshes") as Dictionary).get(third_beam_line.get_instance_id()) as Dictionary
	failed = _check(third_beam_entry.get("mesh") == pooled_beam_mesh, "released Beam MeshInstance must be reused from the pool") or failed
	var arc_line := Line2D.new()
	arc_line.points = PackedVector2Array([Vector2.ZERO, Vector2(45.0, 30.0)])
	arc_line.set_meta("hybrid_ground_visible", true)
	add_child(arc_line)
	view.register_ground_segment(arc_line)
	view.sync_late_visuals(0.0)
	var arc_entry := (view.get("_segment_meshes") as Dictionary).get(arc_line.get_instance_id()) as Dictionary
	failed = _check(arc_entry.get("primitive") == (view.get("_connected_renderer") as ConnectedEffectRenderer).shared_box_mesh, "Arc and Link paths must use the shared unit BoxMesh") or failed
	view.unregister_ground_visual(arc_line)
	failed = _check(not (view.get("_segment_meshes") as Dictionary).has(arc_line.get_instance_id()), "active unregister must immediately remove a segment without waiting for a scan") or failed
	var cone_spray := ConeSprayScene.instantiate() as ConeSprayVfx
	add_child(cone_spray)
	cone_spray.start_or_refresh(Vector2(40.0, 60.0), Vector2.RIGHT, 220.0, 34.0)
	await get_tree().process_frame
	view.sync_late_visuals(0.0)
	var cone_entry := (view.get("_ground_cone_meshes") as Dictionary).get(cone_spray.get_instance_id()) as Dictionary
	var cone_mesh := cone_entry.get("mesh") as MeshInstance3D
	failed = _check(cone_mesh != null and cone_mesh.mesh is ArrayMesh and cone_entry.get("material") is ShaderMaterial, "Cone spray must use one UV fan ArrayMesh and flowing shader") or failed
	failed = _check(cone_mesh.mesh == (view.get("_connected_renderer") as ConnectedEffectRenderer).get_cone_mesh(deg_to_rad(34.0)), "equal cone angles must reuse the cached ArrayMesh") or failed
	for shape_value in [AreaEffect.VisualShape.RECTANGLE, AreaEffect.VisualShape.CONE]:
		var shaped_area := AreaEffectScene.instantiate() as AreaEffect
		shaped_area.visual_shape = shape_value
		shaped_area.rectangle_size = Vector2(140.0, 55.0)
		shaped_area.cone_direction = Vector2(0.8, -0.6)
		shaped_area.cone_range = 190.0
		shaped_area.cone_half_angle_deg = 32.0
		shaped_area.duration = 1.0
		shaped_area.position = Vector2(180.0 + float(shape_value) * 30.0, 140.0)
		add_child(shaped_area)
		await get_tree().process_frame
		await get_tree().process_frame
		var shaped_entry := (view.get("_area_meshes") as Dictionary).get(shaped_area.get_instance_id()) as Dictionary
		var shaped_mesh := shaped_entry.get("mesh") as MeshInstance3D
		failed = _check(shaped_mesh != null and shaped_mesh.mesh is ArrayMesh and shaped_mesh.mesh.get_surface_count() == 1, "non-circular AreaEffect must create a 3D polygon mesh") or failed
		if shape_value == AreaEffect.VisualShape.RECTANGLE:
			failed = _check(shaped_area.collision_shape.shape is RectangleShape2D, "rectangle AreaEffect visual and collision must share shape classification") or failed
		else:
			var cone_collision := shaped_area.get_node_or_null("VisualShapeCollisionPolygon") as CollisionPolygon2D
			failed = _check(cone_collision != null and not cone_collision.disabled and cone_collision.polygon.size() >= 3, "cone AreaEffect must use a matching collision polygon") or failed
	failed = _check(is_equal_approx(view.camera_distance, HybridCameraDefaultsType.CAMERA_DISTANCE), "Camera3D must use the shared distance default") or failed
	view.set_view_multiplier(1.5)
	await get_tree().process_frame
	failed = _check(is_equal_approx(view.get_view_multiplier(), 1.5), "Camera3D view multiplier must apply without changing its calibrated base distance") or failed
	failed = _check(is_equal_approx(view.camera_distance, HybridCameraDefaultsType.CAMERA_DISTANCE), "view changes must not overwrite the Camera3D debug/base distance") or failed
	var ground_camera := view.get_node_or_null("GroundCamera3D") as Camera3D
	view.set_screen_shake_offset(Vector2(8.0, -5.0))
	await get_tree().process_frame
	failed = _check(ground_camera != null and absf(ground_camera.h_offset) > 0.0 and absf(ground_camera.v_offset) > 0.0, "screen shake must reach Camera3D projection offsets") or failed
	view.set_screen_shake_offset(Vector2.ZERO)
	view.set_view_multiplier(1.0)
	await get_tree().process_frame
	var rest_ground := view.get_node_or_null("GroundMeshes/RestAreaGround") as MeshInstance3D
	failed = _check(rest_ground != null, "hidden 2D RestArea texture must have a 3D ground replacement") or failed
	if rest_ground != null:
		failed = _check(rest_ground.position.distance_to(view.world_2d_to_3d(rest_sprite.global_position)) < 0.001, "3D RestArea ground must follow its 2D texture anchor") or failed
	var rest_zone_entries := view.get("_rest_zone_meshes") as Dictionary
	failed = _check(rest_zone_entries.size() == 5, "RestArea must create all five interactive 3D zone visuals") or failed
	view.call("_setup_rest_area_ground")
	failed = _check(rest_zone_entries.size() == 5, "RestArea visual setup must be idempotent") or failed
	var center_zone_entry := rest_zone_entries.get(4) as Dictionary
	var center_zone_material := center_zone_entry.get("material") as ShaderMaterial
	failed = _check(center_zone_entry.get("quad") is QuadMesh and center_zone_material != null, "RestArea zone must use one radial UV quad shader") or failed
	rest_area.hover_zone_id = 4
	rest_area._zone4_hold_elapsed = 0.5
	view.sync_late_visuals(0.0)
	failed = _check(is_equal_approx(float(center_zone_material.get_shader_parameter("hovered")), 1.0), "RestArea shader must receive hover emphasis") or failed
	failed = _check(is_equal_approx(float(center_zone_material.get_shader_parameter("hold_progress")), 0.5), "RestArea center ring must receive hold progress") or failed
	rest_area.modulate.a = 0.4
	view.sync_late_visuals(0.0)
	failed = _check(is_equal_approx(float(center_zone_material.get_shader_parameter("visibility_alpha")), 0.4), "RestArea shader must follow area fade alpha") or failed
	rest_area.visible = false
	view.sync_late_visuals(0.0)
	failed = _check(not (center_zone_entry.get("mesh") as MeshInstance3D).visible and not rest_ground.visible, "RestArea ground and zones must hide together") or failed
	rest_area.visible = true
	rest_area.modulate.a = 1.0
	var ground_mesh := view.get_node_or_null("GroundMeshes/DummyCellGround") as MeshInstance3D
	failed = _check(ground_mesh != null, "dummy 2D Cell must create a mapped 3D ground mesh") or failed
	if ground_mesh != null:
		var position_before := ground_mesh.position
		var recenter_offset := Vector2(140.0, -75.0)
		board.position += recenter_offset
		board.board_recentered.emit(recenter_offset)
		await get_tree().process_frame
		var expected_delta := view.world_2d_to_3d(recenter_offset)
		failed = _check(ground_mesh.position.distance_to(position_before + expected_delta) < 0.001, "3D Cell must follow 2D Board recenter") or failed
		board.board_visual_active_changed.emit(false, true)
		failed = _check(not ground_mesh.visible, "3D Cell must hide with the 2D Board") or failed
		board.board_visual_active_changed.emit(true, true)
		failed = _check(ground_mesh.visible, "3D Cell must become visible with the 2D Board") or failed
	var screen := view.project_world_to_screen(player.position)
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	failed = _check(screen.distance_to(viewport_center) < 2.0, "camera target must project to viewport center") or failed
	var points := [Vector2.ZERO, Vector2(120.0, -90.0), Vector2(-240.0, 310.0)]
	for point: Vector2 in points:
		var projected := view.project_world_to_screen(point)
		var round_trip := view.screen_to_world_2d(projected)
		failed = _check(round_trip.distance_to(point) < 0.25, "projection round trip failed for %s: %s" % [point, round_trip]) or failed
	var screen_right := view.world_vector_to_screen(Vector2.RIGHT, player.position)
	failed = _check(screen_right.length_squared() > 0.01, "world direction must produce a screen direction") or failed
	var spear := ProjectileScene.instantiate() as Projectile
	spear.projectile_texture = SpearTexture
	spear.base_displacement = Vector2(180.0, -35.0)
	spear.position = Vector2(40.0, 25.0)
	add_child(spear)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_spear_direction := view.world_vector_to_screen(spear.base_displacement, spear.global_position).normalized()
	var visual_spear_direction := Vector2.UP.rotated(spear.projectile_root.global_rotation).normalized()
	failed = _check(visual_spear_direction.dot(expected_spear_direction) > 0.995, "spear art forward axis must face its projected flight direction: visual=%s expected=%s rotation=%s" % [visual_spear_direction, expected_spear_direction, spear.projectile_root.global_rotation_degrees]) or failed
	view.configure(56.0, -4.0, 20.0)
	await get_tree().process_frame
	failed = _check(view.can_project_world_point(player.position), "camera must remain projectable after reconfigure") or failed
	var base_enemy := BaseEnemyScene.instantiate() as BaseEnemy
	base_enemy.position = Vector2(80.0, 40.0)
	add_child(base_enemy)
	var elite_enemy := EliteEnemyScene.instantiate() as BaseEnemy
	elite_enemy.position = Vector2(-120.0, 60.0)
	add_child(elite_enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	for enemy: BaseEnemy in [base_enemy, elite_enemy]:
		var body := enemy.get_node("Body") as Sprite2D
		failed = _check(body.has_method("set_screen_offset"), "%s body must use billboard projection" % enemy.name) or failed
		var expected_canvas := view.project_world_to_canvas(enemy.global_position, get_viewport())
		failed = _check(body.global_position.distance_to(expected_canvas) < 2.0, "%s billboard does not match logical footpoint" % enemy.name) or failed
	if failed:
		print("FAIL hybrid projection")
		get_tree().quit(1)
	else:
		print("PASS hybrid projection")
		get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
