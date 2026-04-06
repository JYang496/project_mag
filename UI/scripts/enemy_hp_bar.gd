extends Node2D
class_name EnemyHpBar

@export var offset_y: float = -30.0

@onready var bar: ProgressBar = $Bar
@onready var hide_timer: Timer = $HideTimer

func _ready() -> void:
	visible = false
	position = Vector2(0.0, offset_y)
	hide_timer.one_shot = true

func set_max_hp(value: int) -> void:
	var max_value: int = max(1, value)
	bar.max_value = float(max_value)
	if bar.value > bar.max_value:
		bar.value = bar.max_value

func set_hp(value: int) -> void:
	bar.value = clampf(float(value), 0.0, bar.max_value)

func show_for(duration_sec: float) -> void:
	visible = true
	hide_timer.stop()
	hide_timer.wait_time = maxf(0.05, duration_sec)
	hide_timer.start()

func hide_immediately() -> void:
	hide_timer.stop()
	visible = false

func _on_hide_timer_timeout() -> void:
	visible = false
