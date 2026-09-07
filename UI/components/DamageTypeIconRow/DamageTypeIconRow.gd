extends HBoxContainer

const SLOT_SCENE := preload("res://UI/components/DamageTypeIconSlot/DamageTypeIconSlot.tscn")


func set_data(items: Array, icon_size: float, row_name: String) -> void:
	name = row_name
	for child in get_children():
		child.queue_free()
	for item_variant in items.slice(0, 2):
		var item := (item_variant as Dictionary).duplicate()
		item["size"] = icon_size
		var slot := SLOT_SCENE.instantiate() as PanelContainer
		slot.call("set_data", item)
		add_child(slot)
