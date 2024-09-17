extends Label

func _ready() -> void:
	var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"scale",Vector2(1,1),0.1).from(Vector2.ZERO)
	tween.tween_property(self,"position:y",position.y - 50,0.1)
	tween.tween_callback(self.queue_free).set_delay(0.3)

func setNumber(number):
	text = str(number)

func setColor(color):
	set("theme_override_colors/font_color",color)
