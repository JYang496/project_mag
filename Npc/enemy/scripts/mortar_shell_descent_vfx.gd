extends Node2D
class_name MortarShellDescentVfx

@onready var animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite


func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	animated_sprite.animation = &"descent"
	animated_sprite.stop()
	animated_sprite.frame = 0


func set_descent_progress(progress: float) -> void:
	if animated_sprite == null:
		return
	var frame_count := animated_sprite.sprite_frames.get_frame_count(&"descent")
	if frame_count <= 0:
		return
	var clamped_progress := clampf(progress, 0.0, 0.9999)
	animated_sprite.frame = mini(int(floor(clamped_progress * float(frame_count))), frame_count - 1)


func cleanup_for_battle_end() -> void:
	queue_free()
