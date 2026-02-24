extends Effect
class_name LinearMovement

@export var speed: float = 400.0
@export var direction: Vector2 = Vector2.ZERO


func projectile_effect_ready() -> void:
	adjust_base_displacement()

func adjust_base_displacement() -> void:
	projectile.base_displacement = projectile.base_displacement + direction * speed

func set_base_displacement() -> void:
	projectile.base_displacement = direction * speed

func _physics_process(delta: float) -> void:
	pass
