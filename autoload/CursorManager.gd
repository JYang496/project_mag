extends Node

const STATE_DEFAULT := 0
const STATE_CLICKABLE := 1
const STATE_HOLD_ACTIVE := 2
const STATE_TEXT := 3

const _WORLD_PRIORITY_DEFAULT := 50
const _STATE_RANK := {
	STATE_DEFAULT: 0,
	STATE_CLICKABLE: 1,
	STATE_HOLD_ACTIVE: 3
}
const _CURSOR_SHAPE_BY_STATE := {
	STATE_DEFAULT: Input.CURSOR_ARROW,
	STATE_CLICKABLE: Input.CURSOR_POINTING_HAND,
	STATE_HOLD_ACTIVE: Input.CURSOR_WAIT,
	STATE_TEXT: Input.CURSOR_IBEAM
}

var _world_states: Dictionary = {}
var _control_rules: Dictionary = {}
var _active_state: int = STATE_DEFAULT
var _active_shape: int = Input.CURSOR_ARROW
var _hover_shape_control: Control
var _hover_shape_original: int = Input.CURSOR_ARROW

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	force_refresh()

func _process(_delta: float) -> void:
	_refresh_if_needed()

func set_world_state(owner: Object, state: int, priority: int = _WORLD_PRIORITY_DEFAULT) -> void:
	if owner == null:
		return
	if state == STATE_DEFAULT:
		clear_world_state(owner)
		return
	_world_states[owner] = {
		"state": state,
		"priority": priority
	}
	_refresh_if_needed()

func clear_world_state(owner: Object) -> void:
	if owner == null:
		return
	if _world_states.has(owner):
		_world_states.erase(owner)
		_refresh_if_needed()

func register_control_rule(control: Control, can_click: Callable, priority: int = 100) -> void:
	if control == null or not is_instance_valid(control):
		return
	_control_rules[control] = {
		"can_click": can_click,
		"priority": priority
	}
	_refresh_if_needed()

func unregister_control_rule(control: Control) -> void:
	if control == null:
		return
	if _control_rules.has(control):
		_control_rules.erase(control)
		_refresh_if_needed()

func force_refresh() -> void:
	_refresh_if_needed(true)

func _refresh_if_needed(force: bool = false) -> void:
	_cleanup_invalid_entries()
	var hovered := _get_hovered_control()
	var world_state := _resolve_world_state()
	var target_state := _resolve_target_state(hovered, world_state)
	var ui_shape_target := _resolve_ui_shape_target_control(hovered, target_state, world_state)
	var ui_shape := _resolve_ui_shape_for_state(target_state)
	_apply_hover_control_shape(ui_shape_target, ui_shape)
	if not force and target_state == _active_state:
		return
	_apply_state(target_state)

func _apply_state(state: int) -> void:
	_active_state = state
	var shape: int = _CURSOR_SHAPE_BY_STATE.get(state, Input.CURSOR_ARROW)
	if shape == _active_shape:
		return
	_active_shape = shape
	Input.set_default_cursor_shape(shape)

func _resolve_target_state(hovered: Control, world_state: int) -> int:
	if world_state == STATE_HOLD_ACTIVE:
		return STATE_HOLD_ACTIVE
	if _is_text_edit_hovered(hovered):
		return STATE_TEXT
	if _is_ui_clickable(hovered):
		return STATE_CLICKABLE
	if world_state == STATE_CLICKABLE and not _is_ui_hover_blocking_world(hovered):
		return STATE_CLICKABLE
	return STATE_DEFAULT

func _resolve_world_state() -> int:
	var best_state := STATE_DEFAULT
	var best_rank := -1
	var best_priority := -2147483648
	for value in _world_states.values():
		var state := int(value.get("state", STATE_DEFAULT))
		var rank := int(_STATE_RANK.get(state, 0))
		var priority := int(value.get("priority", _WORLD_PRIORITY_DEFAULT))
		if rank > best_rank:
			best_rank = rank
			best_priority = priority
			best_state = state
			continue
		if rank == best_rank and priority > best_priority:
			best_priority = priority
			best_state = state
	return best_state

func _is_ui_clickable(hovered: Control) -> bool:
	return _resolve_ui_clickable_target_control(hovered) != null

func _find_best_rule_for_hovered(hovered: Control) -> Dictionary:
	return _find_best_rule_entry_for_hovered(hovered).get("rule", {})

func _find_best_rule_entry_for_hovered(hovered: Control) -> Dictionary:
	var current: Node = hovered
	var best_entry: Dictionary = {}
	var best_priority := -2147483648
	while current != null:
		if current is Control and _control_rules.has(current):
			var rule: Dictionary = _control_rules[current]
			var priority := int(rule.get("priority", 100))
			if best_entry.is_empty() or priority > best_priority:
				best_entry = {
					"control": current,
					"rule": rule
				}
				best_priority = priority
		current = current.get_parent()
	return best_entry

func _is_actionable_base_button(hovered: Control) -> bool:
	return _find_actionable_base_button(hovered) != null

func _find_actionable_base_button(hovered: Control) -> BaseButton:
	var current: Node = hovered
	while current != null:
		if current is BaseButton:
			var button := current as BaseButton
			if button.visible and button.is_visible_in_tree() and not button.disabled:
				return button
			return null
		current = current.get_parent()
	return null

func _is_text_edit_hovered(hovered: Control) -> bool:
	if hovered == null:
		return false
	var current: Node = hovered
	while current != null:
		if current is LineEdit:
			return (current as LineEdit).editable
		if current is TextEdit:
			return (current as TextEdit).editable
		current = current.get_parent()
	return false

func _is_ui_hover_blocking_world(hovered: Control) -> bool:
	if hovered == null or not hovered.is_visible_in_tree():
		return false
	if _is_text_edit_hovered(hovered):
		return true
	if _is_actionable_base_button(hovered):
		return true
	var entry := _find_best_rule_entry_for_hovered(hovered)
	if entry.is_empty():
		return false
	return _evaluate_rule_clickable(entry.get("rule", {}))

func _get_hovered_control() -> Control:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var hovered := viewport.gui_get_hovered_control()
	if hovered == null or not hovered.is_visible_in_tree():
		return null
	return hovered

func _cleanup_invalid_entries() -> void:
	var invalid_world: Array = []
	for owner in _world_states.keys():
		if not is_instance_valid(owner):
			invalid_world.append(owner)
	for owner in invalid_world:
		_world_states.erase(owner)
	var invalid_rules: Array = []
	for control in _control_rules.keys():
		if not is_instance_valid(control):
			invalid_rules.append(control)
	for control in invalid_rules:
		_control_rules.erase(control)
	if _hover_shape_control != null and not is_instance_valid(_hover_shape_control):
		_hover_shape_control = null

func _resolve_ui_clickable_target_control(hovered: Control) -> Control:
	if hovered == null:
		return null
	var button := _find_actionable_base_button(hovered)
	if button != null:
		return button
	var entry := _find_best_rule_entry_for_hovered(hovered)
	if entry.is_empty():
		return null
	var rule: Dictionary = entry.get("rule", {})
	if not _evaluate_rule_clickable(rule):
		return null
	var control: Variant = entry.get("control", null)
	if control is Control:
		return control as Control
	return null

func _evaluate_rule_clickable(rule: Dictionary) -> bool:
	if rule.is_empty():
		return false
	var can_click: Callable = rule.get("can_click", Callable())
	if not can_click.is_valid():
		return false
	var result: Variant = can_click.call()
	return result is bool and result

func _resolve_ui_shape_for_state(state: int) -> int:
	if state == STATE_TEXT:
		return Input.CURSOR_IBEAM
	if state == STATE_CLICKABLE:
		return Input.CURSOR_POINTING_HAND
	return -1

func _resolve_ui_shape_target_control(hovered: Control, state: int, world_state: int) -> Control:
	if hovered == null:
		return null
	if state == STATE_TEXT:
		var current: Node = hovered
		while current != null:
			if current is LineEdit:
				return current as Control
			if current is TextEdit:
				return current as Control
			current = current.get_parent()
		return null
	if state == STATE_CLICKABLE:
		var clickable_control := _resolve_ui_clickable_target_control(hovered)
		if clickable_control != null:
			return clickable_control
		# World clickable may sit under a full-screen HUD Control that keeps arrow cursor.
		# In that case, temporarily override the hovered control's cursor shape.
		if world_state == STATE_CLICKABLE and not _is_ui_hover_blocking_world(hovered):
			return hovered
	return null

func _apply_hover_control_shape(target: Control, shape: int) -> void:
	if target == null or shape < 0:
		_restore_hover_control_shape()
		return
	if _hover_shape_control != null and _hover_shape_control != target:
		_restore_hover_control_shape()
	if _hover_shape_control == null:
		_hover_shape_control = target
		_hover_shape_original = target.mouse_default_cursor_shape
	target.mouse_default_cursor_shape = shape

func _restore_hover_control_shape() -> void:
	if _hover_shape_control == null:
		return
	if is_instance_valid(_hover_shape_control):
		_hover_shape_control.mouse_default_cursor_shape = _hover_shape_original
	_hover_shape_control = null
