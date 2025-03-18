extends EquipmentSlot
class_name EquipmentSlotShop

var sell_mode : bool = false
var ready_to_sell : bool = false


func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and item != null:
		if not sell_mode:
			InventoryData.on_select_eqp = item
		else:
			click_sell_equipment()
			
func click_sell_equipment() -> void:
	if not ready_to_sell:
		if not InventoryData.ready_to_sell_list.has(item):
			InventoryData.ready_to_sell_list.append(item)
		hover_off_color = Color(1,1,1,0.7)
		hover_off_width = border_width
		queue_redraw()
		ready_to_sell = true
	else:
		if InventoryData.ready_to_sell_list.has(item):
			InventoryData.ready_to_sell_list.erase(item)
		hover_off_color = Color(0,0,0)
		hover_off_width = 0.0
		queue_redraw()
		ready_to_sell = false
			
func reset_sell_status():
	InventoryData.ready_to_sell_list.clear()
	hover_off_color = Color(0,0,0)
	hover_off_width = 0.0
	update()
	ready_to_sell = false
