extends RefCounted
class_name OutgoingDamageResult

var damage: int
var is_critical: bool

func _init(resolved_damage: int = 1, critical: bool = false) -> void:
	damage = maxi(1, resolved_damage)
	is_critical = critical
