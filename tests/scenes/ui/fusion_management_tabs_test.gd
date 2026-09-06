extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class RestAreaAvailabilityStub:
	extends Node
	func is_module_management_available() -> bool: return true

var _failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	DataHandler.prepare_world_data(true)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var rest := RestAreaAvailabilityStub.new()
	rest.add_to_group("rest_area")
	add_child(rest)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	ui.ensure_upgrade_management()
	await get_tree().process_frame
	var view := ui.upgrade_management_view as Control
	var items: Array = view.call("build_items", &"weapon") as Array
	_expect(not items.is_empty(), "fusion management needs a weapon row")
	if items.is_empty():
		await _finish()
		return
	view.call("_on_item_selected", items[0])
	var original_upgrade_id := str(view.selected_item.get("id", ""))
	view.set_service_mode(&"fusion")
	_expect(view.get_service_mode() == &"fusion" and not view.upgrade_mode_buttons.visible, "fusion tab must replace upgrade sub-tabs")
	_expect(view.service_tabs.position.y >= 54.0, "service tabs must remain below the panel title")
	view.set_service_mode(&"upgrade")
	_expect(str(view.selected_item.get("id", "")) == original_upgrade_id, "switching service tabs must preserve upgrade selection")
	view.set_service_mode(&"fusion")
	var weapon := view.selected_item.get("weapon", null) as Weapon
	_expect(weapon != null, "selected fusion weapon must remain valid")
	if weapon == null:
		await _finish()
		return
	weapon.set_level(3)
	view.selected_fusion_branch_id = "gatling_mg"
	view.refresh_detail()
	var branch_row := view.upgrade_detail_body.get_node_or_null("FusionBranchOptions") as HBoxContainer
	_expect(branch_row != null and branch_row.get_child_count() == 2, "Fuse 2 branch choices must use one compact horizontal row")
	var heat := InventoryData.add_weapon_cores([&"fire", &"heat"], 1, false)
	var projectile := InventoryData.add_weapon_cores([&"physical", &"projectile"], 1, false)
	var unrelated := InventoryData.add_weapon_cores([&"freeze", &"control"], 1, false)
	var heat_key := str(heat.get("core_key", ""))
	var projectile_key := str(projectile.get("core_key", ""))
	var unrelated_key := str(unrelated.get("core_key", ""))
	view.call("_change_core_selection", heat_key, 1)
	view.call("_change_core_selection", projectile_key, 1)
	var preview: Dictionary = view.call("_get_fusion_preview")
	_expect(bool(preview.get("ok", false)), "two manually selected cores must enable a union-covered recipe")
	view.call("_change_core_selection", projectile_key, -1)
	view.call("_change_core_selection", unrelated_key, 1)
	preview = view.call("_get_fusion_preview")
	_expect(not bool(preview.get("ok", false)) and str(preview.get("reason_code", "")) == "core_unrelated", "an unrelated core must not satisfy the selector")
	view.call("_change_core_selection", unrelated_key, -1)
	view.call("_change_core_selection", projectile_key, 1)
	InventoryData.remove_weapon_cores([&"physical", &"projectile"], 1, false)
	var count_before_stale_submit := InventoryData.get_weapon_core_count([&"fire", &"heat"])
	_expect(not bool(view.trigger_action()), "stale UI selection must fail safely")
	_expect(InventoryData.get_weapon_core_count([&"fire", &"heat"]) == count_before_stale_submit, "stale submit must not consume another core")
	InventoryData.add_weapon_cores([&"physical", &"projectile"], 1, false)
	view.call("_change_core_selection", projectile_key, 1)
	_expect(bool(view.trigger_action()), "valid manual selection must submit exactly once")
	_expect(int(weapon.fuse) == 2 and weapon.branch_runtime.has_branch("gatling_mg"), "successful UI fusion must apply the selected branch")
	view.refresh_detail()
	var fuse3_core := InventoryData.add_weapon_cores([&"heat", &"projectile"], 3, false)
	var fuse3_key := str(fuse3_core.get("core_key", ""))
	view.call("_change_core_selection", fuse3_key, 1)
	view.call("_change_core_selection", fuse3_key, 1)
	view.call("_change_core_selection", fuse3_key, 1)
	preview = view.call("_get_fusion_preview")
	_expect(int(preview.get("required_core_count", 0)) == 3 and int(preview.get("required_level", 0)) == 6, "Fuse 3 UI must expose the 3-core and Lv.6 requirements")
	_expect(str(preview.get("reason_code", "")) == "level_too_low", "Fuse 3 UI must report its level gate")
	weapon.set_level(6)
	_expect(bool(view.trigger_action()) and int(weapon.fuse) == 3, "Fuse 3 UI must enhance the existing branch")
	var heat_after := InventoryData.get_weapon_core_count([&"fire", &"heat"])
	view.trigger_action()
	_expect(InventoryData.get_weapon_core_count([&"fire", &"heat"]) == heat_after, "repeated UI submit must not consume cores")
	_expect(LocalizationManager.tr_key("ui.management.tab.fusion", "") != "", "English/Chinese fusion localization key must resolve")
	await _finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish() -> void:
	var code := 0
	if _failures.is_empty(): print("PASS: fusion management tabs")
	else:
		code = 1
		for failure in _failures: push_error(failure)
		print("FAIL: fusion management tabs")
	await TEST_TEARDOWN.finish(self, code, _reset)

func _reset() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
