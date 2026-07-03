extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail(1, "UpgradePreviewRefreshTest: failed to instantiate player.")
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail(2, "UpgradePreviewRefreshTest: failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.upgrade_management_controller.update_upg()

	var selected_weapon := PlayerData.player_weapon_list[0] as Weapon
	var weapon_items: Array[Dictionary] = ui.upgrade_management_controller.build_items(&"weapon")
	var selected_item := _find_item_for_ref(weapon_items, selected_weapon, "weapon")
	if selected_item.is_empty():
		_fail(3, "UpgradePreviewRefreshTest: current upgrade view did not list the equipped weapon.")
		return
	ui.upgrade_management_controller.on_item_selected(selected_item)
	ui.upgrade_management_controller.refresh_detail()
	if ui.upgrade_detail_title.text == "":
		_fail(4, "UpgradePreviewRefreshTest: current upgrade detail did not refresh after selection.")
		return
	if not _detail_text(ui).contains("Lv.%d/" % int(selected_weapon.level)):
		_fail(5, "UpgradePreviewRefreshTest: current upgrade detail did not show selected weapon level.")
		return

	var next_level := int(selected_weapon.level) + 1
	PlayerData.player_gold = 999999
	ui.upgrade_management_controller.refresh_action()
	if ui.upgrade_action_button.disabled:
		_fail(6, "UpgradePreviewRefreshTest: current upgrade action did not become available.")
		return
	ui.upgrade_management_controller.on_action_pressed()
	await get_tree().process_frame
	if int(selected_weapon.level) != next_level:
		_fail(7, "UpgradePreviewRefreshTest: current upgrade action did not upgrade the selected weapon.")
		return
	selected_weapon.set_level(next_level)
	ui.upgrade_management_controller.update_upg()
	weapon_items = ui.upgrade_management_controller.build_items(&"weapon")
	selected_item = _find_item_for_ref(weapon_items, selected_weapon, "weapon")
	ui.upgrade_management_controller.on_item_selected(selected_item)
	ui.upgrade_management_controller.refresh_detail()
	if not _detail_text(ui).contains("Lv.%d/" % next_level):
		_fail(8, "UpgradePreviewRefreshTest: current upgrade detail did not refresh after upgrade.")
		return

	InventoryData.reset_runtime_state()
	print("UpgradePreviewRefreshTest: PASS")
	get_tree().quit(0)

func _find_item_for_ref(items: Array[Dictionary], ref: Object, ref_key: String) -> Dictionary:
	for item in items:
		if item.get(ref_key, null) == ref:
			return item
	return {}

func _detail_text(ui: UI) -> String:
	var parts := PackedStringArray()
	for child in ui.upgrade_detail_body.get_children():
		var label := child as Label
		if label:
			parts.append(label.text)
	return "\n".join(parts)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
