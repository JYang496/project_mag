extends Node

var INVENTORY_MAX_SLOTS : int = 4
var inventory_slots : Array = []
@onready var ui = get_tree().get_first_node_in_group("ui")

const AWAY = "away"
const HOVER_ON = "hover_on"
const SELECT = "select"
const ON_SELECT = "on_select"
const STATES = [AWAY, HOVER_ON ,SELECT ,ON_SELECT]
var slot_state : String = AWAY
var equipment_state : String = AWAY
var on_select_item :
	get:
		return on_select_item
	set(value):
		print(value,on_select_item)
		if on_select_item == value:
			ui.drag_item_icon.texture = null
			on_select_item = null
			return
		on_select_item = value
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
