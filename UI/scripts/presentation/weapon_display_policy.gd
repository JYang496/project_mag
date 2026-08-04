extends RefCounted
class_name WeaponDisplayPolicy

const SHOP_CARD: StringName = &"shop_card"
const SHOP_DETAIL: StringName = &"shop_detail"
const UPGRADE_LIST: StringName = &"upgrade_list"
const UPGRADE_DETAIL: StringName = &"upgrade_detail"
const WAREHOUSE_CARD: StringName = &"warehouse_card"
const WAREHOUSE_DETAIL: StringName = &"warehouse_detail"
const REPLACEMENT_COMPARE: StringName = &"replacement_compare"
const REWARD_CARD: StringName = &"reward_card"
const REWARD_DETAIL: StringName = &"reward_detail"
const HUD_TOOLTIP: StringName = &"hud_tooltip"

const POLICIES := {
	SHOP_CARD: {"summary_limit": 0, "description_lines": 1, "show_taxonomy": false},
	SHOP_DETAIL: {"summary_limit": 0, "description_lines": 0, "show_taxonomy": true},
	UPGRADE_LIST: {"summary_limit": 3, "description_lines": 0, "show_taxonomy": false},
	UPGRADE_DETAIL: {"summary_limit": 0, "description_lines": 0, "show_taxonomy": true},
	WAREHOUSE_CARD: {"summary_limit": 0, "description_lines": 0, "show_taxonomy": false},
	WAREHOUSE_DETAIL: {"summary_limit": 4, "description_lines": 3, "show_taxonomy": true},
	REPLACEMENT_COMPARE: {"summary_limit": 3, "description_lines": 2, "show_taxonomy": true},
	REWARD_CARD: {"summary_limit": 0, "description_lines": 2, "show_taxonomy": false},
	REWARD_DETAIL: {"summary_limit": 3, "description_lines": 2, "show_taxonomy": true},
	HUD_TOOLTIP: {"summary_limit": 0, "description_lines": 1, "show_taxonomy": true},
}


static func get_policy(context: StringName) -> Dictionary:
	return (POLICIES.get(context, {}) as Dictionary).duplicate(true)


static func summary_limit(context: StringName) -> int:
	return int(get_policy(context).get("summary_limit", 0))
