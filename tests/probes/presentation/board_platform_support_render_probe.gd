extends Node

const PlatformRendererType := preload("res://Visual/Oblique/board_platform_renderer.gd")
const BackgroundTexture := preload("res://Visual/Oblique/assets/background_variants/unloaded_world_quarantine_sector_vertical.png")
const GroundTexture := preload("res://asset/images/cells/default.png")

class ProbeView:
	extends Node3D
	var world_scale := 0.006
	var _board_visual_active := true
	var _ground_root: Node3D

	func _init() -> void:
		_ground_root = Node3D.new()
		_ground_root.name = "GroundMeshes"
		add_child(_ground_root)

class ProbeCell:
	extends Node2D
	var board_enabled := true

	func configure(rect: Rect2) -> void:
		position = rect.position
		var texture_root := Node2D.new()
		texture_root.name = "Texture"
		texture_root.position = rect.size * 0.5
		add_child(texture_root)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		var texture := GradientTexture2D.new()
		texture.width = maxi(roundi(rect.size.x), 1)
		texture.height = maxi(roundi(rect.size.y), 1)
		sprite.texture = texture
		# The probe only needs this sprite as a source of cell bounds. Keeping it
		# visible would draw its default magenta gradient over the 3D viewport.
		sprite.visible = false
		texture_root.add_child(sprite)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: board platform support render probe requires a graphical rendering driver")
		get_tree().quit(0)
		return
	var output_dir := OS.get_environment("BOARD_SUPPORT_RENDER_OUTPUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://test-results/board_support_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scenarios := {
		"full_3x3": {"rects": _full_grid_rects(), "view": "overview"},
		"t_shape": {"rects": _t_shape_rects(), "view": "overview"},
		"cross_shape": {"rects": _cross_shape_rects(), "view": "overview"},
		"mixed_sizes": {"rects": _mixed_size_rects(), "view": "overview"},
		"front_edge_closeup": {"rects": _full_grid_rects(), "view": "front"},
		"upper_corner_closeup": {"rects": _full_grid_rects(), "view": "corner"},
	}
	var failed := false
	for scenario_name in scenarios:
		var scenario := scenarios[scenario_name] as Dictionary
		var path := output_dir.path_join("%s.png" % scenario_name)
		var saved := await _render_scenario(
			scenario.get("rects", []) as Array,
			path,
			String(scenario.get("view", "overview"))
		)
		if not saved:
			failed = true
	if failed:
		print("FAIL: board platform support render probe")
	else:
		print("PASS: board platform support render probe output=%s" % output_dir)
	get_tree().quit(1 if failed else 0)


func _render_scenario(rects: Array, output_path: String, view_mode: String = "overview") -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	var scene_root := Node3D.new()
	viewport.add_child(scene_root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.003, 0.008, 0.020, 1.0)
	environment_node.environment = environment
	scene_root.add_child(environment_node)
	var camera := Camera3D.new()
	camera.fov = 43.0
	scene_root.add_child(camera)
	if view_mode == "front":
		camera.position = Vector3(0.0, 5.8, 9.4)
		camera.look_at(Vector3(0.0, -0.28, 3.2), Vector3.UP)
	elif view_mode == "corner":
		camera.position = Vector3(6.0, 2.1, -2.8)
		camera.look_at(Vector3(4.5, -0.10, -4.5), Vector3.UP)
	else:
		camera.position = Vector3(0.0, 9.5, 12.5)
		camera.look_at(Vector3(0.0, -0.35, 0.0), Vector3.UP)
	camera.current = true
	_add_camera_background(camera)
	var probe_view := ProbeView.new()
	scene_root.add_child(probe_view)
	var cell_root := Node2D.new()
	viewport.add_child(cell_root)
	var centered_rects := _center_rects(rects)
	var cells: Array[Node2D] = []
	for rect_variant in centered_rects:
		var rect := rect_variant as Rect2
		var cell := ProbeCell.new()
		cell.configure(rect)
		cell_root.add_child(cell)
		cells.append(cell)
		_add_ground_tile(probe_view._ground_root, rect, probe_view.world_scale)
	var renderer := PlatformRendererType.new()
	renderer.setup(probe_view)
	renderer.rebuild(cells)
	for frame_index in range(4):
		await get_tree().process_frame
	var viewport_texture := viewport.get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	var valid := image != null and not image.is_empty() and image.get_width() == 640 and image.get_height() == 360
	if valid:
		valid = image.save_png(output_path) == OK
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	remove_child(viewport)
	viewport.queue_free()
	await get_tree().process_frame
	return valid


func _add_camera_background(camera: Camera3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = Vector3(0.0, 0.0, -28.0)
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = Vector2(55.0, 31.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = BackgroundTexture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	quad.material = material
	mesh_instance.mesh = quad
	camera.add_child(mesh_instance)


func _add_ground_tile(root: Node3D, rect: Rect2, world_scale: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = rect.size * world_scale
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = GroundTexture
	material.albedo_color = Color(0.78, 0.84, 0.90, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(rect.get_center().x * world_scale, 0.0, rect.get_center().y * world_scale)
	root.add_child(mesh_instance)


func _center_rects(rects: Array) -> Array[Rect2]:
	if rects.is_empty():
		return []
	var bounds := rects[0] as Rect2
	for index in range(1, rects.size()):
		bounds = bounds.merge(rects[index] as Rect2)
	var offset := -bounds.get_center()
	var centered: Array[Rect2] = []
	for rect_variant in rects:
		var rect := rect_variant as Rect2
		centered.append(Rect2(rect.position + offset, rect.size))
	return centered


func _full_grid_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for y in range(3):
		for x in range(3):
			result.append(Rect2(Vector2(x, y) * 512.0, Vector2(512.0, 512.0)))
	return result


func _t_shape_rects() -> Array[Rect2]:
	return [
		Rect2(Vector2(512.0, 0.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(0.0, 512.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(512.0, 512.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(1024.0, 512.0), Vector2(512.0, 512.0)),
	]


func _cross_shape_rects() -> Array[Rect2]:
	return [
		Rect2(Vector2(512.0, 0.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(0.0, 512.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(512.0, 512.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(1024.0, 512.0), Vector2(512.0, 512.0)),
		Rect2(Vector2(512.0, 1024.0), Vector2(512.0, 512.0)),
	]


func _mixed_size_rects() -> Array[Rect2]:
	return [
		Rect2(Vector2(0.0, 0.0), Vector2(768.0, 512.0)),
		Rect2(Vector2(768.0, 128.0), Vector2(256.0, 256.0)),
		Rect2(Vector2(128.0, 512.0), Vector2(384.0, 256.0)),
	]
