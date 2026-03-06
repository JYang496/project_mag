extends Effect
class_name KnockBackEffect

var angle : Vector2 = Vector2.ZERO
var amount : float = 0.0

func _ready() -> void:
	supports_melee = true
	super._ready()

func projectile_effect_ready() -> void:
	if "knock_back" in projectile:
		projectile.knock_back.amount = amount
		projectile.knock_back.angle = angle

func melee_effect_ready() -> void:
	if melee.has_method("get") and melee.get("knock_back") != null:
		melee.knock_back.amount = amount
		melee.knock_back.angle = angle
