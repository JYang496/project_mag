extends Node2D

var time_scale = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Engine.time_scale = time_scale


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
