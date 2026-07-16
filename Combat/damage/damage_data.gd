extends RefCounted
class_name DamageData

const SOURCE_PLAYER_WEAPON := &"player_weapon"

var amount: int = 0
var damage_type: StringName = Attack.TYPE_PHYSICAL
var source_category: StringName = StringName()
var delivery_type: StringName = StringName()
var knock_back := {
	"amount": 0,
	"angle": Vector2.ZERO
}
var source_node: Node
var source_player: Node

# Optional duplicate-event guard metadata.
var dedupe_token: StringName = StringName()
var dedupe_window_sec: float = 0.0
var damage_is_final: bool = false
var suppress_reactive_effects: bool = false


func setup(
	damage_amount: int,
	type_value: StringName,
	knockback_value: Dictionary,
	source_node_value: Node,
	source_player_value: Node = null,
	source_category_value: StringName = StringName(),
	delivery_type_value: StringName = StringName()
) -> DamageData:
	amount = damage_amount
	damage_type = Attack.normalize_damage_type(type_value)
	knock_back = _normalize_knock_back(knockback_value)
	source_node = source_node_value
	source_player = source_player_value
	source_category = source_category_value
	delivery_type = DamageDeliveryType.normalize(delivery_type_value)
	return self

func has_valid_player_weapon_context() -> bool:
	if source_category != SOURCE_PLAYER_WEAPON:
		return true
	return delivery_type != StringName()


func to_attack() -> Attack:
	var attack := Attack.new()
	attack.damage = amount
	attack.damage_type = damage_type
	attack.knock_back = knock_back
	attack.source_node = source_node
	attack.source_player = source_player
	attack.damage_is_final = damage_is_final
	attack.suppress_reactive_effects = suppress_reactive_effects
	attack.feedback_batch_id = int(get_instance_id())
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
