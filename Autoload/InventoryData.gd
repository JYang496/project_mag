extends Node

var INVENTORY_MAX_SLOTS : int = 8
var MAX_FUSE_SIZE : int = 2
var inventory_slots : Array = []
var moddule_slots : Array = []
var ready_to_sell_list : Array = []
var ready_to_fuse_list : Array = []
#@onready var ui : UI = get_tree().get_first_node_in_group("ui")
#@onready var player : Player = get_tree().get_first_node_in_group("player")

# At this stage, on_select_module should not do anything
var on_select_module :
	get:
		return on_select_module
	#set(value):
		#if value != null and on_select_module == null and on_select_inventory_module == null:
			##on_select_module = value
			##on_drag_item = on_select_module
			#on_drag_item = null
			#on_select_module = null
			#print("module was empt, assign value")
		#elif value != null and on_select_module != null and on_select_inventory_module == null:
			## Clear the drag and on select value, no swap action taken
			#on_drag_item = null
			#on_select_module = null
		#elif value != null and on_select_module == null and on_select_inventory_module != null:
			## Swap module between weapon and inv, no swap action taken
			#on_drag_item = null
			#on_select_inventory_module = null
		#elif value == null and on_select_module == null and on_select_inventory_module != null:
			## Install module into a weapon
			#on_drag_item = null
			#on_select_inventory_module = null
		#else:
			#on_select_module = value
			#on_drag_item = on_select_module
		#ui.update_modules()
		#ui.update_inventory()
		#ui.update_shop()
		#ui.refresh_border()

var on_select_module_weapon :
	get:
		return on_select_module_weapon
	set(value):
		if value != null and on_select_inventory_module != null and on_select_module == null:
			var module_list : Array = value.modules.get_children()
			if module_list.size() >= value.MAX_MODULE_NUMBER:
				return
			value.modules.add_child(on_select_inventory_module)
			value.calculate_status()
			moddule_slots.erase(on_select_inventory_module)
			GlobalVariables.ui.update_modules()
			GlobalVariables.ui.update_inventory()
			GlobalVariables.ui.update_shop()
			GlobalVariables.ui.refresh_border()
			on_select_inventory_module = null

var on_select_inventory_module :
	get:
		return on_select_inventory_module
	set(value):
		if value != null and on_select_inventory_module == null and on_select_module == null:
			# Pick module in inv
			on_select_inventory_module = value
			on_drag_item = on_select_inventory_module
		elif value != null and on_select_inventory_module != null and on_select_module == null:
			# Swap position in inventory
			on_drag_item = null
			on_select_inventory_module = null
		elif value != null and on_select_inventory_module == null and on_select_module != null:
			# Put weapon module into inv, not gonna work
			on_drag_item = null
			on_select_module = null
		else:
			on_select_inventory_module = value
			on_drag_item = on_select_inventory_module

var on_select_eqp :
	get:
		return on_select_eqp
	set(value):
		if value != null and on_select_eqp == null and on_select_slot == null:
			# Pick equipment
			on_select_eqp = value
			on_drag_item = on_select_eqp
		elif value != null and on_select_eqp != null and on_select_slot == null:
			# Swap position
			on_drag_item = null
			if value != on_select_eqp:
				PlayerData.player.swap_weapon_position(on_select_eqp,value)
			on_select_eqp = null
		elif value != null and on_select_eqp == null and on_select_slot != null:
			# Swap eqp and slot
			on_select_eqp = value
			slot_eqp_swap()
		elif value == null and on_select_eqp == null and on_select_slot != null:
			# Put item from inv to equipment
			on_drag_item = null
			inventory_slots.erase(on_select_slot)
			PlayerData.player.create_weapon(on_select_slot)
			on_select_slot = null
		else:
			on_select_eqp = value
			on_drag_item = on_select_eqp
		GlobalVariables.ui.update_modules()
		GlobalVariables.ui.update_inventory()
		GlobalVariables.ui.update_shop()
		GlobalVariables.ui.refresh_border()

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
				PlayerData.player_weapon_list.erase(on_select_eqp)
				on_select_eqp.queue_free()
			on_select_eqp = null
		GlobalVariables.ui.update_inventory()
		GlobalVariables.ui.refresh_border()

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
		PlayerData.player.create_weapon(on_select_slot)
	on_select_eqp = null
	on_select_slot = null
	on_select_eqp = null

var on_select_upg :
	get:
		return on_select_upg
	set(value):
		on_select_upg = value
		GlobalVariables.ui.update_upg()

var on_select_eqp_gf :
	get:
		return on_select_eqp_gf
	set(value):
		add_fuse_item(value)
		on_select_eqp_gf = value
		GlobalVariables.ui.update_gf()

var on_select_slot_gf :
	get:
		return on_select_slot_gf
	set(value):
		add_fuse_item(value)
		on_select_slot_gf = value
		GlobalVariables.ui.update_gf()

func add_fuse_item(item) -> void:
	if ready_to_fuse_list.size() < MAX_FUSE_SIZE and not ready_to_fuse_list.has(item):
		if ready_to_fuse_list.size() == 0 or item.ITEM_NAME == ready_to_fuse_list[0].ITEM_NAME:
			ready_to_fuse_list.append(item)
		GlobalVariables.ui.update_gf()

func remove_fuse_item(item) -> void:
	if ready_to_fuse_list.has(item):
		ready_to_fuse_list.erase(item)
		GlobalVariables.ui.update_gf()

var on_drag_item :
	get:
		return on_drag_item
	set(value):
		if on_drag_item == value:
			# Cancel selection
			GlobalVariables.ui.drag_item_icon.texture = null
			on_drag_item = null
			return
		# Select item
		if value == null:
			GlobalVariables.ui.drag_item_icon.texture = null
		else:
			GlobalVariables.ui.drag_item_icon.texture = value.get_node("Sprite").texture
		on_drag_item = value

func clear_on_select() -> void:
	on_select_upg = null
	on_select_module = null
	on_select_module_weapon = null
	on_select_inventory_module = null
	on_select_eqp = null
	on_select_slot = null
	on_drag_item = null
