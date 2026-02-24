extends Effect
class_name KnockBackEffect

var angle : Vector2 = Vector2.ZERO
var amount : float = 0.0

func _ready() -> void:
	supports_melee = true
	super._ready()

func projectile_effect_ready() -> void:
	if "knock_back" in projectile:
		projectile.knock_back = {"amount": amount, "angle": angle}

func melee_effect_ready() -> void:
	var knock_back_data := {"amount": amount, "angle": angle}
	melee.set("knock_back", knock_back_data)
