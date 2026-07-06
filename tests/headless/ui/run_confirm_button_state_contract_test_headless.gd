extends SceneTree

const ROUTE_PANEL_PATH := "res://UI/scripts/route_selection_panel.gd"
const REWARD_PANEL_PATH := "res://UI/scripts/reward_selection_panel.gd"
const MODAL_CONTROLLER_PATH := "res://UI/scripts/components/modal_dialog_controller.gd"

var _failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_route_panel()
	_check_reward_panel()
	_check_modal_controller()
	if _failures.is_empty():
		print("PASS confirm button state contract")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL confirm button state contract")
	quit(1)

func _check_route_panel() -> void:
	var source := _read_source(ROUTE_PANEL_PATH)
	_expect(source.contains("_apply_route_card_style_with_color"), "route cards use explicit selected-state style")
	_expect(source.contains("style.set_border_width_all(2 if selected else 1)"), "selected route cards keep a 2px border")
	_expect(source.contains("_apply_action_button_style(confirm_button, true)"), "route confirm button has explicit state style")

func _check_reward_panel() -> void:
	var source := _read_source(REWARD_PANEL_PATH)
	_expect(source.contains("_apply_action_button_style(confirm_button, true)"), "reward confirm button has explicit state style")
	_expect(source.contains("font_pressed_color"), "reward action button pressed font color is explicit")
	_expect(source.contains("font_focus_color"), "reward action button focus font color is explicit")

func _check_modal_controller() -> void:
	var source := _read_source(MODAL_CONTROLLER_PATH)
	_expect(source.contains("_apply_dialog_button_style(ok_button, true, destructive)"), "modal ok button has explicit state style")
	_expect(source.contains("font_pressed_color"), "modal ok pressed font color is explicit")
	_expect(source.contains("font_focus_color"), "modal ok focus font color is explicit")

func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("cannot read %s" % path)
		return ""
	return file.get_as_text()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
