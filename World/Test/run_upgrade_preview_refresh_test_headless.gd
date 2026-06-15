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
	ui.update_upg()

	var slot := ui.get_node("GUI/UpgradeRootv2/Panel/Equipped/EquipmentSlotUpg") as EquipmentSlotUpgrade
	var preview := ui.upgrade_preview
	var click := InputEventAction.new()
	click.action = "CLICK"
	click.pressed = true
	slot._on_background_gui_input(click)

	var selected_weapon := PlayerData.player_weapon_list[0] as Weapon
	if InventoryData.on_select_upg != selected_weapon:
		_fail(3, "UpgradePreviewRefreshTest: click did not select the weapon.")
		return
	if preview.weapon_node != selected_weapon:
		_fail(4, "UpgradePreviewRefreshTest: preview did not refresh immediately after click.")
		return
	if not preview.lblName.text.contains("Lv.%d/" % int(selected_weapon.level)):
		_fail(5, "UpgradePreviewRefreshTest: preview header did not show selected weapon level.")
		return

	var next_level := int(selected_weapon.level) + 1
	selected_weapon.set_level(next_level)
	ui.update_upg()
	if not preview.lblName.text.contains("Lv.%d/" % next_level):
		_fail(6, "UpgradePreviewRefreshTest: preview did not refresh after upgrade.")
		return

	InventoryData.reset_runtime_state()
	print("UpgradePreviewRefreshTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
