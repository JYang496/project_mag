extends RefCounted
class_name WeaponTrait

const PHYSICAL := &"physical"
const ENERGY := &"energy"
const FIRE := &"fire"
const FREEZE := &"freeze"
const HEAT := &"heat"
const CHARGE := &"charge"
const AUTO_FIRE := &"auto_fire"

const ALL: Array[StringName] = [
	PHYSICAL,
	ENERGY,
	FIRE,
	FREEZE,
	HEAT,
	CHARGE,
	AUTO_FIRE,
]

static func normalize(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower()) if value != null else StringName()
	return normalized if ALL.has(normalized) else StringName()

static func normalize_array(values: Variant) -> Array[StringName]:
	var output: Array[StringName] = []
	if values == null:
		return output
	for value in values:
		var normalized := normalize(value)
		if normalized != StringName() and not output.has(normalized):
			output.append(normalized)
	return output

static func traits_to_flags(values: Array) -> int:
	var normalized := normalize_array(values)
	var mask := 0
	for i in range(ALL.size()):
		if normalized.has(ALL[i]):
			mask |= 1 << i
	return mask

static func flags_to_traits(mask: int) -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(ALL.size()):
		if (mask & (1 << i)) != 0:
			output.append(ALL[i])
	return output
