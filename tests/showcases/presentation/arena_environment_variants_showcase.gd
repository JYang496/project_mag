extends Node3D

const GROUND_STYLE := preload("res://Visual/Oblique/arena_ground_style.gd")
const GROUND_SHADER := preload("res://Shaders/battlefield_deployment_ground.gdshader")

const PANEL_POSITIONS := [
	Vector3(-3.15, 1.45, 0.0),
	Vector3(3.15, 1.45, 0.0),
	Vector3(-3.15, -1.55, 0.0),
	Vector3(3.15, -1.55, 0.0),
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("071018"))
	var tile_texture := _build_floor_texture()
	for theme in range(GROUND_STYLE.THEME_COUNT):
		_add_theme_panel(theme, tile_texture)
	_build_overlay()
	print("PASS: arena environment variants showcase")


func _add_theme_panel(theme: int, tile_texture: Texture2D) -> void:
	var style := GROUND_STYLE.build_style(100 + theme * 17, theme)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Theme%d" % theme
	mesh_instance.position = PANEL_POSITIONS[theme]
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = Vector2(5.65, 2.35)
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("terrain_texture", tile_texture)
	quad.material = material
	mesh_instance.mesh = quad
	add_child(mesh_instance)
	mesh_instance.set_instance_shader_parameter("deployment_progress", 1.0)
	mesh_instance.set_instance_shader_parameter("deployment_dim", 1.0)
	mesh_instance.set_instance_shader_parameter("arena_theme_tint", style.theme_tint)
	mesh_instance.set_instance_shader_parameter("arena_midtone_color", style.midtone_color)
	mesh_instance.set_instance_shader_parameter("arena_midtone_strength", float(style.midtone_strength))
	mesh_instance.set_instance_shader_parameter("arena_accent_color", style.accent_color)
	mesh_instance.set_instance_shader_parameter("arena_variant", float(style.variant))
	mesh_instance.set_instance_shader_parameter("arena_detail_seed", float(style.seed))
	mesh_instance.set_instance_shader_parameter("arena_detail_strength", float(style.detail_strength))
	mesh_instance.set_instance_shader_parameter("arena_decal_id", float(style.decal_id))
	mesh_instance.set_instance_shader_parameter("arena_decal_rotation", float(style.decal_rotation))
	mesh_instance.set_instance_shader_parameter("arena_decal_strength", float(style.decal_strength))
	mesh_instance.set_instance_shader_parameter("arena_ambient_phase", float(style.ambient_phase))


func _build_floor_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var color := Color("263340")
			if x in [0, 1, 31, 32, 62, 63] or y in [0, 1, 31, 32, 62, 63]:
				color = Color("151f29")
			elif (x + y) % 17 == 0:
				color = Color("2d3b49")
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _build_overlay() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var title := _label("ARENA MATERIAL UNITY · 4 DECORATIVE THEMES", 26, Color("d9f4ff"))
	title.position = Vector2(70.0, 24.0)
	title.size = Vector2(1140.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)
	var subtitle := _label("Same footprint and gameplay · restrained industrial variation · combat cues stay dominant", 15, Color("83aabb"))
	subtitle.position = Vector2(70.0, 62.0)
	subtitle.size = Vector2(1140.0, 28.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(subtitle)
	var label_positions := [Vector2(85.0, 297.0), Vector2(665.0, 297.0), Vector2(85.0, 589.0), Vector2(665.0, 589.0)]
	for theme in range(GROUND_STYLE.THEME_COUNT):
		var style := GROUND_STYLE.build_style(100 + theme * 17, theme)
		var theme_label := _label(str(style.theme_name), 19, style.accent_color)
		theme_label.position = label_positions[theme]
		theme_label.size = Vector2(530.0, 34.0)
		theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.add_child(theme_label)
	var footer := _label("Review at 1280×720 · deterministic placement · decorative layer only", 15, Color("8297a4"))
	footer.position = Vector2(70.0, 671.0)
	footer.size = Vector2(1140.0, 28.0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(footer)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
