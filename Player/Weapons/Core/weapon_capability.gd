extends RefCounted
class_name WeaponCapability

const SUMMON := &"summon"
const TRAP := &"trap"
const SUPPORT := &"support"
const MOVEMENT := &"movement"

const ALL: Array[StringName] = [SUMMON, TRAP, SUPPORT, MOVEMENT]

static func normalize(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower()) if value != null else StringName()
	return normalized if ALL.has(normalized) else StringName()

static func flags_to_capabilities(mask: int) -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(ALL.size()):
		if (mask & (1 << i)) != 0:
			output.append(ALL[i])
	return output
