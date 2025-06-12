extends Effect
class_name SpiralMovement

@export var spin_rate : float = 6.0
@export var spin_speed : float = 400.0
var angle : float = 0.0
var direction: Vector2 = Vector2.ZERO

#@onready var module_parent = self.get_parent() # Bullet root is parent


func _process(delta: float) -> void:
	angle += spin_rate * delta
	var x_pos = cos(angle)
	var y_pos = sin(angle)
	var destination = Vector2(bullet.position.x + x_pos, bullet.position.y + y_pos)
	direction = bullet.position.direction_to(destination)
	bullet.bullet_displacement = direction * spin_speed
