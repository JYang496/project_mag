extends RefCounted
class_name HintPresenter

const HUD_MARGIN := 16.0
const REST_HINT_SIZE := Vector2(460, 108)
const REST_HINT_OFFSET := Vector2(12, 212)
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
	rest_area_hover_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rest_area_hover_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rest_area_hover_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_area_hover_hint_label.add_theme_font_size_override("font_size", 15)
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
	rest_area_hover_hint_label.text = text
	rest_area_hover_hint_label.visible = text.strip_edges() != ""
	rest_area_hover_hint_anchor_world = world_pos
	rest_area_hover_hint_use_world_anchor = rest_area_hover_hint_label.visible
	update_rest_area_hover_hint_position()

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
	var target := REST_HINT_OFFSET
	var max_x := maxf(0.0, viewport_size.x - rest_area_hover_hint_label.size.x - 8.0)
	var max_y := maxf(0.0, viewport_size.y - rest_area_hover_hint_label.size.y - 8.0)
	rest_area_hover_hint_label.position = Vector2(
		clampf(target.x, 8.0, max_x),
		clampf(target.y, 8.0, max_y)
	)

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
			screen_pos.y - rest_area_hover_hint_label.size.y - 10.0
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
