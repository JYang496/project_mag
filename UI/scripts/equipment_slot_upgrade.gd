extends EquipmentSlot
class_name EquipmentSlotUpgrade

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
	selected_label = Label.new()
	selected_label.name = "UpgradeSelectedLabel"
	selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	selected_label.offset_left = 8.0
	selected_label.offset_top = 8.0
	selected_label.offset_right = -8.0
	selected_label.offset_bottom = 36.0
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	selected_label.add_theme_font_size_override("font_size", 16)
	add_child(selected_label)
