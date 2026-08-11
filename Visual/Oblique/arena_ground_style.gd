class_name ArenaGroundStyle
extends RefCounted

## Stable, low-cost material variation for the modular arena floor. The texture
## remains the material owner; this policy only selects restrained shader detail.
const VARIANT_COUNT := 6
const DECAL_COUNT := 12
const THEME_COUNT := 4
const DETAIL_STRENGTH_MIN := 0.055
const DETAIL_STRENGTH_MAX := 0.095
const DECAL_STRENGTH_MAX := 0.042

const THEME_SERVICE_DECK := 0
const THEME_HAZARD_LANE := 1
const THEME_REPAIR_BAY := 2
const THEME_ENERGY_CONDUIT := 3

const THEME_NAMES := [
	"SERVICE DECK",
	"HAZARD LANE",
	"REPAIR BAY",
	"ENERGY CONDUIT",
]

const THEME_TINTS := [
	Color(0.91, 0.96, 1.00, 1.0),
	Color(1.00, 0.94, 0.84, 1.0),
	Color(0.88, 1.00, 0.96, 1.0),
	Color(0.90, 0.92, 1.00, 1.0),
]

const THEME_ACCENTS := [
	Color(0.30, 0.78, 0.96, 1.0),
	Color(1.00, 0.58, 0.20, 1.0),
	Color(0.25, 0.90, 0.70, 1.0),
	Color(0.52, 0.48, 1.00, 1.0),
]


static func build_style(cell_id: int, theme_override: int = -1) -> Dictionary:
	var mixed_seed := _mix_cell_id(cell_id)
	var variant := posmod(mixed_seed, VARIANT_COUNT)
	var strength_step := posmod(mixed_seed / VARIANT_COUNT, 3)
	var decal_id := posmod(mixed_seed / (VARIANT_COUNT * 3), DECAL_COUNT)
	var theme := theme_override if theme_override >= 0 else posmod(_mix_cell_id(cell_id + 7919), THEME_COUNT)
	theme = clampi(theme, 0, THEME_COUNT - 1)
	return {
		"theme": theme,
		"theme_name": THEME_NAMES[theme],
		"theme_tint": THEME_TINTS[theme],
		"accent_color": THEME_ACCENTS[theme],
		"variant": variant,
		"seed": float(posmod(mixed_seed, 4096)) / 4095.0,
		"detail_strength": DETAIL_STRENGTH_MIN + float(strength_step) * 0.02,
		"decal_id": decal_id,
		"decal_rotation": posmod(mixed_seed / 97, 4),
		"decal_strength": 0.026 + float(posmod(mixed_seed / 211, 3)) * 0.008,
		"ambient_phase": float(posmod(mixed_seed / 43, 32)) / 32.0,
	}


static func _mix_cell_id(cell_id: int) -> int:
	# Integer-only mixing keeps layouts stable across sessions and platforms.
	var value := cell_id * 1103515245 + 12345
	value = value ^ (value >> 11)
	return absi(value)
