class_name ArenaGroundStyle
extends RefCounted

## Stable, low-cost material variation for the modular arena floor. The texture
## remains the material owner; this policy only selects restrained shader detail.
const VARIANT_COUNT := 6
const DECAL_COUNT := 12
const DETAIL_STRENGTH_MIN := 0.055
const DETAIL_STRENGTH_MAX := 0.095
const DECAL_STRENGTH_MAX := 0.042


static func build_style(cell_id: int) -> Dictionary:
	var mixed_seed := _mix_cell_id(cell_id)
	var variant := posmod(mixed_seed, VARIANT_COUNT)
	var strength_step := posmod(mixed_seed / VARIANT_COUNT, 3)
	var decal_id := posmod(mixed_seed / (VARIANT_COUNT * 3), DECAL_COUNT)
	return {
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
