extends Node2D
class_name Weapon

@onready var player = get_tree().get_first_node_in_group("player")
@onready var modules: Node2D = $Modules

# Common variables for weapons
var level : int
var star : int
var max_level
