extends Node

var INVENTORY_MAX_SLOTS : int = 4
var inventory_slots : Array = []
@onready var ui : UI = get_tree().get_first_node_in_group("ui")
@onready var player : Player = get_tree().get_first_node_in_group("player")

var on_select_eqp :
	get:
		return on_select_eqp
	set(value):
		if value != null and on_select_eqp == null and on_select_slot == null:
			# Pick equipment
			on_select_eqp = value
			on_drag_item = on_select_eqp
			print("eqp was empty, assign value")
		elif value != null and on_select_eqp != null and on_select_slot == null:
			# Swap position
			on_drag_item = null
			if value != on_select_eqp:
				player.swap_weapon_position(on_select_eqp,value)
				print("swap position, clean on select afterward")
			on_select_eqp = null
		elif value != null and on_select_eqp == null and on_select_slot != null:
			# Swap eqp and slot
			on_select_eqp = value
			slot_eqp_swap()
		elif value == null and on_select_eqp == null and on_select_slot != null:
			# Put item from inv to equipment
			on_drag_item = null
			print("add item to eqp")
			inventory_slots.erase(on_select_slot)
			player.create_weapon(on_select_slot)
			on_select_slot = null
		else:
			on_select_eqp = value
			on_drag_item = on_select_eqp
		ui.update_inventory()
		ui.refresh_border()

var on_select_slot :
	get:
		return on_select_slot
	set(value) :
		on_select_slot = value
		on_drag_item = on_select_slot
		if on_select_slot != null and on_select_eqp != null:
			slot_eqp_swap()
		elif on_select_slot == null and on_select_eqp != null:
			on_drag_item = null
			var copy_eqp = on_select_eqp.duplicate()
			if not self.inventory_slots.has(copy_eqp):
				copy_eqp.level = on_select_eqp.level
				self.inventory_slots.append(copy_eqp)
				print("put weapon into inv")
				PlayerData.player_weapon_list.erase(on_select_eqp)
				on_select_eqp.queue_free()
			on_select_eqp = null
		ui.update_inventory()
		ui.refresh_border()

func slot_eqp_swap() -> void:
	# Swap eqp and slot
	on_drag_item = null
	var copy_eqp = on_select_eqp.duplicate()
	if not self.inventory_slots.has(copy_eqp):
		copy_eqp.level = on_select_eqp.level
		self.inventory_slots.append(copy_eqp)
		PlayerData.player_weapon_list.erase(on_select_eqp)
		on_select_eqp.queue_free()
		inventory_slots.erase(on_select_slot)
		player.create_weapon(on_select_slot)
	on_select_eqp = null
	print("swap eqp and slot")
	on_select_slot = null
	on_select_eqp = null

var on_drag_item :
	get:
		return on_drag_item
	set(value):
		if on_drag_item == value:
			# Cancel selection
			ui.drag_item_icon.texture = null
			on_drag_item = null
			return
		# Select item
		if value == null:
			ui.drag_item_icon.texture = null
		else:
			ui.drag_item_icon.texture = value.get_node("Sprite").texture
		on_drag_item = value
		
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
