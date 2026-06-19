extends ScrollContainer
class_name ModuleShopListView

@onready var module_shop: VBoxContainer = $ModuleShop

func populate_slots(slot_scene: PackedScene, count: int = 4) -> void:
	if slot_scene == null:
		return
	for child in module_shop.get_children():
		child.queue_free()
	for index in range(count):
		var slot := slot_scene.instantiate()
		slot.name = "ModuleShopSlot%d" % (index + 1)
		module_shop.add_child(slot)
