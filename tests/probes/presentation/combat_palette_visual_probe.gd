extends Node2D

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const MARKER_SCRIPT := preload("res://Combat/visual/affiliation_marker.gd")
const PLAYER_TEXTURE := preload("res://asset/images/characters/pixel/idle_bottom.png")
const ENEMY_ENTRIES := [
	["ROLLING", preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")],
	["INTERCEPTOR", preload("res://Npc/enemy/scenes/enemy_interceptor.tscn")],
	["BOMBER", preload("res://Npc/enemy/scenes/enemy_bomber.tscn")],
	["MIRROR", preload("res://Npc/enemy/scenes/enemy_mirror_caster.tscn")],
	["ELITE", preload("res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn")],
]
const SUPPORT_ENTRIES := [
	["SPEED SUPPORT", preload("res://Npc/enemy/scenes/enemy_orbit_support.tscn")],
	["REPAIR", preload("res://Npc/enemy/scenes/enemy_repair_unit.tscn")],
	["SHIELD CORE", preload("res://Npc/enemy/scenes/enemy_shield_core.tscn")],
]

var _validation_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_build_background()
	_add_player()
	_add_enemy_row()
	_add_support_row()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_path := OS.get_environment("COMBAT_PALETTE_PROBE_OUTPUT")
	if output_path.is_empty():
		output_path = OS.get_cache_dir().path_join("combat_palette_visual_probe.png")
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error == OK and _validation_errors.is_empty():
		print("PASS: combat palette visual probe -> %s" % output_path)
	else:
		if error != OK:
			_validation_errors.append("screenshot save failed: %s" % error_string(error))
		for validation_error in _validation_errors:
			push_error(validation_error)
	await TEST_TEARDOWN.finish(self, 0 if error == OK and _validation_errors.is_empty() else 2, _reset_runtime)


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color(0.018, 0.028, 0.04, 1.0)
	background.position = Vector2.ZERO
	background.size = get_viewport().get_visible_rect().size
	background.z_index = -100
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)

	var title := _make_label(
		"COMBAT OWNERSHIP PALETTE // PLAYER • ENEMY • SUPPORT",
		Vector2(32.0, 22.0),
		Vector2(1216.0, 42.0),
		20,
		PALETTE.PLAYER_CORE
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var divider := ColorRect.new()
	divider.position = Vector2(48.0, 350.0)
	divider.size = Vector2(1184.0, 2.0)
	divider.color = Color(PALETTE.NEUTRAL_PRIMARY, 0.34)
	add_child(divider)


func _add_player() -> void:
	var player := Node2D.new()
	player.position = Vector2(125.0, 190.0)
	var marker := MARKER_SCRIPT.new()
	marker.position = Vector2(0.0, 8.0)
	marker.scale = Vector2(1.0, 0.58)
	marker.marker_shape = 0
	marker.marker_color = Color(PALETTE.PLAYER_PRIMARY, 0.82)
	marker.radius = 23.0
	marker.line_width = 2.5
	player.add_child(marker)
	var sprite := Sprite2D.new()
	sprite.position = Vector2(0.5, -5.0)
	sprite.texture = PLAYER_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(sprite)
	add_child(player)
	add_child(_make_label("PLAYER", Vector2(70.0, 246.0), Vector2(110.0, 28.0), 14, PALETTE.PLAYER_PRIMARY))


func _add_enemy_row() -> void:
	for index in range(ENEMY_ENTRIES.size()):
		var entry: Array = ENEMY_ENTRIES[index]
		var enemy := _instantiate_enemy(entry[1] as PackedScene)
		if enemy == null:
			continue
		enemy.position = Vector2(330.0 + float(index) * 185.0, 190.0)
		add_child(enemy)
		var label := _make_label(
			str(entry[0]),
			enemy.position + Vector2(-76.0, 56.0),
			Vector2(152.0, 28.0),
			13,
			Color(PALETTE.PLAYER_CORE, 0.78)
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)


func _add_support_row() -> void:
	for index in range(SUPPORT_ENTRIES.size()):
		var entry: Array = SUPPORT_ENTRIES[index]
		var enemy := _instantiate_enemy(entry[1] as PackedScene)
		if enemy == null:
			continue
		enemy.position = Vector2(300.0 + float(index) * 330.0, 520.0)
		var link_target: BaseEnemy = null
		if index > 0:
			link_target = _instantiate_enemy(ENEMY_ENTRIES[0][1] as PackedScene)
			if link_target != null:
				link_target.position = enemy.position + Vector2(-110.0, 0.0)
				add_child(link_target)
		_set_property_if_present(enemy, &"aura_radius", 92.0)
		_set_property_if_present(enemy, &"heal_radius", 92.0)
		add_child(enemy)
		if index == 1 and link_target != null:
			enemy.set("_heal_target", link_target)
		elif index == 2 and link_target != null:
			var protected_targets: Array[BaseEnemy] = [link_target]
			enemy.set("_protected_targets", protected_targets)
		_validate_support_visual_contract(enemy, str(entry[0]), index > 0)
		enemy.queue_redraw()
		var label := _make_label(
			str(entry[0]),
			enemy.position + Vector2(-88.0, 116.0),
			Vector2(176.0, 28.0),
			13,
			Color(PALETTE.PLAYER_CORE, 0.82)
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	add_child(_make_label("ENEMY OUTER / HEAL INNER", Vector2(500.0, 548.0), Vector2(190.0, 24.0), 11, PALETTE.HEAL))
	add_child(_make_label("ENEMY OUTER / SHIELD INNER", Vector2(805.0, 548.0), Vector2(210.0, 24.0), 11, PALETTE.SHIELD))


func _validate_support_visual_contract(enemy: BaseEnemy, label: String, expects_link: bool) -> void:
	var aura := enemy.call("get_hybrid_aura_visual") as Dictionary
	var line_color := aura.get("line_color", Color.TRANSPARENT) as Color
	if not line_color.is_equal_approx(Color(PALETTE.ENEMY_PRIMARY, line_color.a)):
		_validation_errors.append("%s aura does not use enemy ownership color" % label)
	if not aura.has("detail_color"):
		_validation_errors.append("%s aura is missing semantic detail color" % label)
	if not expects_link:
		return
	var links := enemy.call("get_hybrid_link_visuals") as Array
	if links.is_empty():
		_validation_errors.append("%s did not expose its production link visual" % label)
		return
	var link := links[0] as Dictionary
	if not link.has("outer_color") or not link.has("color"):
		_validation_errors.append("%s link is missing ownership/function layers" % label)


func _instantiate_enemy(scene: PackedScene) -> BaseEnemy:
	var enemy := scene.instantiate() as BaseEnemy
	if enemy == null:
		return null
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _set_property_if_present(object: Object, property_name: StringName, value: Variant) -> void:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			object.set(property_name, value)
			return


func _make_label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.03, 0.94))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _reset_runtime() -> void:
	pass
