extends Node2D
class_name BulletBase

var hp : int = 1
var damage = 1
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
var expire_time : float = 2.5
var base_displacement = Vector2.ZERO
var bullet_displacement = Vector2.ZERO
var blt_texture
var module_list = []
var hitbox_type = "once"
var dot_cd : float
var overlapping : bool :
	set(value):
		if value != overlapping:
			overlapping = value
			overlapping_signal.emit()

# Signals
signal overlapping_signal()

# Preloads
@onready var hitbox_once = preload("res://Utility/hit_hurt_box/hit_box.tscn")
@onready var hitbox_dot = preload("res://Utility/hit_hurt_box/hit_box_dot.tscn")

# Children
@onready var player  = get_tree().get_first_node_in_group("player")
@onready var expire_timer = $ExpireTimer
@onready var bullet = $Bullet
@onready var bullet_sprite = $Bullet/BulletSprite
var hitbox_ins

func _ready() -> void:
	expire_timer.wait_time = expire_time
	bullet_sprite.texture = blt_texture
	init_hitbox(hitbox_type)
	expire_timer.start()

# This function will 0adjust the hitbox shape identical to your sprite size
func init_hitbox(hitbox_type = "once") -> void:
	var shape = RectangleShape2D.new()
	shape.size = bullet_sprite.texture.get_size()
	match hitbox_type:
		"dot":
			hitbox_ins = hitbox_dot.instantiate()
			hitbox_ins.dot_cd = dot_cd
		_:
			hitbox_ins = hitbox_once.instantiate()
	hitbox_ins.get_child(0).shape = shape
	hitbox_ins.set_collision_mask_value(3,true)
	hitbox_ins.hitbox_owner = self
	bullet_sprite.call_deferred("add_child",hitbox_ins)


func _physics_process(delta: float) -> void:
	self.position = self.position + base_displacement * delta
	if base_displacement != Vector2.ZERO:
		self.rotation = base_displacement.angle() + deg_to_rad(90)
	bullet.position = bullet.position + bullet_displacement * delta

func enemy_hit(charge : int = 1):
	hp -= charge
	if hp <= 0:
		self.call_deferred("queue_free")


func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")
