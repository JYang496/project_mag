extends Node

var INVENTORY_MAX_SLOTS : int = 4
var inventory_slots : Array = []
@onready var ui : UI= get_tree().get_first_node_in_group("ui")
@onready var player : Player = get_tree().get_first_node_in_group("player")

const AWAY = "away"
const HOVER_ON = "hover_on"
const SELECT = "select"
const ON_SELECT = "on_select"
const STATES = [AWAY, HOVER_ON ,SELECT ,ON_SELECT]
var slot_state : String = AWAY
var equipment_state : String = AWAY
var on_select_eqp :
	get:
		return on_select_eqp
	set(value):
		if on_select_eqp == null:
			on_select_eqp = value
			print("eqp was empty, assign value")
		elif on_select_eqp != null:
			# Swap position
			player.swap_weapon_position(on_select_eqp,value)
			print("swap position, clean on select afterward")
			on_select_eqp = null
			ui.update_inventory()
var on_select_slot
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
			ui.drag_item_icon.texture = value.sprite.texture
		on_drag_item = value
		
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
