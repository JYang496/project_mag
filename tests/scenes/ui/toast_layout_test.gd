extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TOAST_PRESENTER_SCRIPT := preload("res://UI/scripts/components/toast_presenter.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false
var _ui: UI


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	await _assert_toast_size("Contract reward: 2 gold")
	await _assert_toast_size(
		"A deliberately long toast message that must stay on one line and be trimmed instead of stretching its panel vertically."
	)

	var presenter = _ui.toast_presenter
	var label := presenter.label as Label
	_assert_true(label.autowrap_mode == TextServer.AUTOWRAP_OFF, "Toast text should not wrap.")
	_assert_true(label.clip_text, "Toast text should clip instead of increasing minimum width.")
	_assert_true(label.max_lines_visible == 1, "Toast text should remain limited to one line.")

	print("FAIL: toast layout" if _failed else "PASS: toast layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)


func _assert_toast_size(message: String) -> void:
	_ui.show_item_message(message, 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _ui.toast_presenter.panel as PanelContainer
	_assert_true(
		is_equal_approx(panel.size.x, TOAST_PRESENTER_SCRIPT.MAX_WIDTH),
		"Toast width should remain at its 440px desktop target."
	)
	_assert_true(
		is_equal_approx(panel.size.y, TOAST_PRESENTER_SCRIPT.HEIGHT),
		"Toast content should not inflate its 44px target height."
	)


func _reset_runtime_state() -> void:
	_ui = null


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
