extends RefCounted
class_name DamageDeliveryType

const PROJECTILE := &"projectile"
const MELEE_CONTACT := &"melee_contact"
const BEAM := &"beam"
const AREA := &"area"

const ALL: Array[StringName] = [
	PROJECTILE,
	MELEE_CONTACT,
	BEAM,
	AREA,
]

static func normalize(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower()) if value != null else StringName()
	return normalized if ALL.has(normalized) else StringName()

static func flags_to_types(mask: int) -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(ALL.size()):
		if (mask & (1 << i)) != 0:
			output.append(ALL[i])
	return output

static func types_to_flags(values: Array) -> int:
	var mask := 0
	for value in values:
		var normalized := normalize(value)
		var index := ALL.find(normalized)
		if index >= 0:
			mask |= 1 << index
	return mask
