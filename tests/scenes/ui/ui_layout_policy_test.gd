extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const LAYOUT := preload("res://UI/scripts/management/ui_layout_policy.gd")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const MANAGEMENT_SHELL_SCENE := preload("res://UI/scenes/runtime/management_shell.tscn")
const PROJECTED_WORLD_UI := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const HUD_PHASE_CONTROLLER := preload("res://UI/scripts/components/hud_phase_controller.gd")

class FakeHeatWeapon:
	extends Node

	func get_combat_resource_slots() -> Array[Dictionary]:
		return [{
			"type": &"heat",
			"ratio": 0.5,
			"state": &"normal",
			"short_text": "HEAT",
			"tooltip": "phase lifecycle regression",
			"priority": 10,
		}]

class FakeHeatPlayer:
	extends Node
	var weapon: Node
	var active_skill_holder := Node.new()

	func _ready() -> void:
		add_child(active_skill_holder)

	func get_main_weapon() -> Node:
		return weapon

	func has_equipped_energy_weapon() -> bool:
		return false

const VIEWPORTS := [
	Vector2(1280.0, 720.0),
	Vector2(1600.0, 900.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
]

var _failed := false

func _ready() -> void:
	for viewport_size in VIEWPORTS:
		_test_management_layout(viewport_size)
		_test_expandable_primary_menus(viewport_size)
		_test_single_action_primary_menu(viewport_size)
		_test_hud_lanes(viewport_size)
	_test_hud_phase_visibility_contract()
	_test_management_shell_priority()
	_test_pause_modal_layer_priority()
	await _test_prepare_delayed_special_resource_visibility()
	print("FAIL UI layout policy" if _failed else "PASS UI layout policy")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _test_management_layout(viewport_size: Vector2) -> void:
	var safe := LAYOUT.safe_margin(viewport_size)
	var usable := Rect2(safe, viewport_size - safe * 2.0)
	var panel := LAYOUT.management_panel_rect(viewport_size)
	_expect(usable.encloses(panel), "%s management panel exceeds safe area" % viewport_size)
	_expect(panel.size.x > 0.0 and panel.size.y > 0.0, "%s management panel collapsed" % viewport_size)

func _test_expandable_primary_menus(viewport_size: Vector2) -> void:
	var previous_height := 0.0
	for entry_count in [1, 2, 4, 6]:
		var panel := LAYOUT.primary_menu_rect(viewport_size, entry_count)
		_expect(
			Rect2(Vector2.ZERO, viewport_size).encloses(panel),
			"%s primary menu with %d entries exceeds viewport" % [viewport_size, entry_count]
		)
		_expect(
			panel.size.y >= previous_height,
			"%s primary menu must not shrink when entries increase" % viewport_size
		)
		previous_height = panel.size.y

func _test_single_action_primary_menu(viewport_size: Vector2) -> void:
	var standard := LAYOUT.primary_menu_rect(viewport_size, 1)
	var compact := LAYOUT.primary_menu_rect(viewport_size, 1, &"single_action")
	_expect(compact.size.y < standard.size.y, "%s single-action menu should be shorter than a standard menu" % viewport_size)
	_expect(compact.size.y >= 200.0, "%s single-action menu should retain readable title, description, and action spacing" % viewport_size)
	_expect(Rect2(Vector2.ZERO, viewport_size).encloses(compact), "%s single-action menu exceeds viewport" % viewport_size)

func _test_hud_phase_visibility_contract() -> void:
	var prepare := HUD_PHASE_CONTROLLER.visibility_for(PhaseManager.PREPARE)
	_expect(bool(prepare.gold), "Prepare HUD should show the economy value")
	_expect(not bool(prepare.character_status), "Prepare HUD should not show battle-only character status")
	_expect(not bool(prepare.objectives), "Prepare HUD should not show battle objectives")
	var battle := HUD_PHASE_CONTROLLER.visibility_for(PhaseManager.BATTLE)
	_expect(not bool(battle.gold), "Battle HUD should hide the economy value")
	_expect(bool(battle.character_status), "Battle HUD should show existing character status")
	_expect(bool(battle.objectives), "Battle HUD should show objectives")
	var management := HUD_PHASE_CONTROLLER.visibility_for(PhaseManager.PREPARE, true)
	_expect(float(management.world_hud_alpha) < 0.5, "Open management UI should dim persistent world HUD")
	var game_over := HUD_PHASE_CONTROLLER.visibility_for(PhaseManager.GAMEOVER)
	_expect(not bool(game_over.battle_hud) and not bool(game_over.utility), "Game over should clear runtime HUD rails")

func _test_hud_lanes(viewport_size: Vector2) -> void:
	var left := LAYOUT.hud_left_lane(viewport_size)
	var right := LAYOUT.hud_right_lane(viewport_size)
	var center := LAYOUT.hud_center_safe_rect(viewport_size)
	_expect(not left.intersects(right), "%s left and right HUD lanes overlap" % viewport_size)
	_expect(not left.intersects(center), "%s left HUD lane enters combat-safe center" % viewport_size)
	_expect(not right.intersects(center), "%s right HUD lane enters combat-safe center" % viewport_size)
	_expect(center.size.x > 0.0 and center.size.y > 0.0, "%s combat-safe center collapsed" % viewport_size)

func _test_management_shell_priority() -> void:
	var shell := MANAGEMENT_SHELL_SCENE.instantiate() as Control
	_expect(shell.z_index > 50, "management shell must render above persistent HUD rails")
	_expect(shell.z_index < 200, "management shell must remain below protocol and modal overlays")
	shell.free()

func _test_pause_modal_layer_priority() -> void:
	var ui := UI_SCENE.instantiate() as CanvasLayer
	var pause_layer := ui.get_node_or_null("PauseMenuLayer") as CanvasLayer
	var pause_root := ui.get_node_or_null("PauseMenuLayer/PauseMenuRoot") as Control
	_expect(pause_layer != null, "pause menu must own a dedicated CanvasLayer")
	_expect(pause_root != null and pause_root.get_parent() == pause_layer, "pause blocker must live inside the dedicated modal layer")
	if pause_layer != null:
		_expect(pause_layer.layer == UI.PAUSE_MODAL_CANVAS_LAYER, "pause layer must use the reserved modal priority")
		_expect(pause_layer.layer > PROJECTED_WORLD_UI.LAYER_ORDER, "pause layer must render above projected damage labels")
	ui.free()

func _test_prepare_delayed_special_resource_visibility() -> void:
	PhaseManager.reset_runtime_state()
	PlayerData.player = null
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1
	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	# Keep this lifecycle test focused on HUD initialization.
	ui._rest_area_purchase_prewarm_generation += 1
	await get_tree().process_frame
	var special_root := ui.hud_presenter.special_resource_slot_container
	_expect(special_root != null, "special resource root must exist before initial phase visibility sync")
	_expect(special_root != null and not special_root.visible, "prepare phase must initially hide the special resource root")
	_test_visible_hud_refresh_is_idempotent(ui)

	var player := FakeHeatPlayer.new()
	player.weapon = FakeHeatWeapon.new()
	player.add_child(player.weapon)
	add_child(player)
	PlayerData.player = player
	for _frame_index in range(12):
		await get_tree().physics_frame

	_expect(ui.hud_presenter.primary_resource_meter != null, "delayed heat weapon must create its resource meter")
	_expect(not special_root.visible, "delayed heat resource must inherit prepare-phase hidden visibility")

func _test_visible_hud_refresh_is_idempotent(ui: UI) -> void:
	var hud_root := ui.battle_hud
	var hud_key := hud_root.get_instance_id()
	ui.hud_phase_controller.invalidate()
	ui.hud_phase_controller.refresh(true)
	_expect(is_equal_approx(hud_root.modulate.a, 1.0), "unchanged visible HUD must not restart its fade-in")
	_expect(not ui.hud_phase_controller._visibility_tweens.has(hud_key), "unchanged visible HUD must not allocate a visibility tween")

func _reset_runtime_state() -> void:
	PlayerData.player = null
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1
	PhaseManager.reset_runtime_state()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
