extends RefCounted
class_name InventoryOperationResultPresenter

# Translate inventory errors at the display boundary; accept other services' reasons.
const ERRORS := {
	&"last_weapon": ["ui.inventory.reason.last_weapon", "At least one weapon must remain equipped."],
	&"stored_equip_rest_only": ["ui.inventory.reason.stored_equip_rest_only", "Stored weapons can only be equipped during rest."],
	&"invalid_stored_weapon": ["ui.inventory.reason.invalid_stored_weapon", "Invalid stored weapon."],
	&"no_weapon_slots": ["ui.inventory.reason.no_weapon_slots", "No weapon slots available."],
	&"stored_exchange_rest_only": ["ui.inventory.reason.stored_exchange_rest_only", "Stored weapons can only be exchanged during rest."],
	&"invalid_weapon": ["ui.module.reason.invalid_weapon", "Invalid weapon."],
	&"incoming_install_phase": ["ui.inventory.reason.incoming_install_phase", "New weapons can only be installed during settlement or rest."],
	&"invalid_module": ["ui.module.reason.invalid_module", "Invalid module."],
	&"module_rest_only": ["ui.module.reason.rest_area_only", "Modules can only be managed in the Rest Area."],
	&"no_module_container": ["ui.module.reason.no_container", "Weapon has no module container."],
	&"unique_module": ["ui.module.reason.unique", "Only one module of each type can be owned."],
	&"no_module_slots": ["ui.module.reason.no_slots", "No module slots available."],
	&"module_not_equipped": ["ui.module.reason.not_equipped", "Module is not equipped."],
	&"module_purchase_rest_only": ["ui.inventory.reason.module_purchase_rest_only", "Modules can only be purchased during rest."],
	&"insufficient_gold": ["ui.shop.not_enough_gold", "Not enough gold."],
	&"module_upgrade_rest_only": ["ui.inventory.reason.module_upgrade_rest_only", "Modules can only be upgraded during rest."],
	&"module_max_level": ["ui.inventory.reason.module_max_level", "Module is fully upgraded."],
	&"gold_spend_disabled": ["ui.workbench.gold_spend_disabled", "Gold purchases are unavailable in Gold Supply mode."],
	&"insufficient_modification_points": ["ui.modification.insufficient", "Not enough modification points."],
	&"weapon_sell_disabled": ["ui.weapon.sell_disabled", "Weapon selling has been replaced by the weapon warehouse."],
}

static func reason(result: Dictionary) -> String:
	var error := StringName(result.get("error", &""))
	if error == &"module_incompatible":
		return LocalizationManager.localize_module_reason(str(result.get("detail", "")))
	if ERRORS.has(error):
		var entry: Array = ERRORS[error]
		return LocalizationManager.tr_key(str(entry[0]), str(entry[1]))
	return LocalizationManager.localize_module_reason(str(result.get("reason", "")))
