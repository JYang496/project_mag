extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var left_stack := ui.left_contract_hud_stack
	var right_stack := ui.right_hud_stack
	var presenter = ui.battle_contract_hud_presenter
	var panel := presenter.panel as PanelContainer
	_assert_true(left_stack != null, "Contract HUD should create a dedicated left stack.")
	_assert_true(right_stack != null, "Right HUD stack should remain available for non-contract UI.")
	_assert_true(panel != null and panel.get_parent() == left_stack,
		"Contract HUD should belong to the left stack.")
	_assert_near(Vector2(16.0, 16.0), left_stack.position,
		"Contract stack should keep the confirmed top-left margin.")
	_assert_near(Vector2(16.0, 16.0), presenter.call("_hud_target_position", Vector2(1280.0, 720.0)),
		"Contract intro collapse should target the same top-left position.")
	_assert_true(not panel.visible, "Inactive contract HUD should be fully hidden.")
	_assert_true(right_stack.get_node_or_null("BattleContractHud") == null,
		"Right HUD stack should no longer contain the contract HUD.")

	var before := _visible_control_positions(right_stack)
	panel.visible = true
	await get_tree().process_frame
	var after_show := _visible_control_positions(right_stack)
	panel.visible = false
	await get_tree().process_frame
	var after_hide := _visible_control_positions(right_stack)
	_assert_true(before == after_show and before == after_hide,
		"Showing or hiding the contract must not reflow right-side UI.")

	print("FAIL: battle contract HUD layout" if _failed else "PASS: battle contract HUD layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _visible_control_positions(root: Control) -> Dictionary:
	var result := {}
	for child in root.get_children():
		var control := child as Control
		if control != null and control.visible:
			result[control.name] = control.position
	return result

func _assert_near(expected: Vector2, actual: Vector2, message: String) -> void:
	_assert_true(expected.distance_to(actual) < 0.5, "%s Expected=%s Actual=%s" % [message, expected, actual])

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
