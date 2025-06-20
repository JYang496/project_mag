extends Effect
class_name KnockBackEffect

var angle : Vector2 = Vector2.ZERO
var amount : float = 0.0

func bullet_effect_ready() -> void:
	if "knock_back" in bullet:
		bullet.knock_back = {"amount": amount, "angle": angle}
