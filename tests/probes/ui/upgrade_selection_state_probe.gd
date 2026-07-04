extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")

class RestAreaAvailabilityStub:
	extends Node
	func is_module_management_available() -> bool:
		return true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 999

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	var rest_area_stub := RestAreaAvailabilityStub.new()
	rest_area_stub.add_to_group("rest_area")
	get_tree().root.add_child(rest_area_stub)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	ui.upgrade_management_controller.apply_mode(&"weapon")
	ui.upgrade_management_controller.update_upg()
	var items: Array[Dictionary] = ui.upgrade_management_view.build_items(&"weapon")
	if items.is_empty():
		_fail("UpgradeSelectionStateProbe: no weapon item was available.")
		return
	var weapon := items[0].get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		_fail("UpgradeSelectionStateProbe: first upgrade row had no valid weapon.")
		return
	var previous_level := int(weapon.level)
	ui.upgrade_management_view.call("_on_item_selected", items[0])
	if ui._upgrade_selected_item.is_empty():
		_fail("UpgradeSelectionStateProbe: selection did not sync back to UI owner state.")
		return
	ui.upgrade_management_controller.on_action_pressed()
	if int(weapon.level) != previous_level + 1:
		_fail("UpgradeSelectionStateProbe: selected weapon was not upgraded.")
		return

	print("PASS: upgrade selection survives controller action sync")
	printerr("PASS: upgrade selection survives controller action sync")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	print("FAIL: ", message)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(1)
