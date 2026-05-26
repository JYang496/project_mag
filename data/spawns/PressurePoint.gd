extends Resource
class_name PressurePoint

@export_range(0.0, 1.0, 0.01) var t: float = 0.0
@export_range(0.1, 5.0, 0.01) var multiplier: float = 1.0

func sanitize() -> void:
	t = clampf(t, 0.0, 1.0)
	multiplier = maxf(multiplier, 0.1)
