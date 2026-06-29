extends RefCounted
class_name LootRarity

const COMMON := "common"
const RARE := "rare"
const EPIC := "epic"

const ALL := [
	COMMON,
	RARE,
	EPIC,
]

const DEFAULT_WEIGHT_BY_RARITY := {
	COMMON: 100.0,
	RARE: 45.0,
	EPIC: 15.0,
}

const DISPLAY_NAME_BY_RARITY := {
	COMMON: "Common",
	RARE: "Rare",
	EPIC: "Epic",
}

const COLOR_BY_RARITY := {
	COMMON: Color(1.0, 1.0, 1.0, 1.0),
	RARE: Color(0.35, 0.55, 1.0, 1.0),
	EPIC: Color(0.62, 0.35, 0.95, 1.0),
}

static func normalize(value: String) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if ALL.has(normalized):
		return normalized
	return COMMON

static func get_all() -> Array:
	return ALL.duplicate()

static func get_count() -> int:
	return ALL.size()

static func get_weight_summary() -> String:
	var chunks: PackedStringArray = []
	for rarity in ALL:
		chunks.append("%s %.0f" % [get_display_name(rarity), get_default_weight(rarity)])
	return " / ".join(chunks)

static func get_default_weight(rarity: String) -> float:
	return float(DEFAULT_WEIGHT_BY_RARITY.get(normalize(rarity), DEFAULT_WEIGHT_BY_RARITY[COMMON]))

static func sanitize_weight(weight: float, _rarity: String) -> float:
	if weight < 0.0:
		return 0.0
	return weight

static func get_display_name(rarity: String) -> String:
	return str(DISPLAY_NAME_BY_RARITY.get(normalize(rarity), DISPLAY_NAME_BY_RARITY[COMMON]))

static func get_color(rarity: String) -> Color:
	return COLOR_BY_RARITY.get(normalize(rarity), COLOR_BY_RARITY[COMMON])
