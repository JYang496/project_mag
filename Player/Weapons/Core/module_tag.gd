extends RefCounted
class_name ModuleTag

const CORE: Array[StringName] = [
	&"trigger", &"buff", &"debuff", &"dot", &"duration", &"stacking", &"movement",
	&"physical", &"energy", &"fire", &"freeze", &"heat", &"charge",
	&"projectile", &"melee_contact", &"beam", &"area", &"summon", &"trap", &"support",
	&"mark", &"reload", &"close", &"on_hit", &"execute", &"defense", &"economy",
]

static func normalize_array(values: Variant) -> Array[StringName]:
	var output: Array[StringName] = []
	if values == null:
		return output
	for value in values:
		var normalized := StringName(str(value).strip_edges().to_lower())
		if normalized != StringName() and not output.has(normalized):
			output.append(normalized)
	return output
