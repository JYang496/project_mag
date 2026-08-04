extends RefCounted

const BATTLE_HINT_MIN_WIDTH := 152.0
const BATTLE_HINT_MAX_WIDTH := 220.0
const BATTLE_HINT_HEIGHT := 30.0

var _owner: Node2D
var _zone_merchant_hint_text := "Purchase"
var _zone_smith_hint_text := "Upgrade"
var _zone_module_hint_text := "Warehouses"
var _zone_board_hint_text := "Board"
var _zone_battle_hint_text := "Choose next protocol"
var _zone_hint_forward_offset := Vector2(0.0, -44.0)
var _zone_battle_hint_extra_offset := Vector2(0.0, -14.0)
var _zone_hint_z_index := 80
var _zone_hover_color := Color(0.44, 0.88, 1.0, 1.0)
var _zone_selected_color := Color(0.38, 1.0, 0.58, 0.95)
var _zone_ids := {
	"merchant": 0,
	"smith": 1,
	"module": 2,
	"board": 6,
	"center": 4,
}
var _zone_hint_status_signature := ""
var _zone_hint_visual_state := ""
var _merchant_hint_label: Label
var _smith_hint_label: Label
var _module_hint_label: Label
var _board_hint_label: Label
var _battle_hint_label: Label

func setup(
	owner_node: Node2D,
	zone_ids: Dictionary,
	merchant_hint_text: String,
	smith_hint_text: String,
	module_hint_text: String,
	board_hint_text: String,
	battle_hint_text: String,
	hint_forward_offset: Vector2,
	battle_hint_extra_offset: Vector2,
	hint_z_index: int,
	hover_color: Color,
	selected_color: Color
) -> void:
	_owner = owner_node
	_zone_ids = zone_ids.duplicate()
	_zone_merchant_hint_text = merchant_hint_text
	_zone_smith_hint_text = smith_hint_text
	_zone_module_hint_text = module_hint_text
	_zone_board_hint_text = board_hint_text
	_zone_battle_hint_text = battle_hint_text
	_zone_hint_forward_offset = hint_forward_offset
	_zone_battle_hint_extra_offset = battle_hint_extra_offset
	_zone_hint_z_index = hint_z_index
	_zone_hover_color = hover_color
	_zone_selected_color = selected_color
	_merchant_hint_label = _get_hint_label("MerchantHintLabel")
	_smith_hint_label = _get_hint_label("SmithHintLabel")
	_module_hint_label = _get_hint_label("ModuleHintLabel")
	_board_hint_label = _get_hint_label("BoardHintLabel")
	_battle_hint_label = _get_hint_label("BattleHintLabel")

func invalidate_status() -> void:
	_zone_hint_status_signature = ""

func has_status_changed() -> bool:
	return _build_zone_hint_status_signature() != _zone_hint_status_signature

func refresh() -> void:
	if _merchant_hint_label:
		_merchant_hint_label.text = _format_zone_label(
			"$",
			LocalizationManager.tr_key("ui.rest.zone.purchase.title", _zone_merchant_hint_text),
			"Shop",
			0
		)
	if _smith_hint_label:
		var upgradable_count := _get_affordable_upgrade_count()
		_smith_hint_label.text = _format_zone_label(
			"",
			LocalizationManager.tr_key("ui.rest.zone.combined_upgrade.title", _zone_smith_hint_text),
			"UP",
			upgradable_count
		)
	if _module_hint_label:
		var pending_count := InventoryData.temporary_modules.size()
		_module_hint_label.text = _format_zone_label(
			"",
			LocalizationManager.tr_key("ui.rest.zone.warehouses.title", _zone_module_hint_text),
			"MOD",
			pending_count
		)
	if _board_hint_label:
		_board_hint_label.text = _format_zone_label(
			"#",
			LocalizationManager.tr_key("ui.rest.zone.board.title", _zone_board_hint_text),
			"BOARD",
			_get_board_badge_count()
		)
	if _battle_hint_label:
		_battle_hint_label.text = _battle_prompt_text()
		_fit_battle_hint_label()
	_zone_hint_status_signature = _build_zone_hint_status_signature()
	layout()

func setup_labels() -> void:
	for label in _all_hint_labels():
		if label == null:
			continue
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_as_relative = false
		label.z_index = _zone_hint_z_index
	for zone_label in [_merchant_hint_label, _smith_hint_label, _module_hint_label, _board_hint_label]:
		if zone_label == null:
			continue
		zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zone_label.max_lines_visible = 1
		zone_label.clip_text = true
		zone_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		zone_label.add_theme_font_size_override("font_size", 16)
		zone_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		zone_label.add_theme_constant_override("shadow_offset_x", 1)
		zone_label.add_theme_constant_override("shadow_offset_y", 2)
	if _battle_hint_label:
		_battle_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_battle_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_battle_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_battle_hint_label.max_lines_visible = 1
		_battle_hint_label.clip_text = true
		_battle_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_battle_hint_label.add_theme_font_size_override("font_size", 15)
		_battle_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
		_battle_hint_label.add_theme_constant_override("shadow_offset_x", 1)
		_battle_hint_label.add_theme_constant_override("shadow_offset_y", 1)
		_fit_battle_hint_label()
	update_visuals(true)
	layout()

func layout() -> void:
	_place_zone_hint_label(_merchant_hint_label, int(_zone_ids.get("merchant", 0)))
	_place_zone_hint_label(_smith_hint_label, int(_zone_ids.get("smith", 1)))
	_place_zone_hint_label(_module_hint_label, int(_zone_ids.get("module", 2)))
	_place_zone_hint_label(_board_hint_label, int(_zone_ids.get("board", 6)))
	_place_zone_hint_label(
		_battle_hint_label,
		int(_zone_ids.get("center", 4)),
		_zone_battle_hint_extra_offset
	)

func update_visibility() -> void:
	if not _is_owner_valid():
		for label in _all_hint_labels():
			if label:
				label.visible = false
		_clear_hud_zone_hint()
		return
	_set_hint_label_visible(_merchant_hint_label, int(_zone_ids.get("merchant", 0)))
	_set_hint_label_visible(_smith_hint_label, int(_zone_ids.get("smith", 1)))
	_set_hint_label_visible(_module_hint_label, int(_zone_ids.get("module", 2)))
	_set_hint_label_visible(_board_hint_label, int(_zone_ids.get("board", 6)))
	_set_hint_label_visible(_battle_hint_label, int(_zone_ids.get("center", 4)), true)
	# Scene labels are projected by RestArea in hybrid mode and retain the correct
	# per-zone anchor. The legacy single HUD hint would duplicate this guidance.
	_clear_hud_zone_hint()

func update_visuals(force: bool = false) -> void:
	if not _is_owner_valid():
		return
	var state := "%d|%d|%s" % [
		int(_owner.get("hover_zone_id")),
		int(_owner.get("selected_zone_id")),
		str(bool(_owner.get("is_auto_moving"))),
	]
	if not force and state == _zone_hint_visual_state:
		return
	_zone_hint_visual_state = state
	_style_zone_hint(_merchant_hint_label, int(_zone_ids.get("merchant", 0)))
	_style_zone_hint(_smith_hint_label, int(_zone_ids.get("smith", 1)))
	_style_zone_hint(_module_hint_label, int(_zone_ids.get("module", 2)))
	_style_zone_hint(_board_hint_label, int(_zone_ids.get("board", 6)))
	_style_battle_hint()

func _get_hint_label(label_name: StringName) -> Label:
	if not _is_owner_valid():
		return null
	return _owner.get_node_or_null(NodePath(label_name)) as Label

func _all_hint_labels() -> Array[Label]:
	return [
		_merchant_hint_label,
		_smith_hint_label,
		_module_hint_label,
		_board_hint_label,
		_battle_hint_label,
	]

func _set_hint_label_visible(label: Label, zone_id: int, is_center_action_hint: bool = false) -> void:
	if label == null:
		return
	label.visible = bool(_owner.call("_should_show_zone_hint_label", zone_id, is_center_action_hint))

func _update_hud_zone_hint() -> void:
	var ui := _get_ui()
	if ui == null or not ui.has_method("set_rest_area_hover_hint"):
		return
	var zone_id := _get_hud_zone_hint_id()
	if zone_id < 0:
		_clear_hud_zone_hint()
		return
	var text := _build_hud_zone_hint_text(zone_id)
	if ui.has_method("set_rest_area_hover_hint_at_world"):
		ui.call("set_rest_area_hover_hint_at_world", text, _get_zone_hint_anchor_world(zone_id))
	else:
		ui.call("set_rest_area_hover_hint", text)

func _get_zone_hint_anchor_world(zone_id: int) -> Vector2:
	if _is_owner_valid() and _owner.has_method("_get_zone_center_global"):
		return _owner.call("_get_zone_center_global", zone_id) as Vector2
	return Vector2.ZERO

func _clear_hud_zone_hint() -> void:
	var ui := _get_ui()
	if ui != null and ui.has_method("clear_rest_area_hover_hint"):
		ui.call("clear_rest_area_hover_hint")

func _get_hud_zone_hint_id() -> int:
	if not _is_owner_valid():
		return -1
	if not bool(_owner.call("_is_interaction_enabled")):
		return -1
	if bool(_owner.call("_are_zone_hints_suppressed_by_ui")):
		return -1
	var hover_zone_id := int(_owner.get("hover_zone_id"))
	if hover_zone_id >= 0 and bool(_owner.call("_is_zone_available", hover_zone_id)):
		return hover_zone_id
	var center_zone_id := int(_zone_ids.get("center", 4))
	var selected_zone_id := int(_owner.get("selected_zone_id"))
	if selected_zone_id >= 0 \
			and selected_zone_id != center_zone_id \
			and bool(_owner.call("_is_zone_available", selected_zone_id)):
		return selected_zone_id
	if bool(_owner.call("_is_zone_hint_intro_active")):
		return center_zone_id
	return -1

func _build_hud_zone_hint_text(zone_id: int) -> String:
	var parts := _get_zone_hint_text_parts(zone_id)
	for part in parts:
		var text := str(part).strip_edges()
		if text != "":
			return text
	return ""

func _get_zone_hint_text_parts(zone_id: int) -> Array[String]:
	if zone_id == int(_zone_ids.get("merchant", 0)):
		return [
			LocalizationManager.tr_key("ui.rest.zone.purchase.title", _zone_merchant_hint_text),
			LocalizationManager.tr_key("ui.rest.zone.purchase.status", "Buy weapons and modules"),
			LocalizationManager.tr_key("ui.purchase.open", "Buy Weapons and Modules"),
		]
	if zone_id == int(_zone_ids.get("smith", 1)):
		return [
			LocalizationManager.tr_key("ui.rest.zone.combined_upgrade.title", _zone_smith_hint_text),
			_get_upgrade_status_text(),
			LocalizationManager.tr_key("ui.upgrade.open", "Upgrade Weapons and Modules"),
		]
	if zone_id == int(_zone_ids.get("module", 2)):
		return [
			LocalizationManager.tr_key("ui.rest.zone.warehouses.title", _zone_module_hint_text),
			_get_module_status_text(),
			LocalizationManager.tr_key("ui.management.menu.subtitle", "Open weapon or module warehouse"),
		]
	if zone_id == int(_zone_ids.get("board", 6)):
		return [
			LocalizationManager.tr_key("ui.rest.zone.board.title", _zone_board_hint_text),
			_get_board_status_text(),
			LocalizationManager.tr_key("ui.rest.zone.board.action", "Open Grid Management or Task Management"),
		]
	if zone_id == int(_zone_ids.get("center", 4)):
		var battle_hint := LocalizationManager.tr_key("ui.tutorial.ctx.battle", _zone_battle_hint_text)
		return [
			battle_hint,
			battle_hint,
			battle_hint,
		]
	return []

func _get_upgrade_status_text() -> String:
	var upgradable_count := _get_affordable_upgrade_count()
	if upgradable_count > 0:
		return LocalizationManager.tr_format(
			"ui.rest.zone.upgrade.available",
			{"count": upgradable_count},
			"%d upgrades available" % upgradable_count
		)
	return LocalizationManager.tr_key("ui.rest.zone.upgrade.none", "No upgrades available")

func _get_module_status_text() -> String:
	var pending_count := InventoryData.temporary_modules.size()
	if pending_count > 0:
		return LocalizationManager.tr_format(
			"ui.rest.zone.warehouses.pending",
			{"count": pending_count},
			"%d stored modules" % pending_count
		)
	return LocalizationManager.tr_key("ui.rest.zone.warehouses.none", "Open weapon and module warehouses")

func _get_board_status_text() -> String:
	return LocalizationManager.tr_key(
		"ui.rest.zone.board.status",
		"Install cell effects or deploy task modules"
	)

func _format_zone_label(icon_text: String, title: String, _badge_label: String, _count: int) -> String:
	if icon_text == "":
		return title
	return "%s  %s" % [icon_text, title]

func _battle_prompt_text() -> String:
	return LocalizationManager.tr_format(
		"ui.rest.zone.battle.prompt",
		{"input": _primary_click_label()},
		"[{input}] Choose Next Protocol"
	)

func _primary_click_label() -> String:
	for event in InputMap.action_get_events(&"CLICK"):
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			return LocalizationManager.tr_key("ui.controls.key.lmb", "LMB")
	return LocalizationManager.tr_key("ui.controls.key.lmb", "LMB")

func _fit_battle_hint_label() -> void:
	if _battle_hint_label == null:
		return
	var font := _battle_hint_label.get_theme_font("font")
	var font_size := _battle_hint_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		_battle_hint_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var target_size := Vector2(
		clampf(ceilf(text_width) + 20.0, BATTLE_HINT_MIN_WIDTH, BATTLE_HINT_MAX_WIDTH),
		BATTLE_HINT_HEIGHT
	)
	_battle_hint_label.custom_minimum_size = target_size
	_battle_hint_label.size = target_size

func _get_board_badge_count() -> int:
	return CellEffectRuntime.get_pending_snapshot().size() + (1 if TaskRewardManager.has_pending_reward() else 0)

func _get_ui() -> Node:
	if GlobalVariables == null:
		return null
	var ui := GlobalVariables.ui
	if ui != null and is_instance_valid(ui):
		return ui
	return null

func _place_zone_hint_label(label: Label, zone_id: int, extra_offset: Vector2 = Vector2.ZERO) -> void:
	if label == null or not _is_owner_valid():
		return
	var zone_rect := _owner.call("_get_zone_rect_local", zone_id) as Rect2
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var label_size := label.size
	if label_size.x <= 0.0 or label_size.y <= 0.0:
		label_size = label.get_combined_minimum_size()
	var target_center := zone_rect.get_center() + _zone_hint_forward_offset + extra_offset
	label.position = target_center - label_size * 0.5

func _build_zone_hint_status_signature() -> String:
	var weapon_parts: PackedStringArray = []
	for weapon in _get_owned_weapons_for_upgrade():
		weapon_parts.append("%d:%d" % [int(weapon.level), int(weapon.max_level)])
	return "%d|%d|%d|%d|%d|%s" % [
		int(PlayerData.player_gold),
		InventoryData.temporary_modules.size(),
		CellEffectRuntime.get_inventory_snapshot().size(),
		CellEffectRuntime.get_pending_snapshot().size(),
		1 if TaskRewardManager.has_pending_reward() else 0,
		",".join(weapon_parts),
	]

func _get_affordable_upgrade_count() -> int:
	var count := 0
	for weapon in _get_owned_weapons_for_upgrade():
		if weapon.level >= weapon.max_level:
			continue
		if PlayerData.player_gold >= _get_weapon_upgrade_cost(weapon):
			count += 1
	for module_ref in InventoryData.get_all_owned_modules():
		var module_instance := module_ref as Module
		if module_instance == null or not is_instance_valid(module_instance) or int(module_instance.module_level) >= Module.MAX_LEVEL:
			continue
		if PlayerData.player_gold >= _get_module_upgrade_cost(module_instance):
			count += 1
	return count

func _get_owned_weapons_for_upgrade() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon != null and is_instance_valid(weapon):
			result.append(weapon)
	for weapon in InventoryData.get_stored_weapons():
		if weapon != null and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _get_weapon_upgrade_cost(weapon: Weapon) -> int:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return 1
	if GlobalVariables.economy_data == null:
		return maxi(1, int(round(float(weapon_def.price) * 0.5)))
	return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))

func _get_module_upgrade_cost(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 1
	if GlobalVariables.economy_data == null:
		return maxi(1, int(module_instance.cost))
	return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))

func _style_zone_hint(label: Label, zone_id: int) -> void:
	if label == null or not _is_owner_valid():
		return
	var is_hovered := int(_owner.get("hover_zone_id")) == zone_id
	var is_selected := int(_owner.get("selected_zone_id")) == zone_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.82)
	style.border_color = Color(0.28, 0.42, 0.55, 0.78)
	if is_hovered:
		style.bg_color = Color(0.055, 0.18, 0.26, 0.96)
		style.border_color = _zone_hover_color
	if is_selected:
		style.bg_color = Color(0.045, 0.20, 0.13, 0.96)
		style.border_color = _zone_selected_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 2
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override(
		"font_color",
		Color(0.82, 1.0, 0.88) if is_selected else Color(0.86, 0.95, 1.0)
	)

func _style_battle_hint() -> void:
	if _battle_hint_label == null or not _is_owner_valid():
		return
	var center_zone_id := int(_zone_ids.get("center", 4))
	var is_hovered := int(_owner.get("hover_zone_id")) == center_zone_id
	var is_selected := int(_owner.get("selected_zone_id")) == center_zone_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.075, 0.067, 0.86)
	style.border_color = Color(0.30, 0.65, 0.45, 0.88) if is_selected else Color(0.24, 0.46, 0.39, 0.78)
	if is_hovered:
		style.bg_color = Color(0.035, 0.13, 0.09, 0.94)
		style.border_color = Color(0.40, 0.91, 0.60, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = 2
	_battle_hint_label.add_theme_stylebox_override("normal", style)
	_battle_hint_label.add_theme_color_override(
		"font_color",
		Color(0.94, 1.0, 0.96) if is_hovered else Color(0.86, 0.95, 0.90)
	)

func _is_owner_valid() -> bool:
	return _owner != null and is_instance_valid(_owner)
