extends RefCounted
class_name WeaponStatCatalog

const DEFINITIONS := {
	&"damage": {"label_key": "ui.stat.damage", "fallback": "Damage", "format": &"integer", "order": 10, "group": &"damage", "direction": &"higher_better", "summary_priority": 100},
	&"fire_interval_sec": {"label_key": "ui.stat.fire_interval", "fallback": "Fire Interval", "format": &"seconds", "order": 20, "group": &"cadence", "direction": &"lower_better", "summary_priority": 95},
	&"ammo": {"label_key": "ui.stat.ammo", "fallback": "Magazine", "format": &"rounds", "order": 30, "group": &"resource", "direction": &"higher_better", "summary_priority": 90},
	&"range": {"label_key": "ui.stat.range", "fallback": "Range", "format": &"integer", "order": 40, "group": &"range", "direction": &"higher_better", "summary_priority": 85},
	&"speed": {"label_key": "ui.stat.projectile_speed", "fallback": "Projectile Speed", "format": &"integer", "order": 50, "group": &"projectile", "direction": &"higher_better", "summary_priority": 70},
	&"projectile_hits": {"label_key": "ui.stat.projectile_hits", "fallback": "Hit Limit", "format": &"integer", "order": 60, "group": &"projectile", "direction": &"higher_better", "summary_priority": 75},
	&"bullet_count": {"label_key": "ui.stat.bullet_count", "fallback": "Projectiles", "format": &"integer", "order": 70, "group": &"projectile", "direction": &"higher_better", "summary_priority": 80},
	&"explosion_scale": {"label_key": "ui.stat.explosion_scale", "fallback": "Blast Scale", "format": &"multiplier", "order": 80, "group": &"area", "direction": &"higher_better", "summary_priority": 65},
	&"duration": {"label_key": "ui.stat.duration", "fallback": "Duration", "format": &"seconds", "order": 90, "group": &"special", "direction": &"higher_better", "summary_priority": 55},
	&"hit_cd": {"label_key": "ui.stat.hit_interval", "fallback": "Hit Interval", "format": &"seconds", "order": 100, "group": &"cadence", "direction": &"lower_better", "summary_priority": 50},
	&"dot_cd": {"label_key": "ui.stat.dot_interval", "fallback": "Damage Interval", "format": &"seconds", "order": 110, "group": &"cadence", "direction": &"lower_better", "summary_priority": 45},
	&"dash_speed": {"label_key": "ui.stat.dash_speed", "fallback": "Dash Speed", "format": &"integer", "order": 120, "group": &"mobility", "direction": &"higher_better", "summary_priority": 60},
	&"return_speed": {"label_key": "ui.stat.return_speed", "fallback": "Return Speed", "format": &"integer", "order": 130, "group": &"mobility", "direction": &"higher_better", "summary_priority": 40},
	&"spin_speed": {"label_key": "ui.stat.spin_speed", "fallback": "Orbit Speed", "format": &"decimal", "order": 140, "group": &"special", "direction": &"higher_better", "summary_priority": 40},
}

static var _warned_unknown_keys: Dictionary = {}


static func get_definition(key: Variant) -> Dictionary:
	var normalized := StringName(str(key))
	if DEFINITIONS.has(normalized):
		return (DEFINITIONS[normalized] as Dictionary).duplicate(true)
	if not _warned_unknown_keys.has(normalized):
		_warned_unknown_keys[normalized] = true
		push_warning("WeaponStatCatalog has no display definition for '%s'." % str(normalized))
	return {
		"label_key": "",
		"fallback": str(normalized).replace("_", " ").capitalize(),
		"format": &"auto",
		"order": 1000,
		"group": &"special",
		"direction": &"neutral",
		"summary_priority": 0,
	}


static func sorted_keys(values: Dictionary) -> Array[StringName]:
	var keys: Array[StringName] = []
	for key_variant in values.keys():
		keys.append(StringName(str(key_variant)))
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_def := get_definition(a)
		var b_def := get_definition(b)
		var a_order := int(a_def.get("order", 1000))
		var b_order := int(b_def.get("order", 1000))
		return str(a) < str(b) if a_order == b_order else a_order < b_order
	)
	return keys


static func summary_keys(values: Dictionary, limit: int) -> Array[StringName]:
	var keys := sorted_keys(values)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_priority := int(get_definition(a).get("summary_priority", 0))
		var b_priority := int(get_definition(b).get("summary_priority", 0))
		if a_priority == b_priority:
			return int(get_definition(a).get("order", 1000)) < int(get_definition(b).get("order", 1000))
		return a_priority > b_priority
	)
	if limit > 0 and keys.size() > limit:
		keys.resize(limit)
	return keys
