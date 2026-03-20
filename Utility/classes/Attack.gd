extends Node
class_name Attack

const TYPE_PHYSICAL: StringName = &"physical"
const TYPE_ENERGY: StringName = &"energy"
const TYPE_FIRE: StringName = &"fire"
const TYPE_FREEZE: StringName = &"freeze"
const VALID_TYPES: Array[StringName] = [
	TYPE_PHYSICAL,
	TYPE_ENERGY,
	TYPE_FIRE,
	TYPE_FREEZE,
]

var damage := 0
var damage_type: StringName = TYPE_PHYSICAL
var source_node: Node
var source_player: Node
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}

static func normalize_damage_type(value: Variant) -> StringName:
	if value == null:
		return TYPE_PHYSICAL
	var normalized := StringName(str(value).strip_edges().to_lower())
	if VALID_TYPES.has(normalized):
		return normalized
	return TYPE_PHYSICAL


func is_from_player() -> bool:
	if source_player != null and is_instance_valid(source_player) and source_player is Player:
		return true
	if source_node == null or not is_instance_valid(source_node):
		return false
	var current: Node = source_node
	while current:
		if current is Player:
			return true
		current = current.get_parent()
	return false
