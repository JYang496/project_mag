extends Node2D

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const TARGET_SCENE := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const AURA_ENTRIES := [
	{
		"title": "SPEED AURA",
		"detail": "MOVEMENT SPEED SUPPORT",
		"scene": preload("res://Npc/enemy/scenes/enemy_orbit_support.tscn"),
		"accent": PALETTE.SPEED,
	},
	{
		"title": "REPAIR RANGE",
		"detail": "HEAL CAST LINK",
		"scene": preload("res://Npc/enemy/scenes/enemy_repair_unit.tscn"),
		"accent": PALETTE.HEAL,
	},
	{
		"title": "SHIELD AURA",
		"detail": "DAMAGE REDUCTION LINKS",
		"scene": preload("res://Npc/enemy/scenes/enemy_shield_core.tscn"),
		"accent": PALETTE.SHIELD,
	},
]

var _validation_errors: PackedStringArray = []


func _ready() -> void:
	_build_background()
	_build_gallery()
	await get_tree().process_frame
	_validate_gallery()
	if _validation_errors.is_empty():
		print("ENEMY_AURA_GALLERY_READY auras=%d" % AURA_ENTRIES.size())
	else:
		for validation_error in _validation_errors:
			push_error(validation_error)


func _build_background() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280.0, 720.0)
	background.color = Color(0.014, 0.023, 0.034, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)

	var title := _make_label(
		"ENEMY AURA EFFECTS // PRODUCTION VISUAL GALLERY",
		Vector2(32.0, 22.0), Vector2(1216.0, 36.0), 22, PALETTE.PLAYER_CORE
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := _make_label(
		"Enemy-red ownership ring  •  Functional color identifies the support effect",
		Vector2(32.0, 60.0), Vector2(1216.0, 28.0), 13, Color(PALETTE.NEUTRAL_PRIMARY, 0.82)
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	for index in range(1, AURA_ENTRIES.size()):
		var divider := ColorRect.new()
		divider.position = Vector2(80.0 + float(index) * 400.0, 116.0)
		divider.size = Vector2(1.0, 530.0)
		divider.color = Color(PALETTE.NEUTRAL_PRIMARY, 0.18)
		add_child(divider)


func _build_gallery() -> void:
	for index in range(AURA_ENTRIES.size()):
		var entry: Dictionary = AURA_ENTRIES[index]
		var center := Vector2(280.0 + float(index) * 400.0, 370.0)
		var source := _instantiate_enemy(entry["scene"] as PackedScene)
		if source == null:
			_validation_errors.append("%s failed to instantiate" % str(entry["title"]))
			continue

		_set_radius(source, 138.0)
		source.position = center
		source.set_meta(&"aura_showcase_source", true)
		add_child(source)

		var targets: Array[BaseEnemy] = []
		for offset in _target_offsets(index):
			var target := _instantiate_enemy(TARGET_SCENE)
			if target == null:
				continue
			target.position = center + offset
			targets.append(target)
			add_child(target)

		if index == 1 and not targets.is_empty():
			source.set("_heal_target", targets[0])
		elif index == 2:
			source.set("_protected_targets", targets)
		source.queue_redraw()

		var title := _make_label(
			str(entry["title"]), Vector2(center.x - 170.0, 112.0), Vector2(340.0, 32.0),
			18, entry["accent"] as Color
		)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(title)

		var detail := _make_label(
			str(entry["detail"]), Vector2(center.x - 170.0, 146.0), Vector2(340.0, 24.0),
			12, Color(PALETTE.PLAYER_CORE, 0.72)
		)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(detail)

		var legend := _make_label(
			"SOURCE" if index == 0 else "SOURCE  →  AFFECTED ENEMY",
			Vector2(center.x - 170.0, 606.0), Vector2(340.0, 24.0), 11,
			Color(entry["accent"] as Color, 0.82)
		)
		legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(legend)


func _target_offsets(index: int) -> Array[Vector2]:
	match index:
		0:
			return [Vector2(-88.0, 36.0), Vector2(92.0, -30.0)]
		1:
			return [Vector2(102.0, -18.0)]
		2:
			return [Vector2(-96.0, 48.0), Vector2(92.0, -42.0)]
	return []


func _set_radius(source: BaseEnemy, radius: float) -> void:
	if source is EnemyRepairUnit:
		source.set("heal_radius", radius)
	else:
		source.set("aura_radius", radius)


func _instantiate_enemy(scene: PackedScene) -> BaseEnemy:
	var enemy := scene.instantiate() as BaseEnemy
	if enemy != null:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _validate_gallery() -> void:
	var sources := get_tree().get_nodes_in_group(&"hybrid_enemy_aura_source")
	var showcase_count := 0
	var relationship_kinds: Dictionary = {}
	for source in sources:
		if not source.has_meta(&"aura_showcase_source"):
			continue
		showcase_count += 1
		if not source.has_method("get_hybrid_aura_visual"):
			_validation_errors.append("Aura source is missing the production visual contract")
			continue
		var visual := source.call("get_hybrid_aura_visual") as Dictionary
		relationship_kinds[visual.get("relationship_kind", &"")] = true
		if float(visual.get("radius", 0.0)) <= 0.0:
			_validation_errors.append("Aura source exposes an invalid radius")
	if showcase_count != AURA_ENTRIES.size():
		_validation_errors.append("Expected %d aura sources, found %d" % [AURA_ENTRIES.size(), showcase_count])
	for required_kind in [&"speed_aura", &"repair_range", &"shield_aura"]:
		if not relationship_kinds.has(required_kind):
			_validation_errors.append("Missing aura relationship: %s" % required_kind)


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
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 2)
	return label

