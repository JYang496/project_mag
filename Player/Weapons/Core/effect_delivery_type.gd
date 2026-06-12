extends RefCounted
class_name EffectDeliveryType

const SELF := &"self"
const TARGET := &"target"
const AREA := &"area"
const ALL: Array[StringName] = [SELF, TARGET, AREA]

static func normalize(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower()) if value != null else StringName()
	return normalized if ALL.has(normalized) else StringName()
