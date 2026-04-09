extends RefCounted
class_name DamageData

var amount: int = 0
var damage_type: StringName = Attack.TYPE_PHYSICAL
var knock_back := {
	"amount": 0,
	"angle": Vector2.ZERO
}
var source_node: Node
var source_player: Node

# Optional duplicate-event guard metadata.
var dedupe_token: StringName = StringName()
var dedupe_window_sec: float = 0.0


func setup(
	damage_amount: int,
	type_value: StringName,
	knockback_value: Dictionary,
	source_node_value: Node,
	source_player_value: Node = null
) -> DamageData:
	amount = damage_amount
	damage_type = Attack.normalize_damage_type(type_value)
	knock_back = _normalize_knock_back(knockback_value)
	source_node = source_node_value
	source_player = source_player_value
	return self


func to_attack() -> Attack:
	var attack := Attack.new()
	attack.damage = amount
	attack.damage_type = damage_type
	attack.knock_back = knock_back
	attack.source_node = source_node
	attack.source_player = source_player
	return attack


func _normalize_knock_back(value: Dictionary) -> Dictionary:
	var normalized := {
		"amount": 0,
		"angle": Vector2.ZERO
	}
	if value == null:
		return normalized
	if value.has("amount"):
		normalized.amount = int(value.get("amount", 0))
	if value.has("angle"):
		var angle_value: Variant = value.get("angle", Vector2.ZERO)
		if angle_value is Vector2:
			normalized.angle = angle_value
	return normalized
