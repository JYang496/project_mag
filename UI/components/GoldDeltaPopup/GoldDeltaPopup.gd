extends Control

@onready var value_label: Label = %Value


func show_delta(delta: int) -> void:
	value_label.text = "+%d" % delta if delta > 0 else "%d" % delta
	value_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25, 1.0) if delta > 0 else Color(1.0, 0.42, 0.22, 1.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(0.0, -22.0), 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
