extends RefCounted
class_name HintPresenter

const HUD_MARGIN := 16.0
const REST_HINT_SIZE := Vector2(320, 44)
const REST_HINT_WORLD_SIZE := Vector2(156, 44)
const REST_HINT_WORLD_MAX_WIDTH := 220.0
const REST_HINT_WORLD_FONT_SIZE := 18
const REST_HINT_WORLD_MIN_FONT_SIZE := 14
const REST_HINT_TOP_MARGIN := 88.0
const REST_ZONE_HINT_SIZE := Vector2(240, 30)

var owner_ui: Node
var gui_root: Control
var quest_hint_label: Label
var rest_area_hover_hint_label: Label
var rest_area_hover_hint_anchor_world := Vector2.ZERO
var rest_area_hover_hint_use_world_anchor := false
var rest_area_zone_hint_labels: Array[Label] = []
var rest_area_zone_hint_anchors: Array[Vector2] = []

func bind(owner: Node, root: Control) -> void:
	owner_ui = owner
	gui_root = root

func ensure_quest_hint() -> Label:
	if quest_hint_label != null and is_instance_valid(quest_hint_label):
		return quest_hint_label
	quest_hint_label = Label.new()
	quest_hint_label.name = "QuestHint"
	quest_hint_label.visible = false
	quest_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_hint_label.text = ""
	gui_root.add_child(quest_hint_label)
	return quest_hint_label

func ensure_rest_area_hover_hint() -> Label:
	if rest_area_hover_hint_label != null and is_instance_valid(rest_area_hover_hint_label):
		return rest_area_hover_hint_label
	rest_area_hover_hint_label = Label.new()
	rest_area_hover_hint_label.name = "RestAreaHoverHint"
	rest_area_hover_hint_label.visible = false
	rest_area_hover_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_area_hover_hint_label.z_index = 50
	rest_area_hover_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_area_hover_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rest_area_hover_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rest_area_hover_hint_label.max_lines_visible = 1
	rest_area_hover_hint_label.clip_text = true
	rest_area_hover_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rest_area_hover_hint_label.add_theme_font_size_override("font_size", 18)
	rest_area_hover_hint_label.add_theme_constant_override("line_spacing", 0)
	rest_area_hover_hint_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
	rest_area_hover_hint_label.add_theme_stylebox_override("normal", _build_rest_area_hint_style())
	rest_area_hover_hint_label.size = REST_HINT_SIZE
	gui_root.add_child(rest_area_hover_hint_label)
	return rest_area_hover_hint_label

func create_rest_area_zone_hint_label() -> Label:
	var label := Label.new()
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 15)
	label.size = REST_ZONE_HINT_SIZE
	gui_root.add_child(label)
	return label

func ensure_rest_area_zone_hint_capacity(count: int) -> void:
	while rest_area_zone_hint_labels.size() < count:
		rest_area_zone_hint_labels.append(create_rest_area_zone_hint_label())
	while rest_area_zone_hint_anchors.size() < count:
		rest_area_zone_hint_anchors.append(Vector2.ZERO)

func hide_rest_area_zone_hint_labels() -> void:
	for label in rest_area_zone_hint_labels:
		if label:
			label.visible = false
	rest_area_zone_hint_anchors.clear()

func set_rest_area_zone_hints_at_world(hints: Array) -> void:
	ensure_rest_area_hover_hint()
	rest_area_hover_hint_label.visible = false
	rest_area_hover_hint_use_world_anchor = false
	var count := hints.size()
	ensure_rest_area_zone_hint_capacity(count)
	for idx in range(rest_area_zone_hint_labels.size()):
		var label := rest_area_zone_hint_labels[idx]
		if label == null:
			continue
		if idx >= count:
			label.visible = false
			continue
		var entry: Variant = hints[idx]
		if not (entry is Dictionary):
			label.visible = false
			continue
		var hint_dict := entry as Dictionary
		var text := str(hint_dict.get("text", ""))
		var world_pos_variant: Variant = hint_dict.get("world_pos", Vector2.ZERO)
		if not (world_pos_variant is Vector2) or text.strip_edges() == "":
			label.visible = false
			continue
		var world_pos: Vector2 = world_pos_variant as Vector2
		rest_area_zone_hint_anchors[idx] = world_pos
		label.text = text
		label.visible = true
	update_rest_area_hover_hint_position()

func set_rest_area_hover_hint(text: String) -> void:
	ensure_rest_area_hover_hint()
	hide_rest_area_zone_hint_labels()
	rest_area_hover_hint_label.add_theme_font_size_override("font_size", REST_HINT_WORLD_FONT_SIZE)
	rest_area_hover_hint_label.size = REST_HINT_SIZE
	rest_area_hover_hint_label.text = text
	rest_area_hover_hint_label.visible = text.strip_edges() != ""
	rest_area_hover_hint_use_world_anchor = false
	if owner_ui:
		var viewport := owner_ui.get_viewport()
		if viewport:
			layout_rest_area_hover_hint(viewport.get_visible_rect().size)

func set_rest_area_hover_hint_at_world(text: String, world_pos: Vector2) -> void:
	ensure_rest_area_hover_hint()
	hide_rest_area_zone_hint_labels()
	_fit_rest_area_hover_hint_to_world_text(text)
	rest_area_hover_hint_label.text = text
	rest_area_hover_hint_label.visible = text.strip_edges() != ""
	rest_area_hover_hint_anchor_world = world_pos
	rest_area_hover_hint_use_world_anchor = rest_area_hover_hint_label.visible
	update_rest_area_hover_hint_position()

func _fit_rest_area_hover_hint_to_world_text(text: String) -> void:
	var font_size := REST_HINT_WORLD_FONT_SIZE
	var text_width := _measure_rest_area_hover_hint_text(text, font_size)
	var max_text_width := REST_HINT_WORLD_MAX_WIDTH - 20.0
	while text_width > max_text_width and font_size > REST_HINT_WORLD_MIN_FONT_SIZE:
		font_size -= 1
		text_width = _measure_rest_area_hover_hint_text(text, font_size)
	rest_area_hover_hint_label.add_theme_font_size_override("font_size", font_size)
	rest_area_hover_hint_label.size = Vector2(
		clampf(text_width + 24.0, REST_HINT_WORLD_SIZE.x, REST_HINT_WORLD_MAX_WIDTH),
		REST_HINT_WORLD_SIZE.y
	)

func _measure_rest_area_hover_hint_text(text: String, font_size: int) -> float:
	var font := rest_area_hover_hint_label.get_theme_font("font")
	if font == null:
		return float(text.length() * font_size)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

func clear_rest_area_hover_hint() -> void:
	hide_rest_area_zone_hint_labels()
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.text = ""
	rest_area_hover_hint_label.visible = false
	rest_area_hover_hint_use_world_anchor = false

func layout_rest_area_hover_hint(viewport_size: Vector2) -> void:
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.size = REST_HINT_SIZE
	var target := Vector2((viewport_size.x - rest_area_hover_hint_label.size.x) * 0.5, REST_HINT_TOP_MARGIN)
	var max_x := maxf(0.0, viewport_size.x - rest_area_hover_hint_label.size.x - 8.0)
	var max_y := maxf(0.0, viewport_size.y - rest_area_hover_hint_label.size.y - 8.0)
	rest_area_hover_hint_label.position = Vector2(
		clampf(target.x, 8.0, max_x),
		clampf(target.y, 8.0, max_y)
	)

func _build_rest_area_hint_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.90)
	style.border_color = Color(0.32, 0.48, 0.62, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 5
	return style

func update_rest_area_hover_hint_position() -> void:
	if owner_ui == null:
		return
	var viewport := owner_ui.get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if rest_area_hover_hint_label and rest_area_hover_hint_label.visible and rest_area_hover_hint_use_world_anchor:
		var screen_pos := viewport.get_canvas_transform() * rest_area_hover_hint_anchor_world
		var pos := Vector2(
			screen_pos.x - rest_area_hover_hint_label.size.x * 0.5,
			screen_pos.y - rest_area_hover_hint_label.size.y * 0.5
		)
		var max_x := maxf(0.0, viewport_size.x - rest_area_hover_hint_label.size.x - 8.0)
		var max_y := maxf(0.0, viewport_size.y - rest_area_hover_hint_label.size.y - 8.0)
		rest_area_hover_hint_label.position = Vector2(
			clampf(pos.x, 8.0, max_x),
			clampf(pos.y, 8.0, max_y)
		)
	for idx in range(rest_area_zone_hint_labels.size()):
		if idx >= rest_area_zone_hint_anchors.size():
			continue
		var label := rest_area_zone_hint_labels[idx]
		if label == null or not label.visible:
			continue
		var screen_pos := viewport.get_canvas_transform() * rest_area_zone_hint_anchors[idx]
		label.position = Vector2(
			screen_pos.x - label.size.x * 0.5,
			screen_pos.y - label.size.y * 0.5
		)

func layout_quest_hint(viewport_size: Vector2) -> void:
	if quest_hint_label == null:
		return
	var width := minf(520.0, viewport_size.x - HUD_MARGIN * 2.0)
	quest_hint_label.size = Vector2(maxf(width, 0.0), 36.0)
	quest_hint_label.position = Vector2((viewport_size.x - quest_hint_label.size.x) * 0.5, HUD_MARGIN + 84.0)

func set_quest_hint(text: String) -> void:
	ensure_quest_hint()
	quest_hint_label.text = text
	quest_hint_label.visible = text.strip_edges() != ""
