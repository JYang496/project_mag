extends Node2D

@export var hitbox_dot : HitBoxDot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if hitbox_dot:
		var shape = RectangleShape2D.new()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
