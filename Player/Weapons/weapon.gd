extends Node2D
class_name Weapon

@onready var modules: Node2D = $Modules
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite

# Common variables for weapons
var level : int
var fuse : int = 1
var max_level : int = 3
var FINAL_MAX_FUSE : int = 3
var FINAL_MAX_LEVEL : int = 7

func set_level(lv):
	pass

func set_max_level(ml : int):
	max_level = ml
