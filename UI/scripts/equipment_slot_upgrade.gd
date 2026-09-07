extends EquipmentSlot
class_name EquipmentSlotUpgrade

const UPGRADE_SELECTED_LABEL_SCENE := preload("res://UI/components/UpgradeSelectedLabel/UpgradeSelectedLabel.tscn")

var selected_label: Label

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		InventoryData.on_select_upg = item
		var ui = GlobalVariables.ui
		if ui and is_instance_valid(ui) and ui.upgrade_management_controller:
			ui.upgrade_management_controller.update_upg()

func update() -> void:
	super.update()
	_ensure_selected_label()
	var selected := item != null and is_instance_valid(item) and InventoryData.on_select_upg == item
	selected_label.visible = selected
	selected_label.text = LocalizationManager.tr_key("ui.upgrade.selected", "SELECTED")
	queue_redraw()

func _draw() -> void:
	var selected := item != null and is_instance_valid(item) and InventoryData.on_select_upg == item
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.85, 1.0), false, 5.0)
		return
	super._draw()

func _ensure_selected_label() -> void:
	if selected_label and is_instance_valid(selected_label):
		return
	selected_label = UPGRADE_SELECTED_LABEL_SCENE.instantiate() as Label
	add_child(selected_label)
