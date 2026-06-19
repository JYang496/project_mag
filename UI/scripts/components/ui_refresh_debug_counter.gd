extends RefCounted
class_name UiRefreshDebugCounter

const DEFAULT_KEYS := [
	"hud_hp",
	"hud_inventory",
	"hud_weapon",
	"hud_continuous",
	"weapon_passive_panel",
	"shop_purchase_action",
	"upgrade_action",
	"warehouse_action",
]

var _counts := {}

func _init() -> void:
	reset()

func increment(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1

func reset() -> void:
	_counts.clear()
	for key in DEFAULT_KEYS:
		_counts[key] = 0

func snapshot() -> Dictionary:
	return _counts.duplicate()
