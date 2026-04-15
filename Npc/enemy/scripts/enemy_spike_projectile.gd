extends Area2D
class_name EnemySpikeProjectile

@export var speed: float = 190.0
@export var life_time: float = 3.2
@export var damage: int = 1
@export var radius: float = 11.0
@export var damage_type: StringName = Attack.TYPE_PHYSICAL

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT
var source_enemy: Node
var _life_remaining: float = 0.0

func _ready() -> void:
	_life_remaining = maxf(life_time, 0.05)
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius = maxf(radius, 2.0)
	rotation = direction.angle() + deg_to_rad(90.0)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * maxf(delta, 0.0)
	_life_remaining -= maxf(delta, 0.0)
	if _life_remaining <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not (area is HurtBox):
		return
	var hurt_box := area as HurtBox
	if not hurt_box.get_collision_layer_value(1):
		return
	var valid_source: Node = source_enemy if source_enemy != null and is_instance_valid(source_enemy) else null
	var damage_data := DamageManager.build_damage_data(
		valid_source,
		max(1, damage),
		Attack.normalize_damage_type(damage_type),
		{"amount": 0.0, "angle": direction}
	)
	damage_data.dedupe_token = StringName("enemy_spike_projectile_%d" % get_instance_id())
	damage_data.dedupe_window_sec = 0.03
	DamageManager.apply_to_hurt_box(hurt_box, damage_data)
	queue_free()
