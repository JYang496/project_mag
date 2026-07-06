extends Node

const FRAMES := preload("res://Player/Weapons/Projectiles/chainsaw_spin_frames.tres")
const PROJECTILE_SCENE := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const FIRST_FRAME := preload("res://asset/images/weapons/projectiles/chainsaw_spin_01.png")


func _ready() -> void:
	assert(FRAMES.get_frame_count(&"spin") == 6)
	assert(is_equal_approx(FRAMES.get_animation_speed(&"spin"), 24.0))

	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.projectile_texture = FIRST_FRAME
	projectile.projectile_frames = FRAMES
	projectile.desired_pixel_size = Vector2(32.0, 32.0)
	add_child(projectile)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var static_sprite := projectile.get_node("Bullet/BulletSprite") as Sprite2D
	var animated_sprite := projectile.get_node("Bullet/BulletAnimation") as AnimatedSprite2D
	assert(not static_sprite.visible)
	assert(animated_sprite.visible)
	assert(animated_sprite.is_playing())
	assert(animated_sprite.animation == &"spin")
	print("PASS chainsaw_spin_frames")
	get_tree().quit(0)
