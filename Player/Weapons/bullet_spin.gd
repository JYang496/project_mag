extends Bullet

@export var radius : float = 400.0
@export var angle : float = 0.0

@onready var spin = $Spin
var spin_speed : float = 10.0


func _physics_process(delta: float) -> void:
	angle += spin_speed * delta
	var x_pos = cos(angle)
	var y_pos = sin(angle)
	var destination = Vector2(position.x + radius * x_pos, position.y + radius * y_pos)
	direction = self.position.direction_to(destination)
	spin.position += direction * spin_speed

	move_and_slide()
