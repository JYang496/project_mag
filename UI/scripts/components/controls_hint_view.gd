extends PanelContainer
class_name ControlsHintView

signal display_state_changed(state: int)

enum DisplayState {
	EXPANDED,
	COMPACT,
	HIDDEN,
	CONTEXT_REMINDER,
}

const PANEL_WIDTH := 360.0
const FALLBACK_MARGIN := 16.0
const TWO_COLUMN_MIN_WIDTH := 420.0
const KEYCAP_WIDTH := 64.0
const COMPACT_EXPAND_WIDTH := 72.0
const AUTO_COLLAPSE_SECONDS := 8.0
const CONTEXT_DURATION_SECONDS := 3.0
const CONTEXT_COOLDOWN_SECONDS := 15.0
const MAX_CONTEXT_REPEATS := 2

@onready var content: VBoxContainer = $Margin/Content
@onready var header: HBoxContainer = $Margin/Content/Header
@onready var title_label: Label = $Margin/Content/Header/Title
@onready var collapse_button: Button = $Margin/Content/Header/CollapseButton
@onready var header_divider: ColorRect = $Margin/Content/HeaderDivider
@onready var expanded_content: GridContainer = $Margin/Content/ExpandedContent
@onready var compact_content: HBoxContainer = $Margin/Content/CompactContent
@onready var compact_text: Label = $Margin/Content/CompactContent/CompactText
@onready var compact_expand: Label = $Margin/Content/CompactContent/CompactExpand
@onready var context_content: HBoxContainer = $Margin/Content/ContextContent
@onready var context_key: Label = $Margin/Content/ContextContent/ContextKey
@onready var context_message: Label = $Margin/Content/ContextContent/ContextMessage

var display_state: DisplayState = DisplayState.EXPANDED
var _current_phase: String = ""
var _primary_menu_open := false
var _secondary_menu_context: StringName = &""
var _auto_collapse_remaining := AUTO_COLLAPSE_SECONDS
var _used_move := false
var _used_attack := false
var _manual_expanded := false
var _context_remaining := 0.0
var _context_previous_state: DisplayState = DisplayState.COMPACT
var _context_last_shown_msec: Dictionary = {}
var _context_show_counts: Dictionary = {}
var _action_items: Dictionary = {}
var _render_signature := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_FILL
	add_theme_stylebox_override("panel", _build_panel_style())
	_configure_text_constraints()
	_configure_visual_hierarchy()
	collapse_button.pressed.connect(toggle_expanded)
	_build_action_items()
	_connect_settings_signal()
	refresh_input_glyphs()
	_apply_saved_mode(false)

func layout_for_viewport(viewport_size: Vector2) -> void:
	var available_width := maxf(1.0, viewport_size.x - 2.0 * FALLBACK_MARGIN)
	var target_width := minf(PANEL_WIDTH, available_width)
	custom_minimum_size.x = target_width
	expanded_content.columns = 2 if target_width >= TWO_COLUMN_MIN_WIDTH else 1
	if get_parent() is Container:
		return
	size.x = target_width
	position = Vector2(viewport_size.x - size.x - FALLBACK_MARGIN, FALLBACK_MARGIN)

func refresh_for_phase(phase: String, primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	var phase_changed := _current_phase != phase
	_current_phase = phase
	_primary_menu_open = primary_menu_open
	_secondary_menu_context = _normalize_secondary_menu_context(secondary_menu_context)
	if phase_changed and phase == PhaseManager.BATTLE:
		_begin_battle_guidance()
	_render_current_context()

func refresh_visibility(primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	var next_phase := PhaseManager.current_state()
	var signature := "%s|%s|%s|%s|%s" % [
		next_phase,
		str(primary_menu_open),
		str(secondary_menu_context),
		str(get_tree().paused),
		str(PlayerAssistSettings.controls_hint_mode),
	]
	if signature == _render_signature:
		return
	_render_signature = signature
	refresh_for_phase(next_phase, primary_menu_open, secondary_menu_context)

func tick(delta: float) -> void:
	if _current_phase != PhaseManager.BATTLE or get_tree().paused:
		return
	if display_state == DisplayState.CONTEXT_REMINDER:
		_context_remaining -= maxf(delta, 0.0)
		if _context_remaining <= 0.0:
			set_display_state(_context_previous_state, false)
		return
	if display_state != DisplayState.EXPANDED:
		return
	if _manual_expanded:
		return
	if PlayerAssistSettings.controls_hint_mode != PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE:
		return
	_auto_collapse_remaining -= maxf(delta, 0.0)
	if _auto_collapse_remaining <= 0.0 or (_used_move and _used_attack):
		set_display_state(DisplayState.COMPACT)

func handle_input_event(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("TOGGLE_CONTROLS"):
		toggle_expanded()
		return true
	if _current_phase == PhaseManager.BATTLE:
		if event.is_action_pressed("UP") or event.is_action_pressed("DOWN") \
				or event.is_action_pressed("LEFT") or event.is_action_pressed("RIGHT"):
			_used_move = true
		if event.is_action_pressed("ATTACK"):
			_used_attack = true
	return false

func toggle_expanded() -> void:
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		PlayerAssistSettings.set_controls_hint_mode(PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE)
		_manual_expanded = true
		set_display_state(DisplayState.EXPANDED, false)
		return
	if display_state == DisplayState.EXPANDED:
		_manual_expanded = false
		set_display_state(DisplayState.COMPACT, false)
	else:
		_manual_expanded = true
		set_display_state(DisplayState.EXPANDED, false)

func set_display_state(next_state: DisplayState, persist_manual_choice: bool = true) -> void:
	if next_state == DisplayState.HIDDEN:
		visible = false
		display_state = next_state
		if persist_manual_choice:
			PlayerAssistSettings.set_controls_hint_mode(PlayerAssistSettings.CONTROLS_HINT_HIDDEN)
		display_state_changed.emit(display_state)
		return
	display_state = next_state
	if persist_manual_choice and next_state == DisplayState.EXPANDED:
		PlayerAssistSettings.set_controls_hint_mode(PlayerAssistSettings.CONTROLS_HINT_ALWAYS)
	visible = _should_be_visible()
	header.visible = next_state == DisplayState.EXPANDED
	header_divider.visible = next_state == DisplayState.EXPANDED
	expanded_content.visible = next_state == DisplayState.EXPANDED
	compact_content.visible = next_state == DisplayState.COMPACT
	context_content.visible = next_state == DisplayState.CONTEXT_REMINDER
	collapse_button.text = "%s −" % _tr("ui.controls.collapse", "Collapse")
	display_state_changed.emit(display_state)

func show_context_reminder(action: StringName, message: String, force: bool = false) -> bool:
	if _current_phase != PhaseManager.BATTLE or PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		return false
	var now_msec := Time.get_ticks_msec()
	var last_shown := int(_context_last_shown_msec.get(action, -1000000))
	var shown_count := int(_context_show_counts.get(action, 0))
	if not force:
		if shown_count >= MAX_CONTEXT_REPEATS:
			return false
		if now_msec - last_shown < int(CONTEXT_COOLDOWN_SECONDS * 1000.0):
			return false
	_context_last_shown_msec[action] = now_msec
	_context_show_counts[action] = shown_count + 1
	_context_previous_state = display_state if display_state != DisplayState.CONTEXT_REMINDER else DisplayState.COMPACT
	context_key.text = _keycap_text(_input_label(action))
	context_message.text = message
	_context_remaining = CONTEXT_DURATION_SECONDS
	set_display_state(DisplayState.CONTEXT_REMINDER, false)
	return true

func dismiss_context_reminder() -> void:
	if display_state == DisplayState.CONTEXT_REMINDER:
		set_display_state(_context_previous_state, false)

func refresh_input_glyphs() -> void:
	if not is_node_ready():
		return
	var move_label := _movement_input_label()
	_set_action_item(&"move", move_label, _tr("ui.controls.move", "Move"))
	_set_action_item(&"attack", _input_label(&"ATTACK"), _tr("ui.controls.attack", "Attack"))
	_set_action_item(&"skill", _input_label(&"SKILL_PLAYER"), _tr("ui.controls.skill", "Player Skill"))
	var reload_action := _tr("ui.controls.reload", "Reload")
	if PlayerAssistSettings.auto_reload_switch:
		reload_action = _tr("ui.controls.auto_reload", "Auto Reload On")
	_set_action_item(&"reload", _input_label(&"SKILL_WEAPON"), reload_action)
	_set_action_item(
		&"switch",
		"%s / %s" % [_input_label(&"SWITCH_LEFT"), _input_label(&"SWITCH_RIGHT")],
		_tr("ui.controls.switch_weapon", "Switch Weapon")
	)
	_set_action_item(&"pause", _input_label(&"ESC"), _tr("ui.controls.pause", "Pause"))
	compact_text.text = "%s %s · %s %s" % [
		move_label,
		_tr("ui.controls.move", "Move"),
		_input_label(&"ATTACK"),
		_tr("ui.controls.attack", "Attack"),
	]
	compact_expand.text = "%s %s" % [
		_input_label(&"TOGGLE_CONTROLS"),
		_tr("ui.controls.expand", "Expand"),
	]
	title_label.text = _tr("ui.controls.title", "Controls")
	collapse_button.text = "%s −" % _tr("ui.controls.collapse", "Collapse")
	collapse_button.tooltip_text = _tr("ui.controls.collapse_tooltip", "Collapse controls hint (F1)")

func _begin_battle_guidance() -> void:
	_auto_collapse_remaining = AUTO_COLLAPSE_SECONDS
	_used_move = false
	_used_attack = false
	_manual_expanded = false
	_context_show_counts.clear()
	_context_last_shown_msec.clear()
	_apply_saved_mode(false)

func _apply_saved_mode(emit_change: bool = true) -> void:
	var mode: StringName = PlayerAssistSettings.controls_hint_mode
	if mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		set_display_state(DisplayState.HIDDEN, false)
	elif mode == PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
		set_display_state(DisplayState.EXPANDED, false)
	elif _current_phase == PhaseManager.BATTLE:
		set_display_state(DisplayState.EXPANDED, false)
	else:
		set_display_state(DisplayState.COMPACT, false)
	if not emit_change:
		return
	display_state_changed.emit(display_state)

func _render_current_context() -> void:
	if not is_node_ready():
		return
	refresh_input_glyphs()
	if not _should_be_visible():
		visible = false
		return
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		visible = false
		return
	visible = true
	if _secondary_menu_context != &"":
		_render_secondary_menu_hint(_secondary_menu_context)
		return
	if _primary_menu_open:
		_render_text_context(
			_tr("ui.tutorial.state.primary_menu", "Primary Menu"),
			[
				_tr("ui.tutorial.panel.primary_menu.line1", "[LMB] Click buttons"),
				_tr("ui.tutorial.panel.primary_menu.line2", "[RMB] Exit current menu"),
			]
		)
		return
	if _current_phase == PhaseManager.BATTLE:
		if display_state == DisplayState.HIDDEN:
			_apply_saved_mode(false)
		else:
			set_display_state(display_state, false)
		return
	_render_text_context(
		_tr("ui.tutorial.state.rest", "Rest Area"),
		[
			_tr("ui.tutorial.panel.rest.line1", "[LMB] Click menu and zones"),
			_tr("ui.tutorial.panel.rest.line2", "[LMB Hold Center] Start battle"),
			_tr("ui.tutorial.panel.rest.line3", "[Esc] Pause"),
		]
	)

func _render_secondary_menu_hint(context_name: StringName) -> void:
	var title_key := "ui.tutorial.state.secondary.%s" % context_name
	var fallback_title := str(context_name).replace("_", " ").capitalize()
	var lines: Array[String] = []
	var line_count := 3
	if context_name == &"grid_management" or context_name == &"task_management":
		line_count = 4
	for index in range(1, line_count + 1):
		var key := "ui.tutorial.panel.secondary.%s.line%d" % [context_name, index]
		var translated := LocalizationManager.tr_key(key, "")
		if translated != "":
			lines.append(translated)
	_render_text_context(LocalizationManager.tr_key(title_key, fallback_title), lines)

func _render_text_context(context_title: String, lines: Array[String]) -> void:
	title_label.text = context_title
	_clear_action_items()
	for line in lines:
		var item := _create_hint_item("", line)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expanded_content.add_child(item)
	header.visible = true
	header_divider.visible = true
	expanded_content.visible = true
	compact_content.visible = false
	context_content.visible = false
	display_state = DisplayState.EXPANDED

func _build_action_items() -> void:
	_clear_action_items()
	for action_id in [&"move", &"attack", &"skill", &"reload", &"switch", &"pause"]:
		var item := _create_hint_item("", "")
		expanded_content.add_child(item)
		_action_items[action_id] = item

func _clear_action_items() -> void:
	for child in expanded_content.get_children():
		expanded_content.remove_child(child)
		child.queue_free()
	_action_items.clear()

func _create_hint_item(key_text: String, action_text: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 7)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.custom_minimum_size.x = 0.0
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key_label := Label.new()
	key_label.name = "Key"
	key_label.custom_minimum_size = Vector2(KEYCAP_WIDTH, 26.0)
	key_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.clip_text = true
	key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.87, 1.0))
	key_label.add_theme_stylebox_override("normal", _build_keycap_style())
	key_label.text = key_text
	key_label.visible = key_text != ""
	item.add_child(key_label)
	var action_label := Label.new()
	action_label.name = "Action"
	action_label.custom_minimum_size = Vector2(0.0, 26.0)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.size_flags_vertical = Control.SIZE_FILL
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.max_lines_visible = 2
	action_label.clip_text = true
	action_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_label.add_theme_font_size_override("font_size", 15)
	action_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98, 1.0))
	action_label.text = action_text
	item.add_child(action_label)
	return item

func _set_action_item(action_id: StringName, key_text: String, action_text: String) -> void:
	var item := _action_items.get(action_id, null) as HBoxContainer
	if item == null or not is_instance_valid(item):
		_build_action_items()
		item = _action_items.get(action_id, null) as HBoxContainer
	if item == null:
		return
	var key_label := item.get_node_or_null("Key") as Label
	var action_label := item.get_node_or_null("Action") as Label
	if key_label:
		key_label.text = key_text
		key_label.visible = key_text != ""
	if action_label:
		action_label.text = action_text

func _movement_input_label() -> String:
	var labels := PackedStringArray([
		_input_label(&"UP"),
		_input_label(&"LEFT"),
		_input_label(&"DOWN"),
		_input_label(&"RIGHT"),
	])
	if labels == PackedStringArray(["W", "A", "S", "D"]):
		return "WASD"
	return "/".join(labels)

func _input_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return str(action)
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return str(action)
	return _event_label(events[0])

func _event_label(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event != null:
		var code := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		var label := OS.get_keycode_string(code)
		if label == "Space":
			return _tr("ui.controls.key.space", "Space")
		if label == "Escape":
			return "Esc"
		return _compact_key_name(label)
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return _tr("ui.controls.key.lmb", "LMB")
			MOUSE_BUTTON_RIGHT:
				return _tr("ui.controls.key.rmb", "RMB")
			MOUSE_BUTTON_MIDDLE:
				return _tr("ui.controls.key.mmb", "MMB")
			_:
				return "M%d" % mouse_event.button_index
	var joy_event := event as InputEventJoypadButton
	if joy_event != null:
		return "Pad %d" % joy_event.button_index
	return _compact_key_name(event.as_text())

func _keycap_text(text: String) -> String:
	return "[%s]" % text if text != "" else ""

func _compact_key_name(text: String) -> String:
	var compact := text.replace(" + ", "+").replace("Mouse Button", "M")
	if compact.length() > 12:
		return compact.substr(0, 11) + "…"
	return compact

func _configure_text_constraints() -> void:
	custom_minimum_size.x = PANEL_WIDTH
	title_label.custom_minimum_size.x = 0.0
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_text.custom_minimum_size.x = 0.0
	compact_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_text.clip_text = true
	compact_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_expand.custom_minimum_size.x = COMPACT_EXPAND_WIDTH
	compact_expand.size_flags_horizontal = Control.SIZE_SHRINK_END
	compact_expand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compact_expand.clip_text = true
	compact_expand.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_key.custom_minimum_size.x = KEYCAP_WIDTH
	context_key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	context_key.clip_text = true
	context_key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_message.custom_minimum_size = Vector2(0.0, 26.0)
	context_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_message.size_flags_vertical = Control.SIZE_FILL
	context_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_message.max_lines_visible = 2
	context_message.clip_text = true
	context_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _configure_visual_hierarchy() -> void:
	title_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	collapse_button.add_theme_font_size_override("font_size", 12)
	collapse_button.add_theme_color_override("font_color", Color(0.82, 0.91, 0.94, 1.0))
	collapse_button.add_theme_stylebox_override(
		"normal",
		_build_button_style(Color(0.08, 0.16, 0.20, 0.92), Color(0.28, 0.48, 0.56, 0.92))
	)
	collapse_button.add_theme_stylebox_override(
		"hover",
		_build_button_style(Color(0.12, 0.25, 0.30, 0.98), Color(0.38, 0.72, 0.82, 1.0))
	)
	collapse_button.add_theme_stylebox_override(
		"pressed",
		_build_button_style(Color(0.08, 0.20, 0.25, 1.0), Color(0.45, 0.82, 0.90, 1.0))
	)

func _should_be_visible() -> bool:
	return _current_phase != PhaseManager.GAMEOVER and not get_tree().paused

func _connect_settings_signal() -> void:
	var callback := Callable(self, "_on_assist_settings_changed")
	if not PlayerAssistSettings.settings_changed.is_connected(callback):
		PlayerAssistSettings.settings_changed.connect(callback)

func _on_assist_settings_changed() -> void:
	_render_signature = ""
	refresh_input_glyphs()
	_apply_saved_mode(false)
	_render_current_context()

func _tr(key: String, fallback: String) -> String:
	return LocalizationManager.tr_key(key, fallback)

func _normalize_secondary_menu_context(context_name: StringName) -> StringName:
	match context_name:
		&"purchase", &"upgrade", &"warehouse", &"grid_management", &"task_management":
			return context_name
		&"shop":
			return &"purchase"
		&"grid":
			return &"grid_management"
		&"task":
			return &"task_management"
		_:
			return &""

func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.063, 0.094, 0.88)
	style.border_color = Color(0.28, 0.50, 0.58, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _build_keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.20, 0.23, 0.96)
	style.border_color = Color(0.33, 0.40, 0.44, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	return style

func _build_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	return style
