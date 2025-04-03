extends Node2D
class_name Weapon

@onready var player = get_tree().get_first_node_in_group("player")
@onready var modules: Node2D = $Modules
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite

# Common variables for weapons
var level : int
var fuse : int
var max_level : int

func set_level(lv):
	pass

func set_fuse(f):
	pass
