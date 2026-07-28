# Archived 2026-07-28: release-specific visual patrol.
extends Node

const ENEMY_SCENES := [
	"res://Npc/enemy/scenes/enemy_bomber.tscn",
	"res://Npc/enemy/scenes/enemy_interceptor.tscn",
	"res://Npc/enemy/scenes/enemy_mine_crawler.tscn",
	"res://Npc/enemy/scenes/enemy_mirror_caster.tscn",
	"res://Npc/enemy/scenes/enemy_mirror_clone.tscn",
	"res://Npc/enemy/scenes/enemy_mortar_turret.tscn",
	"res://Npc/enemy/scenes/enemy_orbit_support.tscn",
	"res://Npc/enemy/scenes/enemy_repair_unit.tscn",
	"res://Npc/enemy/scenes/enemy_rolling_ball.tscn",
	"res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn",
	"res://Npc/enemy/scenes/enemy_shield_core.tscn",
	"res://Npc/enemy/scenes/enemy_spike_turret.tscn",
	"res://Npc/enemy/scenes/enemy_tar_mine_crawler.tscn",
	"res://Npc/enemy/scenes/enemy_wheel_cart.tscn",
	"res://Npc/enemy/scenes/reward_enemy.tscn",
]

const COLUMNS := 5
const CELL_SIZE := Vector2(240.0, 190.0)
const GRID_ORIGIN := Vector2(160.0, 132.0)


func _ready() -> void:
	var output_path := OS.get_environment("ENEMY_SIZE_MATRIX_OUTPUT")
	if output_path.is_empty():
		push_error("ENEMY_SIZE_MATRIX_OUTPUT is required.")
		get_tree().quit(2)
		return

	_build_background()
	for index in range(ENEMY_SCENES.size()):
		_add_enemy_cell(index, ENEMY_SCENES[index])

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Enemy size matrix screenshot failed: %s" % error_string(error))
		get_tree().quit(2)
		return
	print("PASS: enemy size matrix patrol")
	get_tree().quit(0)


func _build_background() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var stage_offset_x := (viewport_size.x - 1280.0) * 0.5
	var background := ColorRect.new()
	background.color = Color(0.018, 0.028, 0.04, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.position = Vector2(32.0, 20.0)
	title.size = Vector2(viewport_size.x - 64.0, 48.0)
	title.text = "ENEMY SILHOUETTE MATRIX // 32 px / 48 px SOURCE TIERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.52, 0.92, 0.94))
	background.add_child(title)

	for row in range(3):
		for column in range(COLUMNS):
			var panel := ColorRect.new()
			panel.position = Vector2(stage_offset_x + 40.0 + column * CELL_SIZE.x, 82.0 + row * CELL_SIZE.y)
			panel.size = Vector2(232.0, 182.0)
			panel.color = Color(0.035, 0.075, 0.105, 0.96)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			background.add_child(panel)
			var top_line := ColorRect.new()
			top_line.size = Vector2(panel.size.x, 2.0)
			top_line.color = Color(0.18, 0.52, 0.62)
			panel.add_child(top_line)


func _add_enemy_cell(index: int, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	var enemy := packed.instantiate() as BaseEnemy if packed != null else null
	if enemy == null:
		push_error("Unable to instantiate enemy matrix entry: %s" % scene_path)
		return
	var column := index % COLUMNS
	var row := index / COLUMNS
	var viewport_size := get_viewport().get_visible_rect().size
	var stage_offset_x := (viewport_size.x - 1280.0) * 0.5
	var center := GRID_ORIGIN + Vector2(stage_offset_x + column * CELL_SIZE.x, row * CELL_SIZE.y)
	enemy.position = center
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(enemy)
	if _has_property(enemy, &"aura_visual_enabled"):
		enemy.set("aura_visual_enabled", false)
	if _has_property(enemy, &"aura_fill_color"):
		enemy.set("aura_fill_color", Color.TRANSPARENT)
	if _has_property(enemy, &"aura_line_color"):
		enemy.set("aura_line_color", Color.TRANSPARENT)
	if _has_property(enemy, &"heal_radius"):
		enemy.set("heal_radius", 0.0)
	enemy.queue_redraw()
	for child in enemy.get_children():
		if child.name not in [&"Body", &"GroundShadow", &"HurtBox", &"NPCCollision"]:
			child.queue_free()

	var hp_bar := enemy.call("_ensure_enemy_hp_bar") as EnemyHpBar
	if hp_bar != null:
		hp_bar.show_for(10.0)

	var label := Label.new()
	label.position = center + Vector2(-105.0, 54.0)
	label.size = Vector2(210.0, 34.0)
	label.text = scene_path.get_file().get_basename().trim_prefix("enemy_").replace("_", " ").to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.88))
	add_child(label)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false
