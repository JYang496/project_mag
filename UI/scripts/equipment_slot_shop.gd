extends EquipmentSlot
class_name EquipmentSlotShop

var sell_mode : bool = false
var ready_to_sell : bool = false
var sell_selected_label: Label

func _ready() -> void:
	super._ready()
	sell_selected_label = Label.new()
	sell_selected_label.name = "SellSelectedLabel"
	sell_selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_selected_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sell_selected_label.offset_bottom = 30.0
	sell_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_selected_label.add_theme_font_size_override("font_size", 16)
	sell_selected_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.25))
	sell_selected_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02))
	sell_selected_label.add_theme_constant_override("outline_size", 5)
	refresh_sell_label_text()
	sell_selected_label.visible = false
	background.add_child(sell_selected_label)


func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		if not sell_mode:
			return
		else:
			click_sell_equipment()
			
func click_sell_equipment() -> void:
	if item == null or not is_instance_valid(item):
		return
	if not ready_to_sell:
		if InventoryData.ready_to_sell_list.size() >= PlayerData.player_weapon_list.size() - 1:
			var ui_limit = GlobalVariables.ui
			if ui_limit and is_instance_valid(ui_limit) and ui_limit.has_method("show_item_message"):
				ui_limit.show_item_message(LocalizationManager.tr_key(
					"ui.shop.sell.keep_one",
					"At least one weapon must remain equipped."
				), 1.8)
			return
		if not InventoryData.ready_to_sell_list.has(item):
			InventoryData.ready_to_sell_list.append(item)
		hover_off_color = Color(1.0, 0.22, 0.16, 1.0)
		hover_off_width = 6.0
		queue_redraw()
		ready_to_sell = true
	else:
		if InventoryData.ready_to_sell_list.has(item):
			InventoryData.ready_to_sell_list.erase(item)
		hover_off_color = Color(0,0,0)
		hover_off_width = 0.0
		queue_redraw()
		ready_to_sell = false
	sell_selected_label.visible = ready_to_sell
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("refresh_shop_sell_summary"):
		ui.refresh_shop_sell_summary()
			
func reset_sell_status():
	hover_off_color = Color(0,0,0)
	hover_off_width = 0.0
	update()
	ready_to_sell = false
	if sell_selected_label:
		sell_selected_label.visible = false

func refresh_sell_label_text() -> void:
	if sell_selected_label:
		sell_selected_label.text = LocalizationManager.tr_key("ui.shop.sell.selected", "MARKED FOR SALE")
