extends BaseNPC
class_name BaseEnemy
@export var damage := 0
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")
@onready var drop_preload = preload("res://Objects/loots/drop.tscn")

signal enemy_death()

@onready var hit_box_dot: HitBoxDot = $HitBoxDot
@onready var enable_collision_timer: Timer = $EnableCollisionTimer

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

func death() -> void:
	var drop = drop_preload.instantiate()
	drop.drop = coin_preload
	drop.value = hp / 10 + 1
	drop.global_position = self.global_position
	self.call_deferred("add_sibling",drop)
	enemy_death.emit()
	queue_free()

func erase() -> void:
	enemy_death.emit()
	queue_free()

func _on_enable_collision_timer_timeout() -> void:
	self.set_collision_mask_value(6,true)
	self.set_collision_mask_value(3,true)
