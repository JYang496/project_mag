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
	var deployment_presenter = ui.battlefield_deployment_presenter
	var panel := presenter.panel as PanelContainer
	_assert_true(left_stack != null, "Contract HUD should create a dedicated left stack.")
	_assert_true(right_stack != null, "Right HUD stack should remain available for non-contract UI.")
	_assert_true(panel != null, "Contract HUD presenter should expose its panel.")
	_assert_true(not panel.visible, "Inactive contract HUD should be fully hidden.")
	_assert_true(deployment_presenter != null, "Battlefield deployment presenter should be initialized with the HUD.")
	_assert_true(deployment_presenter.overlay != null and not deployment_presenter.overlay.visible,
		"Battlefield deployment overlay should remain hidden outside BATTLE_STARTING.")

	var before := _visible_control_positions(right_stack)
	panel.visible = true
	await get_tree().process_frame
	var after_show := _visible_control_positions(right_stack)
	panel.visible = false
	await get_tree().process_frame
	var after_hide := _visible_control_positions(right_stack)
	_assert_true(before == after_show and before == after_hide,
		"Showing or hiding the contract must not reflow right-side UI.")

	var intro_probe := Control.new()
	ui.gui_root.add_child(intro_probe)
	presenter.set("_intro_control", intro_probe)
	presenter.set("_intro_playing", true)
	presenter.call("_on_phase_changed", PhaseManager.BATTLE_STARTING)
	_assert_true(is_instance_valid(intro_probe) and not intro_probe.is_queued_for_deletion(),
		"BATTLE_STARTING must preserve the prepared contract intro.")
	presenter.call("_on_phase_changed", PhaseManager.SETTLEMENT)
	await get_tree().process_frame
	_assert_true(not is_instance_valid(intro_probe),
		"Leaving deployment and battle phases must clean the prepared contract intro.")

	print("FAIL: battle contract HUD layout" if _failed else "PASS: battle contract HUD layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _visible_control_positions(root: Control) -> Dictionary:
	var result := {}
	for child in root.get_children():
		var control := child as Control
		if control != null and control.visible:
			result[control.name] = control.position
	return result

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
