extends RefCounted
class_name BuildTag

## Canonical build-synergy vocabulary and presentation metadata.
## Runtime traits remain separate; content-facing synergy metadata must use this catalog.

const SPECS := {
	&"physical": {"label": "Physical", "color": Color(0.72, 0.76, 0.80), "icon_key": "physical", "sort_weight": 10},
	&"energy": {"label": "Energy", "color": Color(0.42, 0.78, 1.0), "icon_key": "energy", "sort_weight": 20},
	&"fire": {"label": "Fire", "color": Color(1.0, 0.42, 0.18), "icon_key": "fire", "sort_weight": 30},
	&"freeze": {"label": "Freeze", "color": Color(0.36, 0.78, 1.0), "icon_key": "freeze", "sort_weight": 40},
	&"projectile": {"label": "Projectile", "color": Color(0.48, 0.82, 1.0), "icon_key": "projectile", "sort_weight": 100},
	&"beam": {"label": "Beam", "color": Color(0.96, 0.48, 1.0), "icon_key": "beam", "sort_weight": 110},
	&"melee": {"label": "Melee", "color": Color(0.92, 0.58, 0.42), "icon_key": "melee", "sort_weight": 120},
	&"area": {"label": "Area", "color": Color(0.76, 0.56, 1.0), "icon_key": "area", "sort_weight": 130},
	&"summon": {"label": "Summon", "color": Color(0.62, 0.76, 1.0), "icon_key": "summon", "sort_weight": 140},
	&"trap": {"label": "Trap", "color": Color(0.64, 0.80, 0.52), "icon_key": "trap", "sort_weight": 150},
	&"on_hit": {"label": "On Hit", "color": Color(0.56, 0.86, 0.76), "icon_key": "on_hit", "sort_weight": 200},
	&"on_kill": {"label": "On Kill", "color": Color(1.0, 0.56, 0.50), "icon_key": "on_kill", "sort_weight": 210},
	&"on_reload": {"label": "Reload", "color": Color(0.70, 0.74, 1.0), "icon_key": "reload", "sort_weight": 220},
	&"on_move": {"label": "Movement", "color": Color(0.52, 0.88, 0.80), "icon_key": "movement", "sort_weight": 230},
	&"on_damage_taken": {"label": "On Damage", "color": Color(1.0, 0.46, 0.42), "icon_key": "on_damage", "sort_weight": 240},
	&"on_overheat": {"label": "Overheat", "color": Color(1.0, 0.34, 0.16), "icon_key": "overheat", "sort_weight": 250},
	&"on_energy_cycle": {"label": "Energy Cycle", "color": Color(0.44, 0.72, 1.0), "icon_key": "energy_cycle", "sort_weight": 260},
	&"close_range": {"label": "Close", "color": Color(0.92, 0.58, 0.42), "icon_key": "close", "sort_weight": 270},
	&"long_range": {"label": "Long Range", "color": Color(0.64, 0.76, 1.0), "icon_key": "long_range", "sort_weight": 280},
	&"heat": {"label": "Heat", "color": Color(1.0, 0.42, 0.18), "icon_key": "heat", "sort_weight": 300},
	&"charge": {"label": "Charge", "color": Color(0.72, 0.62, 1.0), "icon_key": "charge", "sort_weight": 310},
	&"ammo": {"label": "Ammo", "color": Color(0.58, 0.78, 1.0), "icon_key": "ammo", "sort_weight": 320},
	&"crit": {"label": "Crit", "color": Color(1.0, 0.66, 0.26), "icon_key": "crit", "sort_weight": 330},
	&"mark": {"label": "Mark", "color": Color(0.95, 0.72, 0.22), "icon_key": "mark", "sort_weight": 340},
	&"execute": {"label": "Execute", "color": Color(1.0, 0.56, 0.50), "icon_key": "execute", "sort_weight": 350},
	&"defense": {"label": "Defense", "color": Color(0.38, 0.84, 0.68), "icon_key": "defense", "sort_weight": 360},
	&"control": {"label": "Control", "color": Color(0.40, 0.82, 0.88), "icon_key": "control", "sort_weight": 370},
	&"sustain": {"label": "Sustain", "color": Color(0.50, 0.88, 0.54), "icon_key": "sustain", "sort_weight": 380},
	&"mobility": {"label": "Mobility", "color": Color(0.52, 0.88, 0.80), "icon_key": "mobility", "sort_weight": 390},
	&"economy": {"label": "Economy", "color": Color(0.96, 0.82, 0.28), "icon_key": "economy", "sort_weight": 400},
	&"terrain": {"label": "Terrain", "color": Color(0.54, 0.82, 0.58), "icon_key": "terrain", "sort_weight": 410},
	&"objective": {"label": "Objective", "color": Color(0.74, 0.62, 1.0), "icon_key": "objective", "sort_weight": 420},
	&"buff": {"label": "Buff", "color": Color(0.50, 0.88, 0.54), "icon_key": "buff", "sort_weight": 430},
	&"debuff": {"label": "Debuff", "color": Color(0.88, 0.48, 0.58), "icon_key": "debuff", "sort_weight": 440},
	&"weapon": {"label": "Weapon", "color": Color(0.72, 0.82, 0.96), "icon_key": "weapon", "sort_weight": 800},
	&"module": {"label": "Module", "color": Color(0.72, 0.74, 1.0), "icon_key": "module", "sort_weight": 810},
	&"task": {"label": "Task", "color": Color(0.74, 0.62, 1.0), "icon_key": "task", "sort_weight": 820},
}

const ALIASES := {
	&"reload": &"on_reload", &"movement": &"on_move", &"close": &"close_range",
	&"melee_contact": &"melee", &"area_damage": &"area", &"kill_trigger": &"on_kill",
	&"damage": &"on_hit", &"survival": &"defense", &"knockback": &"control",
	&"reward": &"economy", &"logistics": &"economy", &"recovery": &"sustain",
	&"upgrade": &"module",
}

static func normalize(value: Variant) -> StringName:
	if value == null:
		return StringName()
	var key := StringName(str(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_"))
	if key == &"onhit":
		key = &"on_hit"
	key = ALIASES.get(key, key)
	return key if SPECS.has(key) else StringName()

static func normalize_array(values: Variant) -> Array[StringName]:
	var output: Array[StringName] = []
	if values == null:
		return output
	for value in values:
		var key := normalize(value)
		if key != StringName() and not output.has(key):
			output.append(key)
	return output

static func unknown_values(values: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	if values == null:
		return output
	for value in values:
		var raw := str(value).strip_edges()
		if raw != "" and normalize(raw) == StringName() and not output.has(raw):
			output.append(raw)
	return output

static func get_spec(value: Variant) -> Dictionary:
	var key := normalize(value)
	return SPECS.get(key, {})

