extends Control
class_name RouteSelectionPanel

signal route_confirmed(route_id: String)
signal selection_cancelled

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: VBoxContainer = $Panel/VBox/Options
@onready var confirm_button: Button = $Panel/VBox/Footer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Footer/CancelButton

var _selected_route_id: String = ""
var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()
var _route_defs_cache: Array[RunRouteDefinition] = []
var _default_route_id_cache: String = ""
var _default_route_def: RunRouteDefinition

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_action_button_style(confirm_button, true)
	_apply_action_button_style(cancel_button, false)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func open_for_routes(
	route_defs: Array[RunRouteDefinition],
	default_route_id: String,
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if route_defs.is_empty():
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_route_defs_cache = route_defs.duplicate()
	_default_route_id_cache = default_route_id
	_selected_route_id = ""
	title_label.text = LocalizationManager.tr_key("ui.route.title", "Choose Route")
	subtitle_label.text = LocalizationManager.tr_key("ui.route.subtitle", "Select one route for this level.")
	confirm_button.text = LocalizationManager.tr_key("ui.route.confirm", "Confirm Route")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	for child in options_box.get_children():
		child.queue_free()
	_default_route_def = _find_route_def(route_defs, default_route_id)
	for route_def in route_defs:
		if route_def == null:
			continue
		var button := _build_route_card(route_def)
		button.pressed.connect(Callable(self, "_on_route_button_pressed").bind(route_def.route_id, button))
		options_box.add_child(button)
		if _selected_route_id == "" and route_def.route_id == default_route_id:
			_on_route_button_pressed(route_def.route_id, button)
	if _selected_route_id == "" and options_box.get_child_count() > 0:
		var first_button := options_box.get_child(0) as Button
		if first_button:
			var first_route_id := str(first_button.get_meta("route_id", ""))
			if first_route_id != "":
				_on_route_button_pressed(first_route_id, first_button)
	_confirm_button_state()
	visible = true
	return true

func close_panel() -> void:
	visible = false
	_selected_route_id = ""
	_on_confirm = Callable()
	_on_cancel = Callable()

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return true

func cancel_visible_modal() -> bool:
	if not is_modal_open() or not can_cancel_modal():
		return false
	_on_cancel_pressed()
	return true

func _on_route_button_pressed(route_id: String, source_button: Button) -> void:
	_selected_route_id = route_id
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button == source_button
		button.button_pressed = selected
		var route_def := button.get_meta("route_def", null) as RunRouteDefinition
		if route_def != null:
			_apply_route_card_style(button, route_def, selected)
	_confirm_button_state()

func _confirm_button_state() -> void:
	confirm_button.disabled = _selected_route_id == ""

func _on_confirm_pressed() -> void:
	if _selected_route_id == "":
		return
	route_confirmed.emit(_selected_route_id)
	if _on_confirm.is_valid():
		_on_confirm.call_deferred(_selected_route_id)
	close_panel()

func _on_cancel_pressed() -> void:
	selection_cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call_deferred()
	close_panel()

func _on_language_changed(_locale: String) -> void:
	if visible:
		open_for_routes(_route_defs_cache, _default_route_id_cache, _on_confirm, _on_cancel)

func _build_route_card(route_def: RunRouteDefinition) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 108)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = LocalizationManager.get_route_description(route_def)
	button.set_meta("route_id", route_def.route_id)
	button.set_meta("route_def", route_def)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	row.add_child(_make_route_icon(route_def))

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	row.add_child(body)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var title := _make_label(LocalizationManager.get_route_display_name(route_def), 16, Color(0.94, 0.97, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_identity_badge(_get_route_identity(route_def), route_def))

	var description := _make_label(LocalizationManager.get_route_description(route_def), 11, Color(0.72, 0.82, 0.88, 1.0))
	description.clip_text = true
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(description)

	var metrics := HBoxContainer.new()
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_constant_override("separation", 6)
	body.add_child(metrics)
	for metric in _build_route_metrics(route_def):
		metrics.add_child(_make_metric_badge(metric))
	_apply_route_card_style(button, route_def, false)
	return button

func _find_route_def(route_defs: Array[RunRouteDefinition], route_id: String) -> RunRouteDefinition:
	for route_def in route_defs:
		if route_def != null and route_def.route_id == route_id:
			return route_def
	return null

func _make_route_icon(route_def: RunRouteDefinition) -> PanelContainer:
	var identity := _get_route_identity(route_def)
	var color := _route_color(route_def)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(58, 58)
	panel.add_theme_stylebox_override("panel", _make_badge_style(color, 0.18, 0.78, 8))
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _route_icon_text(identity)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	panel.add_child(label)
	return panel

func _make_identity_badge(identity: String, route_def: RunRouteDefinition) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(96, 24)
	panel.add_theme_stylebox_override("panel", _make_badge_style(_route_color(route_def), 0.16, 0.72, 5))
	var label := _make_label(identity, 11, Color(0.9, 0.96, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _build_route_metrics(route_def: RunRouteDefinition) -> Array[Dictionary]:
	return [
		{"label": "HP", "value": "x%.2f" % route_def.enemy_hp_multiplier, "delta": _delta(route_def.enemy_hp_multiplier, _baseline_hp()), "benefit": false},
		{"label": "DMG", "value": "x%.2f" % route_def.enemy_damage_multiplier, "delta": _delta(route_def.enemy_damage_multiplier, _baseline_damage()), "benefit": false},
		{"label": "TIME", "value": "x%.2f" % route_def.battle_timeout_multiplier, "delta": _delta(_baseline_timeout(), route_def.battle_timeout_multiplier), "benefit": false},
		{"label": "RWD", "value": _reward_metric_text(route_def), "delta": _reward_delta(route_def), "benefit": true},
	]

func _make_metric_badge(metric: Dictionary) -> PanelContainer:
	var delta := float(metric.get("delta", 0.0))
	var benefit := bool(metric.get("benefit", false))
	var color := Color(0.48, 0.62, 0.72, 1.0)
	if benefit and delta > 0.05:
		color = Color(0.38, 0.82, 0.56, 1.0)
	elif benefit and delta < -0.05:
		color = Color(0.92, 0.48, 0.28, 1.0)
	elif delta > 0.05:
		color = Color(0.92, 0.48, 0.28, 1.0)
	elif delta < -0.05:
		color = Color(0.38, 0.82, 0.56, 1.0)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(78, 24)
	panel.add_theme_stylebox_override("panel", _make_badge_style(color, 0.13, 0.58, 4))
	var label := _make_label("%s %s" % [str(metric.get("label", "")), str(metric.get("value", ""))], 10, Color(0.88, 0.94, 0.98, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_badge_style(color: Color, bg_alpha: float, border_alpha: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, bg_alpha)
	style.border_color = Color(color.r, color.g, color.b, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _apply_route_card_style(button: Button, route_def: RunRouteDefinition, selected: bool) -> void:
	_apply_route_card_style_with_color(button, _route_color(route_def), selected)

func _apply_route_card_style_with_color(button: Button, color: Color, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color.r, color.g, color.b, 0.10)
		if selected:
			style.bg_color = Color(color.r, color.g, color.b, 0.18)
		elif state == "hover" or state == "focus":
			style.bg_color = Color(color.r, color.g, color.b, 0.14)
		elif state == "pressed":
			style.bg_color = Color(color.r, color.g, color.b, 0.16)
		style.border_color = color
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)

func _apply_action_button_style(button: Button, primary: bool) -> void:
	var color := Color(0.42, 0.78, 0.92, 1.0) if primary else Color(0.56, 0.64, 0.70, 1.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var state_color := color
		style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.15 if primary else 0.10)
		if state == "hover" or state == "focus":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.22 if primary else 0.16)
		elif state == "pressed":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.28 if primary else 0.20)
		elif state == "disabled":
			state_color = Color(0.40, 0.46, 0.50, 1.0)
			style.bg_color = Color(0.10, 0.12, 0.14, 0.64)
		style.border_color = Color(state_color.r, state_color.g, state_color.b, 0.78)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.94, 0.98, 1.0, 1.0))

func _get_route_identity(route_def: RunRouteDefinition) -> String:
	if not route_def.battle_enabled:
		return "No Combat"
	if route_def.enemy_hp_multiplier > 1.1 or route_def.enemy_damage_multiplier > 1.1 or route_def.battle_timeout_multiplier < 0.95:
		return "High Risk"
	return "Standard"

func _route_icon_text(identity: String) -> String:
	match identity:
		"High Risk":
			return "!"
		"No Combat":
			return "+"
		_:
			return ">"

func _route_color(route_def: RunRouteDefinition) -> Color:
	if not route_def.battle_enabled:
		return Color(0.38, 0.78, 0.56, 1.0)
	if route_def.enemy_hp_multiplier > 1.1 or route_def.enemy_damage_multiplier > 1.1:
		return Color(0.94, 0.48, 0.28, 1.0)
	return Color(0.46, 0.68, 0.92, 1.0)

func _baseline_hp() -> float:
	return _default_route_def.enemy_hp_multiplier if _default_route_def != null else 1.0

func _baseline_damage() -> float:
	return _default_route_def.enemy_damage_multiplier if _default_route_def != null else 1.0

func _baseline_timeout() -> float:
	return _default_route_def.battle_timeout_multiplier if _default_route_def != null else 1.0

func _delta(value: float, baseline: float) -> float:
	return value - baseline

func _reward_delta(route_def: RunRouteDefinition) -> float:
	if _default_route_def == null:
		return 0.0
	return float(route_def.reward_item_level_bonus + route_def.reward_module_level_bonus) - float(_default_route_def.reward_item_level_bonus + _default_route_def.reward_module_level_bonus)

func _reward_metric_text(route_def: RunRouteDefinition) -> String:
	var level_bonus := maxi(int(route_def.reward_item_level_bonus), int(route_def.reward_module_level_bonus))
	if level_bonus > 0:
		return "+Lv%d" % level_bonus
	return "%d opt" % int(route_def.reward_option_count)
