extends Node

const UI_SCENE_PATH := "res://UI/scenes/UI.tscn"
const WEAPON_SCENE_PATH := "res://Player/Weapons/weapon_ranger.tscn"

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.GAMEOVER
	var ui_scene := load(UI_SCENE_PATH) as PackedScene
	_assert_true(ui_scene != null, "UI scene should load for HUD dirty coverage.")
	var ui := ui_scene.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.reset_ui_refresh_debug_counts()
	ui._mark_all_hud_dirty()
	ui._refresh_hud_if_needed(0.2)
	_assert_false(ui._hud_hp_dirty, "HUD HP dirty flag should be consumed after refresh.")
	_assert_false(ui._hud_inventory_dirty, "HUD inventory dirty flag should be consumed after refresh.")
	_assert_false(ui._hud_weapon_dirty, "HUD weapon dirty flag should be consumed after refresh.")
	var counts := ui.get_ui_refresh_debug_counts()
	_assert_equal(1, int(counts.get("hud_hp", 0)), "HUD HP refresh should be counted once.")
	_assert_equal(1, int(counts.get("hud_inventory", 0)), "HUD inventory refresh should be counted once.")
	_assert_equal(1, int(counts.get("hud_weapon", 0)), "HUD weapon refresh should be counted once.")
	_assert_equal(1, int(counts.get("hud_continuous", 0)), "HUD continuous refresh should be counted once.")

	PlayerData.player_hp = maxi(0, PlayerData.player_hp - 1)
	_assert_true(ui._hud_hp_dirty, "Changing player HP should mark only the HP HUD block dirty.")
	ui.reset_ui_refresh_debug_counts()
	ui._refresh_hud_if_needed(0.0)
	_assert_false(ui._hud_hp_dirty, "HUD HP dirty flag should be consumed after HP refresh.")
	counts = ui.get_ui_refresh_debug_counts()
	_assert_equal(1, int(counts.get("hud_hp", 0)), "HP-only dirty refresh should not refresh the whole HUD.")
	_assert_equal(0, int(counts.get("hud_inventory", 0)), "HP-only dirty refresh should skip inventory.")

	PlayerData.player_gold += 7
	_assert_true(ui._hud_inventory_dirty, "Changing player gold should mark inventory HUD dirty.")
	_assert_true(ui._upgrade_action_dirty, "Changing player gold should mark upgrade action dirty.")
	_assert_true(ui._warehouse_action_dirty, "Changing player gold should mark warehouse action dirty.")
	ui._refresh_hud_if_needed(0.0)
	_assert_false(ui._hud_inventory_dirty, "HUD inventory dirty flag should be consumed after inventory refresh.")

	ui._upgrade_action_dirty = false
	ui._warehouse_action_dirty = false
	ui._weapon_passive_panel_dirty = false
	InventoryData.temporary_modules_changed.emit()
	_assert_true(ui._upgrade_action_dirty, "Inventory module changes should mark upgrade action dirty.")
	_assert_true(ui._warehouse_action_dirty, "Inventory module changes should mark warehouse action dirty.")
	_assert_true(ui._weapon_passive_panel_dirty, "Inventory module changes should mark passive panel dirty.")

	var weapon_scene := load(WEAPON_SCENE_PATH) as PackedScene
	_assert_true(weapon_scene != null, "Weapon scene should load for passive signal coverage.")
	var weapon := weapon_scene.instantiate() as Weapon if weapon_scene != null else null
	_assert_true(weapon != null, "Weapon scene should instantiate for passive signal coverage.")
	if weapon != null:
		add_child(weapon)
		PlayerData.player_weapon_list.append(weapon)
		PlayerData.notify_weapon_list_changed()
		await get_tree().process_frame
		ui._weapon_passive_panel_dirty = false
		weapon.passive_triggered.emit(&"test", {})
		_assert_true(ui._weapon_passive_panel_dirty, "Weapon passive signal should mark passive panel dirty.")
		ui.reset_ui_refresh_debug_counts()
		ui._refresh_weapon_passive_panel_if_needed(0.0)
		counts = ui.get_ui_refresh_debug_counts()
		_assert_equal(1, int(counts.get("weapon_passive_panel", 0)), "Weapon passive dirty refresh should be counted once.")
		PlayerData.player_weapon_list.erase(weapon)
		PlayerData.notify_weapon_list_changed()
		weapon.queue_free()

	ui.queue_free()
	ui_scene = null
	weapon_scene = null
	await get_tree().process_frame
	_finish()

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _finish() -> void:
	if _failed:
		print("FAIL: hud dirty refresh")
	else:
		print("PASS: hud dirty refresh")
	get_tree().quit(1 if _failed else 0)
