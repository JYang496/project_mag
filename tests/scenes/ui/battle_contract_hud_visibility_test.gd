extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

class IntroSequenceProbe extends RefCounted:
	signal released
	var events: Array[String]

	func _init(event_log: Array[String]) -> void:
		events = event_log

	func has_prepared_intro() -> bool:
		return true

	func play_prepared_intro() -> void:
		events.append("intro_started")
		await released
		events.append("intro_finished")

	func refresh(_allow_deployment_handoff: bool = false) -> void:
		pass

class DeploymentSequenceProbe extends RefCounted:
	signal released
	var events: Array[String]

	func _init(event_log: Array[String]) -> void:
		events = event_log

	func play() -> void:
		events.append("deployment_started")
		await released
		events.append("deployment_finished")

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
	var queued_status := presenter.call("_format_elimination_status", {"active_enemies": 1, "queued_enemies": 2}, 3, 3) as String
	var deployed_status := presenter.call("_format_elimination_status", {"active_enemies": 3, "queued_enemies": 0}, 3, 3) as String
	_assert_true(queued_status.contains("1") and queued_status.contains("2"),
		"Elimination HUD must show active enemies and queued reinforcements as separate values.")
	_assert_true(deployed_status.contains("3") and not deployed_status.contains("2"),
		"Elimination HUD must remove the reinforcement count after every target is deployed.")
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

	var transition_events: Array[String] = []
	var intro_sequence := IntroSequenceProbe.new(transition_events)
	var deployment_sequence := DeploymentSequenceProbe.new(transition_events)
	var real_intro_presenter = ui.battle_contract_hud_presenter
	var real_deployment_presenter = ui.battlefield_deployment_presenter
	ui.battle_contract_hud_presenter = intro_sequence
	ui.battlefield_deployment_presenter = deployment_sequence
	ui.play_battle_entry_intro()
	await get_tree().process_frame
	_assert_true(transition_events == ["deployment_started"],
		"The contract intro must remain hidden while battlefield deployment is active.")
	deployment_sequence.released.emit()
	await get_tree().process_frame
	_assert_true(transition_events == ["deployment_started", "deployment_finished", "intro_started"],
		"The contract intro must start only after battlefield deployment finishes.")
	intro_sequence.released.emit()
	await get_tree().create_timer(0.12).timeout
	_assert_true(transition_events == ["deployment_started", "deployment_finished", "intro_started", "intro_finished"],
		"Battle entry must finish with the protocol description after loading completes.")
	ui.battle_contract_hud_presenter = real_intro_presenter
	ui.battlefield_deployment_presenter = real_deployment_presenter

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
