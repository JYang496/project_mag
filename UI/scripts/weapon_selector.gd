extends Control
class_name WeaponSelector

@export var debug_mode := false

const DIAMOND_COOLDOWN_PROGRESS_SCRIPT := preload("res://UI/scripts/diamond_cooldown_progress.gd")
const WEAPON_SLOT_STATUS_BAR_SCRIPT := preload("res://UI/scripts/weapon_slot_status_bar.gd")
const WEAPON_SKILL_CHARGE_TRACK_SCRIPT := preload("res://UI/scripts/weapon_skill_charge_track.gd")
const WEAPON_TRIGGER_FEEDBACK_SCRIPT := preload("res://UI/scripts/weapon_trigger_feedback.gd")
const WEAPON_AMMO_COLUMN_SCRIPT := preload("res://UI/scripts/components/weapon_ammo_column.gd")
const READABILITY_PRESENTER_SCRIPT := preload("res://UI/scripts/components/weapon_selector_readability_presenter.gd")
const PASSIVE_PRESENTER_SCRIPT := preload("res://UI/scripts/components/weapon_selector_passive_presenter.gd")
const SLOT_VIEW_SCRIPT := preload("res://UI/scripts/components/weapon_slot_view.gd")
const SWITCH_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/weapon_switch_controller.gd")
const SLOT_COUNT := 4
const SWITCH_ANIM_TIME := 0.35
const SWITCH_ANIM_TRANS := Tween.TRANS_SINE
const SWITCH_ANIM_EASE := Tween.EASE_OUT
const SUPPORT_SLOT_SIZE := Vector2(48.0, 64.0)
const MAINHAND_SLOT_SIZE := Vector2(64.0, 64.0)
const SLOT_GAP := 6.0
const COMPACT_DOCK_SIZE := Vector2(226.0, 64.0)
const VISUAL_FOOTPRINT_SIZE := COMPACT_DOCK_SIZE
const MAINHAND_READY_GLOW_COLOR := Color(0.58, 0.86, 1.0, 1.0)
const SUPPORT_READY_GLOW_COLOR := Color(0.92, 0.92, 0.92, 1.0)
const WEAPON_STATUS_FILL := Color(0.33, 0.66, 1.0, 0.95)
const WEAPON_STATUS_TRACK := Color(0.11, 0.20, 0.25, 0.92)
const WEAPON_STATUS_RELOAD := Color(0.34, 0.78, 0.88, 1.0)
const WEAPON_STATUS_LOW := Color(0.98, 0.58, 0.18, 1.0)
const WEAPON_STATUS_EMPTY := Color(0.94, 0.30, 0.28, 1.0)
const WEAPON_STATUS_EMPTY_TRACK := Color(0.38, 0.08, 0.08, 0.88)
const MAINHAND_AMMO_COLUMN_RECT := Rect2(20.0, -58.0, 16.0, 54.0)
const MAINHAND_AMMO_LABEL_RECT := Rect2(40.0, -27.0, 64.0, 24.0)
const SUPPORT_AVAILABILITY_LABEL_Y := 4.0
const PASSIVE_PROGRESS_COLOR := Color(0.98, 0.78, 0.28, 0.95)
const PASSIVE_PROGRESS_BASE_COLOR := Color(0.98, 0.78, 0.28, 0.18)
const PASSIVE_READY_COLOR := Color(1.0, 0.9, 0.38, 1.0)
const PASSIVE_COOLDOWN_COLOR := Color(0.44, 0.76, 0.92, 0.65)
const PASSIVE_COOLDOWN_BASE_COLOR := Color(0.44, 0.76, 0.92, 0.14)
const PASSIVE_UNAVAILABLE_COLOR := Color(0.48, 0.5, 0.52, 0.34)
const PASSIVE_UNAVAILABLE_BASE_COLOR := Color(0.48, 0.5, 0.52, 0.09)
const PASSIVE_CHARGE_BEAN_FILLED_COLOR := Color(1.0, 0.86, 0.26, 0.98)
const PASSIVE_CHARGE_BEAN_EMPTY_COLOR := Color(0.23, 0.24, 0.26, 0.58)
const PASSIVE_CHARGE_BEAN_OUTLINE_COLOR := Color(0.05, 0.05, 0.05, 0.72)
const PASSIVE_TRIGGER_COLOR := Color(1.0, 0.78, 0.22, 1.0)
const SKILL_READY_COLOR := Color(0.58, 0.90, 1.0, 1.0)
const SKILL_COOLDOWN_COLOR := Color(0.20, 0.62, 0.90, 0.92)
const SKILL_BLOCKED_COLOR := Color(0.86, 0.30, 0.28, 0.92)
const HOLD_SKILL_COLOR := Color(1.0, 0.76, 0.18, 1.0)
const TRIGGER_FEEDBACK_DEBOUNCE_MSEC := 120
@onready var _slot_nodes: Array[Control] = [$Slot0, $Slot1, $Slot2, $Slot3]

var slot_nodes: Array[Control] = []
var logical_order: Array[int] = []

var _queued_step := 0
var _is_animating := false
var _needs_full_refresh := false
var _switch_controller = SWITCH_CONTROLLER_SCRIPT.new()
var _slot_views: Array = []
var _slot_cd_nodes: Array[Control] = []
var _slot_glow_nodes: Array[Control] = []
var _slot_passive_nodes: Array[Control] = []
var _slot_passive_glow_nodes: Array[Control] = []
var _slot_passive_charge_nodes: Array[Control] = []
var _slot_trigger_feedback_nodes: Array[Control] = []
var _slot_resource_indicator_nodes: Array[Label] = []
var _slot_availability_label_nodes: Array[Label] = []
var _slot_skill_nodes: Array[Control] = []
var _slot_hold_nodes: Array[Control] = []
var _slot_key_labels: Array[Label] = []
var _cooldown_overlay: Control
var _mainhand_ammo_column: Control
var _readability_presenter
var _passive_presenter
var _slot_glow_tweens: Dictionary = {}
var _slot_passive_glow_tweens: Dictionary = {}
var _slot_trigger_feedback_tweens: Dictionary = {}
var _slot_track_flash_tweens: Dictionary = {}
var _slot_passive_icon_tweens: Dictionary = {}
var _last_trigger_feedback_msec: Dictionary = {}
var _passive_visual_state_by_weapon: Dictionary = {}
var _availability_visual_state_by_weapon: Dictionary = {}
var _skill_active_state_by_weapon: Dictionary = {}
var _selector_reload_total_by_weapon: Dictionary = {}
var _connected_reload_weapon_ids: Dictionary = {}
var _connected_passive_weapon_ids: Dictionary = {}

var _missing_weapon_icon: Texture2D = preload("res://asset/images/ui/missing_weapon_icon.png")
var _mainhand_slot_bg: Texture2D = preload("res://UI/themes/modern/weapon_slot_main.png")
var _support_slot_bg: Texture2D = preload("res://UI/themes/modern/weapon_slot_support.png")

func _ready() -> void:
	custom_minimum_size = COMPACT_DOCK_SIZE
	size = COMPACT_DOCK_SIZE
	slot_nodes = _slot_nodes.duplicate()
	_slot_views.clear()
	for slot_node in _slot_nodes:
		var slot_view = SLOT_VIEW_SCRIPT.new()
		slot_view.setup(slot_node, _missing_weapon_icon)
		_slot_views.append(slot_view)
	_ensure_cooldown_overlay()
	_ensure_mainhand_ammo_column()
	_ensure_slot_cooldown_nodes()
	_readability_presenter = READABILITY_PRESENTER_SCRIPT.new()
	_readability_presenter.setup(self, _slot_nodes)
	_passive_presenter = PASSIVE_PRESENTER_SCRIPT.new()
	_passive_presenter.setup({
		"ready": PASSIVE_READY_COLOR,
		"cooldown": PASSIVE_COOLDOWN_COLOR,
		"cooldown_base": PASSIVE_COOLDOWN_BASE_COLOR,
		"progress": PASSIVE_PROGRESS_COLOR,
		"progress_base": PASSIVE_PROGRESS_BASE_COLOR,
		"unavailable": PASSIVE_UNAVAILABLE_COLOR,
		"unavailable_base": PASSIVE_UNAVAILABLE_BASE_COLOR,
	})
	_ensure_debug_labels()
	refresh_slots()
	_debug_log_state("ready")

func _process(_delta: float) -> void:
	_sync_trigger_feedback_layout()
	_update_slot_cooldown_progress()
	_update_slot_passive_progress()
	_update_slot_resource_indicators()
	_update_slot_weapon_skill_progress()

func set_layout_origin(origin: Vector2) -> void:
	position = origin

func get_compact_dock_size() -> Vector2:
	return COMPACT_DOCK_SIZE

func get_visual_footprint_size() -> Vector2:
	return VISUAL_FOOTPRINT_SIZE

func bind_player_data() -> void:
	if not PlayerData.is_connected("weapon_list_changed", Callable(self, "_on_weapon_list_changed")):
		PlayerData.weapon_list_changed.connect(Callable(self, "_on_weapon_list_changed"))
	if not PlayerData.is_connected("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed")):
		PlayerData.main_weapon_index_changed.connect(Callable(self, "_on_main_weapon_index_changed"))
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(Callable(self, "_on_language_changed"))

func _on_language_changed(_new_locale: String) -> void:
	refresh_slots()

func refresh_slots() -> void:
	if _is_animating:
		_needs_full_refresh = true
		return
	_ensure_slot_cooldown_nodes()
	var valid_weapons := _sanitize_weapon_list()
	var list_size := valid_weapons.size()
	var main_idx := PlayerData.main_weapon_index
	if list_size <= 0:
		main_idx = -1
	else:
		main_idx = clampi(main_idx, 0, list_size - 1)
	logical_order = _switch_controller.build_fixed_order(list_size, SLOT_COUNT)
	_apply_slot_layout(main_idx)
	_apply_visuals_from_logical_order(valid_weapons)
	_apply_cooldown_visibility_from_logical_order(valid_weapons)
	_update_debug_labels()
	_debug_log_state("refresh_slots")

func animate_main_switch(step: int) -> void:
	var sign_step := signi(step)
	if sign_step == 0:
		refresh_slots()
		return
	if _is_animating:
		if _queued_step == 0:
			_queued_step = sign_step
			_debug_log_state("queued_step_%d" % sign_step)
		return
	var weapons := _sanitize_weapon_list()
	logical_order = _switch_controller.build_fixed_order(weapons.size(), SLOT_COUNT)
	_apply_visuals_from_logical_order(weapons)
	_apply_cooldown_visibility_from_logical_order(weapons)
	_update_debug_labels()

	_is_animating = true
	var target_rects := _build_slot_layout(PlayerData.main_weapon_index)
	_switch_controller.play(
		self,
		_slot_nodes,
		target_rects,
		SWITCH_ANIM_TIME,
		SWITCH_ANIM_TRANS,
		SWITCH_ANIM_EASE,
		Callable(self, "_on_switch_anim_finished").bind(sign_step)
	)
	_debug_log_state("animate_start_step_%d" % sign_step)

func _on_weapon_list_changed() -> void:
	if _is_animating:
		_needs_full_refresh = true
		return
	refresh_slots()

func _on_main_weapon_index_changed(old_index: int, new_index: int, step: int) -> void:
	if old_index == new_index:
		return
	_debug_log_state("signal_main_changed_%d_to_%d_step_%d" % [old_index, new_index, step])
	var sign_step := signi(step)
	if sign_step == 0:
		refresh_slots()
		return
	if _is_animating:
		if _queued_step == 0:
			_queued_step = sign_step
		return
	animate_main_switch(sign_step)

func _on_switch_anim_finished(step: int) -> void:
	_is_animating = false
	_update_debug_labels()
	_debug_log_state("animate_finished_step_%d" % step)

	if _needs_full_refresh:
		_needs_full_refresh = false
		_queued_step = 0
		refresh_slots()
		return

	if _queued_step != 0:
		var pending_step := _queued_step
		_queued_step = 0
		animate_main_switch(pending_step)
		return

	refresh_slots()

func _sanitize_weapon_list() -> Array:
	var valid_weapons: Array = []
	for weapon in PlayerData.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	PlayerData.player_weapon_list = valid_weapons
	return valid_weapons

func _build_slot_layout(main_index: int) -> Array[Rect2]:
	return _switch_controller.build_slot_rects(
		SLOT_COUNT,
		main_index,
		SUPPORT_SLOT_SIZE,
		MAINHAND_SLOT_SIZE,
		SLOT_GAP
	)

func _apply_slot_layout(main_index: int) -> void:
	var target_rects := _build_slot_layout(main_index)
	for slot_idx in range(mini(_slot_nodes.size(), target_rects.size())):
		_slot_nodes[slot_idx].position = target_rects[slot_idx].position
		_slot_nodes[slot_idx].size = target_rects[slot_idx].size

func _apply_visuals_from_logical_order(weapons: Array) -> void:
	_apply_slot_backgrounds_from_logical_order()
	_apply_weapon_icons_from_logical_order(weapons)

func _apply_cooldown_visibility_from_logical_order(weapons: Array) -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		var progress_node := _get_slot_cooldown_node(slot_node)
		var glow_node := _get_slot_glow_node(slot_node)
		if progress_node == null:
			continue
		var weapon_idx := logical_order[slot_idx]
		var has_weapon := weapon_idx >= 0 and weapon_idx < weapons.size() and is_instance_valid(weapons[weapon_idx])
		progress_node.visible = has_weapon
		if not has_weapon:
			progress_node.set("progress", 1.0)
		if glow_node != null:
			glow_node.visible = false

func _apply_slot_backgrounds_from_logical_order() -> void:
	var current_main_index := PlayerData.main_weapon_index
	for slot_idx in range(SLOT_COUNT):
		var slot_view = _slot_views[slot_idx]
		var weapon_idx := logical_order[slot_idx]
		slot_view.set_role(
			weapon_idx >= 0 and weapon_idx == current_main_index,
			_mainhand_slot_bg,
			_support_slot_bg
		)

func _apply_weapon_icons_from_logical_order(weapons: Array) -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		var slot_view = _slot_views[slot_idx]
		var weapon_idx := logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			slot_view.show_empty()
			_readability_presenter.update_slot(slot_idx, null, false)
			continue
		var weapon: Weapon = weapons[weapon_idx] as Weapon
		slot_view.show_weapon(weapon)
		slot_node.tooltip_text = LocalizationManager.get_weapon_instance_display_name(weapon)
		_readability_presenter.update_slot(
			slot_idx,
			weapon,
			weapon_idx == PlayerData.main_weapon_index
		)

func _get_slot_icon(slot_node: Control) -> TextureRect:
	if slot_node == null:
		return null
	var slot_index := _slot_nodes.find(slot_node)
	if slot_index < 0 or slot_index >= _slot_views.size():
		return null
	return _slot_views[slot_index].icon

func _get_slot_background(slot_node: Control) -> TextureRect:
	if slot_node == null:
		return null
	var slot_index := _slot_nodes.find(slot_node)
	if slot_index < 0 or slot_index >= _slot_views.size():
		return null
	return _slot_views[slot_index].background

func _ensure_slot_cooldown_nodes() -> void:
	_ensure_cooldown_overlay()
	if _slot_cd_nodes.size() != SLOT_COUNT:
		_slot_cd_nodes.resize(SLOT_COUNT)
	if _slot_glow_nodes.size() != SLOT_COUNT:
		_slot_glow_nodes.resize(SLOT_COUNT)
	if _slot_passive_nodes.size() != SLOT_COUNT:
		_slot_passive_nodes.resize(SLOT_COUNT)
	if _slot_passive_glow_nodes.size() != SLOT_COUNT:
		_slot_passive_glow_nodes.resize(SLOT_COUNT)
	if _slot_passive_charge_nodes.size() != SLOT_COUNT:
		_slot_passive_charge_nodes.resize(SLOT_COUNT)
	if _slot_trigger_feedback_nodes.size() != SLOT_COUNT:
		_slot_trigger_feedback_nodes.resize(SLOT_COUNT)
	if _slot_resource_indicator_nodes.size() != SLOT_COUNT:
		_slot_resource_indicator_nodes.resize(SLOT_COUNT)
	if _slot_availability_label_nodes.size() != SLOT_COUNT:
		_slot_availability_label_nodes.resize(SLOT_COUNT)
	if _slot_skill_nodes.size() != SLOT_COUNT:
		_slot_skill_nodes.resize(SLOT_COUNT)
	if _slot_hold_nodes.size() != SLOT_COUNT:
		_slot_hold_nodes.resize(SLOT_COUNT)
	if _slot_key_labels.size() != SLOT_COUNT:
		_slot_key_labels.resize(SLOT_COUNT)
	for slot_idx in range(SLOT_COUNT):
		var existing := _slot_cd_nodes[slot_idx]
		if existing != null and is_instance_valid(existing):
			pass
		else:
			var progress_node := WEAPON_SLOT_STATUS_BAR_SCRIPT.new() as Control
			if progress_node != null:
				progress_node.name = "WeaponStatusBar%d" % slot_idx
				progress_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
				progress_node.visible = false
				progress_node.z_index = 0
				_cooldown_overlay.add_child(progress_node)
				_slot_cd_nodes[slot_idx] = progress_node
		if _slot_cd_nodes[slot_idx] != null and is_instance_valid(_slot_cd_nodes[slot_idx]):
			_slot_cd_nodes[slot_idx].set("placement", WeaponSlotStatusBar.Placement.TOP)
			_slot_cd_nodes[slot_idx].set("bar_height", 4.0)
			_slot_cd_nodes[slot_idx].set("top_offset", 8.0)
			_slot_cd_nodes[slot_idx].set("padding", 10.0)
			_slot_cd_nodes[slot_idx].set("ready_edge_color", MAINHAND_READY_GLOW_COLOR)
		_ensure_slot_passive_nodes(slot_idx)
		_ensure_slot_passive_charge_node(slot_idx)
		_ensure_slot_trigger_feedback_node(slot_idx)
		_ensure_slot_resource_indicator_node(slot_idx)
		_ensure_slot_availability_label_node(slot_idx)
		_ensure_slot_skill_nodes(slot_idx)
		var existing_glow := _slot_glow_nodes[slot_idx]
		if existing_glow != null and is_instance_valid(existing_glow):
			continue
		var glow_node := DIAMOND_COOLDOWN_PROGRESS_SCRIPT.new() as Control
		if glow_node == null:
			continue
		glow_node.name = "CooldownDiamondGlow%d" % slot_idx
		glow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_node.visible = false
		glow_node.z_index = 0
		glow_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
		glow_node.set("progress", 1.0)
		glow_node.set("line_width", 7.0)
		glow_node.set("padding", 2.0)
		glow_node.set("base_color", Color(1.0, 1.0, 1.0, 0.0))
		glow_node.set("fill_color", MAINHAND_READY_GLOW_COLOR)
		glow_node.set("clockwise", false)
		glow_node.set("shape_mode", DiamondCooldownProgress.ShapeMode.RECTANGLE)
		_cooldown_overlay.add_child(glow_node)
		_slot_glow_nodes[slot_idx] = glow_node

func _ensure_slot_passive_nodes(slot_idx: int) -> void:
	var existing := _slot_passive_nodes[slot_idx]
	if existing == null or not is_instance_valid(existing):
		var passive_node := WEAPON_SLOT_STATUS_BAR_SCRIPT.new() as Control
		if passive_node != null:
			passive_node.name = "PassiveDiamond%d" % slot_idx
			passive_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			passive_node.visible = false
			passive_node.z_index = 0
			passive_node.modulate = Color(1.0, 1.0, 1.0, 0.92)
			passive_node.set("progress", 0.0)
			passive_node.set("placement", WeaponSlotStatusBar.Placement.TOP)
			passive_node.set("top_offset", 0.0)
			passive_node.set("bar_height", 5.0)
			passive_node.set("line_width", 3.0)
			passive_node.set("padding", 2.0)
			passive_node.set("clockwise", true)
			passive_node.set("shape_mode", DiamondCooldownProgress.ShapeMode.RECTANGLE)
			_cooldown_overlay.add_child(passive_node)
			_slot_passive_nodes[slot_idx] = passive_node
	var existing_glow := _slot_passive_glow_nodes[slot_idx]
	if existing_glow != null and is_instance_valid(existing_glow):
		return
	var passive_glow := DIAMOND_COOLDOWN_PROGRESS_SCRIPT.new() as Control
	if passive_glow == null:
		return
	passive_glow.name = "PassiveFlash%d" % slot_idx
	passive_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_glow.visible = false
	passive_glow.z_index = 0
	passive_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	passive_glow.set("progress", 1.0)
	passive_glow.set("line_width", 5.0)
	passive_glow.set("padding", 10.0)
	passive_glow.set("base_color", Color(1.0, 1.0, 1.0, 0.0))
	passive_glow.set("fill_color", PASSIVE_READY_COLOR)
	passive_glow.set("clockwise", true)
	passive_glow.set("shape_mode", DiamondCooldownProgress.ShapeMode.RECTANGLE)
	_cooldown_overlay.add_child(passive_glow)
	_slot_passive_glow_nodes[slot_idx] = passive_glow

func _ensure_slot_passive_charge_node(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_passive_charge_nodes.size():
		return
	var existing := _slot_passive_charge_nodes[slot_idx]
	if existing != null and is_instance_valid(existing):
		return
	var charge_node := WEAPON_SKILL_CHARGE_TRACK_SCRIPT.new() as Control
	if charge_node == null:
		return
	charge_node.name = "PassiveChargeTrack%d" % slot_idx
	charge_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_node.visible = false
	charge_node.z_index = 0
	charge_node.set("filled_color", PASSIVE_CHARGE_BEAN_FILLED_COLOR)
	charge_node.set("empty_color", PASSIVE_CHARGE_BEAN_EMPTY_COLOR)
	charge_node.set("outline_color", PASSIVE_CHARGE_BEAN_OUTLINE_COLOR)
	_cooldown_overlay.add_child(charge_node)
	_slot_passive_charge_nodes[slot_idx] = charge_node

func _ensure_slot_trigger_feedback_node(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_trigger_feedback_nodes.size():
		return
	var existing := _slot_trigger_feedback_nodes[slot_idx]
	if existing != null and is_instance_valid(existing):
		return
	var feedback := WEAPON_TRIGGER_FEEDBACK_SCRIPT.new() as Control
	if feedback == null:
		return
	feedback.name = "TriggerFeedback%d" % slot_idx
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.visible = false
	feedback.z_index = 4
	_cooldown_overlay.add_child(feedback)
	_slot_trigger_feedback_nodes[slot_idx] = feedback

func _ensure_slot_resource_indicator_node(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_resource_indicator_nodes.size():
		return
	var existing := _slot_resource_indicator_nodes[slot_idx]
	if existing != null and is_instance_valid(existing):
		return
	var label := Label.new()
	label.name = "ResourceIndicator%d" % slot_idx
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	label.z_index = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	_cooldown_overlay.add_child(label)
	_slot_resource_indicator_nodes[slot_idx] = label

func _ensure_slot_availability_label_node(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_availability_label_nodes.size():
		return
	var existing := _slot_availability_label_nodes[slot_idx]
	if existing != null and is_instance_valid(existing):
		return
	var label := Label.new()
	label.name = "WeaponAvailability%d" % slot_idx
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	label.z_index = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	_cooldown_overlay.add_child(label)
	_slot_availability_label_nodes[slot_idx] = label

func _ensure_slot_skill_nodes(slot_idx: int) -> void:
	if _slot_skill_nodes[slot_idx] == null or not is_instance_valid(_slot_skill_nodes[slot_idx]):
		var skill_bar := WEAPON_SLOT_STATUS_BAR_SCRIPT.new() as Control
		skill_bar.name = "WeaponSkillBar%d" % slot_idx
		skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_bar.z_index = 3
		skill_bar.set("placement", WeaponSlotStatusBar.Placement.BOTTOM)
		skill_bar.set("bar_height", 4.0)
		skill_bar.set("padding", 8.0)
		skill_bar.set("base_color", Color(0.05, 0.12, 0.17, 0.92))
		_cooldown_overlay.add_child(skill_bar)
		_slot_skill_nodes[slot_idx] = skill_bar
	if _slot_hold_nodes[slot_idx] == null or not is_instance_valid(_slot_hold_nodes[slot_idx]):
		var hold_bar := WEAPON_SLOT_STATUS_BAR_SCRIPT.new() as Control
		hold_bar.name = "WeaponHoldBar%d" % slot_idx
		hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold_bar.visible = false
		hold_bar.z_index = 4
		hold_bar.set("placement", WeaponSlotStatusBar.Placement.BOTTOM)
		hold_bar.set("bar_height", 3.0)
		hold_bar.set("padding", 2.0)
		hold_bar.set("fill_color", HOLD_SKILL_COLOR)
		hold_bar.set("base_color", Color(0.22, 0.14, 0.03, 0.94))
		_cooldown_overlay.add_child(hold_bar)
		_slot_hold_nodes[slot_idx] = hold_bar
	if _slot_key_labels[slot_idx] == null or not is_instance_valid(_slot_key_labels[slot_idx]):
		var key_label := Label.new()
		key_label.name = "WeaponKeyLabel%d" % slot_idx
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.z_index = 5
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0, 1.0))
		key_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.03, 0.96))
		key_label.add_theme_constant_override("outline_size", 3)
		_cooldown_overlay.add_child(key_label)
		_slot_key_labels[slot_idx] = key_label

func _update_slot_weapon_skill_progress() -> void:
	var weapons: Array = PlayerData.player_weapon_list
	var player: Variant = PlayerData.player
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		var skill_bar := _slot_skill_nodes[slot_idx]
		var hold_bar := _slot_hold_nodes[slot_idx]
		var key_label := _slot_key_labels[slot_idx]
		var weapon_idx := logical_order[slot_idx] if slot_idx < logical_order.size() else -1
		var has_weapon := weapon_idx >= 0 and weapon_idx < weapons.size() and is_instance_valid(weapons[weapon_idx])
		for overlay_node in [skill_bar, hold_bar]:
			overlay_node.position = slot_node.position
			overlay_node.size = slot_node.size
		key_label.position = slot_node.position + Vector2(2.0, slot_node.size.y - 26.0)
		key_label.size = Vector2(18.0, 18.0)
		key_label.text = str(weapon_idx + 1) if has_weapon else ""
		key_label.visible = has_weapon
		if not has_weapon:
			skill_bar.visible = false
			hold_bar.visible = false
			continue
		var weapon := weapons[weapon_idx] as Weapon
		var status: Dictionary = weapon.get_weapon_skill_status()
		_track_weapon_skill_activation(slot_idx, weapon, status)
		skill_bar.visible = bool(status.get("available", true))
		skill_bar.set("progress", float(status.get("cooldown_progress", 1.0)))
		var has_energy := bool(status.get("has_energy", true))
		skill_bar.set("fill_color", SKILL_READY_COLOR if bool(status.get("ready", false)) else (SKILL_COOLDOWN_COLOR if has_energy else SKILL_BLOCKED_COLOR))
		skill_bar.set("ready_edge_color", SKILL_READY_COLOR if bool(status.get("ready", false)) else Color.TRANSPARENT)
		var hold_progress := 0.0
		if player != null and is_instance_valid(player) and player.has_method("get_weapon_slot_hold_progress"):
			hold_progress = float(player.call("get_weapon_slot_hold_progress", weapon_idx))
		hold_bar.visible = hold_progress > 0.0
		hold_bar.set("progress", hold_progress)
		var hold_color := HOLD_SKILL_COLOR
		if hold_progress >= 1.0:
			hold_color = SKILL_READY_COLOR if bool(status.get("ready", false)) else (SKILL_COOLDOWN_COLOR if has_energy else SKILL_BLOCKED_COLOR)
		hold_bar.set("fill_color", hold_color)
		key_label.add_theme_color_override(
			"font_color",
			hold_color if hold_progress > 0.0 else Color(0.88, 0.95, 1.0, 1.0)
		)

func _track_weapon_skill_activation(
	slot_idx: int,
	weapon: Weapon,
	status: Dictionary
) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_id := int(weapon.get_instance_id())
	var is_active := bool(status.get("active", false))
	if not _skill_active_state_by_weapon.has(weapon_id):
		_skill_active_state_by_weapon[weapon_id] = is_active
		return
	var was_active := bool(_skill_active_state_by_weapon.get(weapon_id, false))
	_skill_active_state_by_weapon[weapon_id] = is_active
	if is_active and not was_active:
		# Skill confirmation is HUD-only: it must never request camera trauma.
		_play_slot_trigger_feedback(slot_idx, SKILL_READY_COLOR, true, 0.9)

func _get_slot_cooldown_node(slot_node: Control) -> Control:
	if slot_node == null:
		return null
	var slot_idx := _slot_nodes.find(slot_node)
	if slot_idx < 0 or slot_idx >= _slot_cd_nodes.size():
		return null
	var cached := _slot_cd_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _get_slot_glow_node(slot_node: Control) -> Control:
	if slot_node == null:
		return null
	var slot_idx := _slot_nodes.find(slot_node)
	if slot_idx < 0 or slot_idx >= _slot_glow_nodes.size():
		return null
	var cached := _slot_glow_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _get_slot_passive_node(slot_node: Control) -> Control:
	if slot_node == null:
		return null
	var slot_idx := _slot_nodes.find(slot_node)
	if slot_idx < 0 or slot_idx >= _slot_passive_nodes.size():
		return null
	var cached := _slot_passive_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _get_slot_passive_glow_node(slot_node: Control) -> Control:
	if slot_node == null:
		return null
	var slot_idx := _slot_nodes.find(slot_node)
	if slot_idx < 0 or slot_idx >= _slot_passive_glow_nodes.size():
		return null
	var cached := _slot_passive_glow_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _get_slot_passive_charge_node(slot_node: Control) -> Control:
	if slot_node == null:
		return null
	var slot_idx := _slot_nodes.find(slot_node)
	if slot_idx < 0 or slot_idx >= _slot_passive_charge_nodes.size():
		return null
	var cached := _slot_passive_charge_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _update_slot_cooldown_progress() -> void:
	_sync_cooldown_overlay_layout()
	if _mainhand_ammo_column != null:
		_mainhand_ammo_column.visible = false
	var weapons: Array = PlayerData.player_weapon_list
	var active_weapon_ids: Dictionary = {}
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		var progress_node := _get_slot_cooldown_node(slot_node)
		var glow_node := _get_slot_glow_node(slot_node)
		var availability_label := _get_slot_availability_label_node(slot_idx)
		if progress_node == null:
			continue
		progress_node.position = slot_node.position
		progress_node.size = slot_node.size
		if glow_node != null:
			glow_node.position = slot_node.position
			glow_node.size = slot_node.size
		if _is_animating:
			progress_node.scale = Vector2(0.94, 0.94)
			progress_node.pivot_offset = progress_node.size * 0.5
		else:
			progress_node.scale = Vector2.ONE
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			progress_node.visible = false
			progress_node.set("progress", 1.0)
			if availability_label != null:
				availability_label.visible = false
			if glow_node != null:
				glow_node.visible = false
			continue
		var weapon: Variant = weapons[weapon_idx]
		if weapon == null or not is_instance_valid(weapon):
			progress_node.visible = false
			progress_node.set("progress", 1.0)
			if availability_label != null:
				availability_label.visible = false
			if glow_node != null:
				glow_node.visible = false
			continue
		var weapon_id: int = weapon.get_instance_id()
		active_weapon_ids[weapon_id] = true
		_ensure_weapon_reload_signal_connected(weapon)
		_ensure_weapon_passive_signal_connected(weapon)
		var is_mainhand_weapon := weapon_idx == PlayerData.main_weapon_index
		var visual_state := _resolve_weapon_availability_state(weapon, is_mainhand_weapon)
		if availability_label != null:
			var label_rect := get_weapon_availability_label_rect(slot_node.size, is_mainhand_weapon)
			availability_label.position = slot_node.position + label_rect.position
			availability_label.size = label_rect.size
			availability_label.add_theme_font_size_override("font_size", 14 if is_mainhand_weapon else 12)
		progress_node.visible = bool(visual_state.get("visible", false)) and not is_mainhand_weapon
		progress_node.set("fill_color", visual_state.get("fill_color", WEAPON_STATUS_FILL))
		progress_node.set("base_color", visual_state.get("track_color", WEAPON_STATUS_TRACK))
		progress_node.set("progress", clampf(float(visual_state.get("progress", 0.0)), 0.0, 1.0))
		_apply_weapon_availability_label(availability_label, visual_state, is_mainhand_weapon)
		if is_mainhand_weapon:
			_layout_mainhand_ammo_column(slot_node, visual_state)
		_track_weapon_availability_transition(slot_idx, weapon, visual_state)
	_disconnect_stale_reload_signals(active_weapon_ids)
	_disconnect_stale_passive_signals(active_weapon_ids)

func _update_slot_passive_progress() -> void:
	_sync_cooldown_overlay_layout()
	var weapons: Array = PlayerData.player_weapon_list
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		var passive_node := _get_slot_passive_node(slot_node)
		var passive_glow := _get_slot_passive_glow_node(slot_node)
		var charge_node := _get_slot_passive_charge_node(slot_node)
		if passive_node == null:
			continue
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			passive_node.visible = false
			_set_passive_tag_visible(slot_idx, false)
			if charge_node != null:
				charge_node.visible = false
			continue
		var weapon: Variant = weapons[weapon_idx]
		if weapon == null or not is_instance_valid(weapon):
			passive_node.visible = false
			_set_passive_tag_visible(slot_idx, false)
			if charge_node != null:
				charge_node.visible = false
			continue
		var visual_state: Dictionary = _passive_presenter.resolve_state(weapon)
		_passive_presenter.layout_status(
			passive_node,
			charge_node,
			slot_node,
			visual_state,
			_is_animating
		)
		if passive_glow != null:
			passive_glow.position = passive_node.position
			passive_glow.size = passive_node.size
			passive_glow.pivot_offset = passive_glow.size * 0.5
		var should_show := bool(visual_state.get("visible", true))
		_set_passive_tag_visible(slot_idx, should_show)
		_passive_presenter.apply_status(
			passive_node,
			passive_glow,
			visual_state,
			_is_animating
		)
		_passive_presenter.apply_charge(charge_node, visual_state)
		_track_passive_visual_transition(slot_idx, weapon, visual_state)

func _set_passive_tag_visible(slot_idx: int, visible_value: bool) -> void:
	_readability_presenter.set_passive_visible(slot_idx, visible_value)

func _update_slot_resource_indicators() -> void:
	_sync_cooldown_overlay_layout()
	var weapons: Array = PlayerData.player_weapon_list
	for slot_idx in range(SLOT_COUNT):
		var indicator := _get_slot_resource_indicator_node(slot_idx)
		if indicator == null:
			continue
		var slot_node := _slot_nodes[slot_idx]
		if slot_node == null:
			indicator.visible = false
			continue
		indicator.position = slot_node.position + Vector2(slot_node.size.x - 30.0, -2.0)
		indicator.size = Vector2(30.0, 15.0)
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size() or weapon_idx == PlayerData.main_weapon_index:
			indicator.visible = false
			continue
		var weapon: Variant = weapons[weapon_idx]
		var slot := _select_weapon_indicator_resource(weapon)
		if slot.is_empty():
			indicator.visible = false
			continue
		indicator.visible = true
		indicator.text = _resource_indicator_text(slot)
		_style_resource_indicator(indicator, _resource_indicator_color(slot))

func _get_slot_resource_indicator_node(slot_idx: int) -> Label:
	if slot_idx < 0 or slot_idx >= _slot_resource_indicator_nodes.size():
		return null
	var cached := _slot_resource_indicator_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func _get_slot_availability_label_node(slot_idx: int) -> Label:
	if slot_idx < 0 or slot_idx >= _slot_availability_label_nodes.size():
		return null
	var cached := _slot_availability_label_nodes[slot_idx]
	if cached != null and is_instance_valid(cached):
		return cached
	return null

func get_weapon_availability_label_rect(slot_size: Vector2, is_mainhand: bool) -> Rect2:
	if is_mainhand:
		return MAINHAND_AMMO_LABEL_RECT
	var label_width := 44.0
	var label_x := slot_size.x - label_width - 5.0
	var label_y := SUPPORT_AVAILABILITY_LABEL_Y
	return Rect2(
		Vector2(label_x, label_y),
		Vector2(label_width, 22.0)
	)

func _select_weapon_indicator_resource(weapon: Variant) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {}
	if not weapon.has_method("get_combat_resource_slots"):
		return {}
	var value: Variant = weapon.call("get_combat_resource_slots")
	if not (value is Array):
		return {}
	var best: Dictionary = {}
	for slot in value:
		if not (slot is Dictionary):
			continue
		var slot_dict := slot as Dictionary
		if StringName(str(slot_dict.get("type", ""))) == &"ammo":
			continue
		var state := StringName(str(slot_dict.get("state", "normal")))
		if state == &"normal":
			continue
		if best.is_empty() or int(slot_dict.get("priority", 0)) > int(best.get("priority", 0)):
			best = slot_dict
	return best

func _resource_indicator_text(slot: Dictionary) -> String:
	var state := StringName(str(slot.get("state", "normal")))
	var resource_type := StringName(str(slot.get("type", "")))
	if state == &"locked":
		return "HOT" if resource_type == &"heat" else "LOCK"
	if state == &"reloading":
		return "RLD"
	if state == &"charging":
		return "CHG"
	if state == &"cooling":
		return "COOL"
	if state == &"warning":
		return "LOW" if resource_type == &"ammo" else "!"
	return str(slot.get("short_text", ""))

func _resource_indicator_color(slot: Dictionary) -> Color:
	var state := StringName(str(slot.get("state", "normal")))
	var resource_type := StringName(str(slot.get("type", "")))
	if state == &"locked":
		return Color(1.0, 0.22, 0.16, 1.0)
	if state == &"warning":
		return Color(1.0, 0.62, 0.24, 1.0)
	if state == &"extreme_cold" or state == &"deep_cold" or state == &"cold":
		return Color(0.38, 0.78, 1.0, 1.0)
	if state == &"extreme_heat" or state == &"high_heat" or state == &"hot":
		return Color(1.0, 0.46, 0.22, 1.0)
	if state == &"reloading" or state == &"cooling":
		return Color(0.60, 0.72, 1.0, 1.0)
	if resource_type == &"charge" or state == &"charging":
		return Color(0.58, 0.86, 1.0, 1.0)
	return Color(0.86, 0.9, 0.92, 1.0)

func _style_resource_indicator(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", Color(0.04, 0.05, 0.06, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.9)
	style.border_color = Color(0.02, 0.03, 0.04, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	label.add_theme_stylebox_override("normal", style)

func _apply_weapon_availability_label(label: Label, visual_state: Dictionary, use_capsule: bool = false) -> void:
	if label == null:
		return
	label.remove_theme_stylebox_override("normal")
	if use_capsule:
		var capsule := StyleBoxFlat.new()
		capsule.bg_color = Color(0.015, 0.035, 0.05, 0.88)
		capsule.border_color = Color(0.20, 0.54, 0.64, 0.64)
		capsule.set_border_width_all(1)
		capsule.set_corner_radius_all(2)
		capsule.content_margin_left = 4.0
		capsule.content_margin_right = 4.0
		label.add_theme_stylebox_override("normal", capsule)
	var text := str(visual_state.get("label", ""))
	label.text = text
	label.tooltip_text = str(visual_state.get("tooltip", ""))
	label.visible = not text.is_empty()
	if not label.visible:
		return
	var kind := StringName(str(visual_state.get("kind", "normal")))
	var color: Color = visual_state.get("fill_color", WEAPON_STATUS_FILL)
	if kind == &"normal":
		label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
		return
	label.add_theme_color_override("font_color", color)

func _ensure_cooldown_overlay() -> void:
	if _cooldown_overlay != null and is_instance_valid(_cooldown_overlay):
		return
	_cooldown_overlay = Control.new()
	_cooldown_overlay.name = "CooldownOverlay"
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_overlay.offset_left = 0.0
	_cooldown_overlay.offset_top = 0.0
	_cooldown_overlay.offset_right = 0.0
	_cooldown_overlay.offset_bottom = 0.0
	# Keep the ring branch on the selector's own draw layer so it cannot cover sibling UI.
	_cooldown_overlay.z_index = 0
	add_child(_cooldown_overlay)

func _ensure_mainhand_ammo_column() -> void:
	if _mainhand_ammo_column != null and is_instance_valid(_mainhand_ammo_column):
		return
	_ensure_cooldown_overlay()
	_mainhand_ammo_column = WEAPON_AMMO_COLUMN_SCRIPT.new() as Control
	_mainhand_ammo_column.name = "MainhandAmmoColumn"
	_mainhand_ammo_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mainhand_ammo_column.visible = false
	_mainhand_ammo_column.z_index = 2
	_cooldown_overlay.add_child(_mainhand_ammo_column)

func get_mainhand_ammo_column_rect(_slot_size: Vector2) -> Rect2:
	return MAINHAND_AMMO_COLUMN_RECT

func _layout_mainhand_ammo_column(slot_node: Control, visual_state: Dictionary) -> void:
	_ensure_mainhand_ammo_column()
	if _mainhand_ammo_column == null or slot_node == null:
		return
	var column_rect := get_mainhand_ammo_column_rect(slot_node.size)
	_mainhand_ammo_column.position = slot_node.position + column_rect.position
	_mainhand_ammo_column.size = column_rect.size
	_mainhand_ammo_column.visible = bool(visual_state.get("visible", false))
	if not _mainhand_ammo_column.visible:
		return
	_mainhand_ammo_column.call(
		"set_ammo_state",
		clampf(float(visual_state.get("progress", 0.0)), 0.0, 1.0),
		visual_state.get("fill_color", WEAPON_STATUS_FILL),
		visual_state.get("track_color", WEAPON_STATUS_TRACK)
	)

func _sync_cooldown_overlay_layout() -> void:
	if _cooldown_overlay == null or not is_instance_valid(_cooldown_overlay):
		return
	_cooldown_overlay.position = Vector2.ZERO
	_cooldown_overlay.size = size

func _sync_trigger_feedback_layout() -> void:
	for slot_idx in range(mini(_slot_nodes.size(), _slot_trigger_feedback_nodes.size())):
		var feedback := _slot_trigger_feedback_nodes[slot_idx]
		var slot := _slot_nodes[slot_idx]
		if feedback == null or not is_instance_valid(feedback) or slot == null:
			continue
		feedback.position = slot.position
		feedback.size = slot.size
		feedback.pivot_offset = feedback.size * 0.5

func _resolve_weapon_availability_state(weapon: Variant, is_mainhand: bool) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {"visible": false, "kind": &"unavailable"}
	if not weapon.has_method("get_ammo_status"):
		return {"visible": false, "kind": &"unavailable"}
	var status_variant: Variant = weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		return {"visible": false, "kind": &"unavailable"}
	var status := status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		return {"visible": false, "kind": &"infinite"}
	var weapon_id := int(weapon.get_instance_id())
	var current := maxf(float(status.get("current", 0.0)), 0.0)
	var max_ammo := maxf(float(status.get("max", 0.0)), 0.0)
	if max_ammo <= 0.0:
		return {"visible": false, "kind": &"unavailable"}
	var is_reloading := bool(status.get("is_reloading", false))
	var reload_left := maxf(float(status.get("reload_left", 0.0)), 0.0)
	var tooltip := "Ammo: %d/%d" % [int(current), int(max_ammo)]
	if is_reloading:
		var tracked_total := maxf(float(status.get("reload_total", 0.0)), 0.0)
		if tracked_total <= 0.0:
			tracked_total = float(_selector_reload_total_by_weapon.get(weapon_id, 0.0))
		if tracked_total <= 0.0 or reload_left > tracked_total:
			tracked_total = reload_left
		tracked_total = maxf(tracked_total, reload_left)
		_selector_reload_total_by_weapon[weapon_id] = tracked_total
		var reload_progress := 0.0
		if tracked_total > 0.0001:
			reload_progress = clampf(1.0 - (reload_left / tracked_total), 0.0, 1.0)
		return {
			"visible": true,
			"kind": &"reloading",
			"progress": reload_progress,
			"fill_color": WEAPON_STATUS_RELOAD,
			"label": "RLD %.1f" % reload_left if is_mainhand else "RLD",
			"tooltip": "%s (Reloading %.1fs)" % [tooltip, reload_left],
		}
	_selector_reload_total_by_weapon.erase(weapon_id)
	var ammo_progress := clampf(current / max_ammo, 0.0, 1.0)
	if current <= 0.0:
		return {
			"visible": true,
			"kind": &"empty",
			"progress": 0.0,
			"fill_color": WEAPON_STATUS_EMPTY,
			"track_color": WEAPON_STATUS_EMPTY_TRACK,
			"label": "0/%d" % int(max_ammo) if is_mainhand else "0",
			"tooltip": tooltip,
		}
	var low_threshold := maxf(1.0, ceil(max_ammo * 0.25))
	if current <= low_threshold:
		var critical_threshold := maxf(1.0, ceil(max_ammo * 0.125))
		return {
			"visible": true,
			"kind": &"low",
			"progress": ammo_progress,
			"fill_color": WEAPON_STATUS_EMPTY if current <= critical_threshold else WEAPON_STATUS_LOW,
			"label": "%d/%d" % [int(current), int(max_ammo)] if is_mainhand else "LOW",
			"tooltip": tooltip,
		}
	return {
		"visible": true,
		"kind": &"normal",
		"progress": ammo_progress,
		"fill_color": WEAPON_STATUS_FILL,
		"label": "%d/%d" % [int(current), int(max_ammo)] if is_mainhand else "",
		"tooltip": tooltip,
	}

func _ensure_weapon_reload_signal_connected(weapon: Variant) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_signal("weapon_reload_completed"):
		return
	var weapon_id := int(weapon.get_instance_id())
	if _connected_reload_weapon_ids.has(weapon_id):
		return
	var callable := Callable(self, "_on_weapon_reload_completed")
	if not weapon.is_connected("weapon_reload_completed", callable):
		weapon.connect("weapon_reload_completed", callable)
	_connected_reload_weapon_ids[weapon_id] = true

func _disconnect_stale_reload_signals(active_weapon_ids: Dictionary) -> void:
	var stale_ids: Array = []
	for key in _connected_reload_weapon_ids.keys():
		var weapon_id := int(key)
		if active_weapon_ids.has(weapon_id):
			continue
		stale_ids.append(weapon_id)
	for weapon_id in stale_ids:
		var stale_weapon := instance_from_id(weapon_id)
		if stale_weapon != null and is_instance_valid(stale_weapon):
			var callable := Callable(self, "_on_weapon_reload_completed")
			if stale_weapon.is_connected("weapon_reload_completed", callable):
				stale_weapon.disconnect("weapon_reload_completed", callable)
		_connected_reload_weapon_ids.erase(weapon_id)
		_selector_reload_total_by_weapon.erase(weapon_id)
		_availability_visual_state_by_weapon.erase(weapon_id)
		_skill_active_state_by_weapon.erase(weapon_id)

func _ensure_weapon_passive_signal_connected(weapon: Variant) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_id := int(weapon.get_instance_id())
	if _connected_passive_weapon_ids.has(weapon_id):
		return
	var connected_any := false
	if weapon.has_signal("passive_triggered"):
		var passive_callable := Callable(self, "_on_weapon_passive_triggered").bind(weapon_id)
		if not weapon.is_connected("passive_triggered", passive_callable):
			weapon.connect("passive_triggered", passive_callable)
		connected_any = true
	if not connected_any:
		return
	_connected_passive_weapon_ids[weapon_id] = true

func _disconnect_stale_passive_signals(active_weapon_ids: Dictionary) -> void:
	var stale_ids: Array = []
	for key in _connected_passive_weapon_ids.keys():
		var weapon_id := int(key)
		if active_weapon_ids.has(weapon_id):
			continue
		stale_ids.append(weapon_id)
	for weapon_id in stale_ids:
		var stale_weapon := instance_from_id(weapon_id)
		if stale_weapon != null and is_instance_valid(stale_weapon):
			var passive_callable := Callable(self, "_on_weapon_passive_triggered").bind(weapon_id)
			if stale_weapon.has_signal("passive_triggered") \
					and stale_weapon.is_connected("passive_triggered", passive_callable):
				stale_weapon.disconnect("passive_triggered", passive_callable)
		_connected_passive_weapon_ids.erase(weapon_id)
		_passive_visual_state_by_weapon.erase(weapon_id)

func _on_weapon_passive_triggered(event_name: StringName, detail: Dictionary, weapon_id: int) -> void:
	var weapon := instance_from_id(weapon_id)
	if weapon == null or not is_instance_valid(weapon):
		return
	if not _should_play_passive_trigger_feedback(weapon, event_name, detail):
		return
	var slot_idx := _find_slot_index_for_node(weapon as Node)
	if slot_idx < 0:
		return
	if not _can_play_trigger_feedback(slot_idx):
		return
	_play_passive_glow(slot_idx)
	_play_slot_trigger_feedback(slot_idx, PASSIVE_TRIGGER_COLOR, true)
	_play_passive_track_flash(slot_idx)
	_pulse_passive_icon(slot_idx)

func _should_play_passive_trigger_feedback(
	weapon: Variant,
	event_name: StringName,
	detail: Dictionary
) -> bool:
	if weapon == null or not is_instance_valid(weapon) \
			or not weapon.has_method("get_passive_status"):
		return false
	var passive_status: Dictionary = weapon.call("get_passive_status")
	var displayed_passive_id := str(passive_status.get("id", ""))
	if displayed_passive_id.is_empty():
		return false
	return str(event_name) == displayed_passive_id \
		or str(detail.get("passive_id", "")) == displayed_passive_id

func _can_play_trigger_feedback(slot_idx: int) -> bool:
	var now := Time.get_ticks_msec()
	var previous := int(_last_trigger_feedback_msec.get(slot_idx, -TRIGGER_FEEDBACK_DEBOUNCE_MSEC))
	if now - previous < TRIGGER_FEEDBACK_DEBOUNCE_MSEC:
		return false
	_last_trigger_feedback_msec[slot_idx] = now
	return true

func _on_weapon_reload_completed(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var slot_idx := _find_slot_index_for_weapon(weapon)
	if slot_idx < 0:
		return
	var is_mainhand_weapon := false
	if slot_idx < logical_order.size():
		is_mainhand_weapon = logical_order[slot_idx] == PlayerData.main_weapon_index
	_play_ready_glow(slot_idx, is_mainhand_weapon)

func _find_slot_index_for_weapon(weapon: Weapon) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return -1
	var weapons: Array = PlayerData.player_weapon_list
	for slot_idx in range(SLOT_COUNT):
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			continue
		if weapons[weapon_idx] == weapon:
			return slot_idx
	return -1

func _find_slot_index_for_node(weapon: Node) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return -1
	var weapons: Array = PlayerData.player_weapon_list
	for slot_idx in range(SLOT_COUNT):
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			continue
		if weapons[weapon_idx] == weapon:
			return slot_idx
	return -1

func _track_passive_visual_transition(slot_idx: int, weapon: Variant, visual_state: Dictionary) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_id := int(weapon.get_instance_id())
	var kind := str(visual_state.get("kind", "unavailable"))
	var is_ready := bool(visual_state.get("ready", false))
	var previous := str(_passive_visual_state_by_weapon.get(weapon_id, ""))
	var previous_ready := previous == "ready"
	_passive_visual_state_by_weapon[weapon_id] = "ready" if is_ready else kind
	if is_ready and previous != "" and not previous_ready:
		_play_passive_ready_glow(slot_idx)
		_play_slot_trigger_feedback(slot_idx, SKILL_READY_COLOR, false, 0.38)

func _track_weapon_availability_transition(slot_idx: int, weapon: Variant, visual_state: Dictionary) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_id := int(weapon.get_instance_id())
	var next_kind := StringName(str(visual_state.get("kind", "unavailable")))
	var previous_kind := StringName(str(_availability_visual_state_by_weapon.get(weapon_id, "")))
	_availability_visual_state_by_weapon[weapon_id] = next_kind
	if previous_kind == &"" or previous_kind == next_kind:
		return
	if next_kind == &"low" and previous_kind == &"normal":
		_play_weapon_status_alert(slot_idx, WEAPON_STATUS_LOW)
	elif next_kind == &"empty":
		_play_weapon_status_alert(slot_idx, WEAPON_STATUS_EMPTY)

func _play_slot_trigger_feedback(
	slot_idx: int,
	color: Color,
	scale_pulse: bool,
	peak_intensity: float = 1.0
) -> void:
	if slot_idx < 0 or slot_idx >= _slot_trigger_feedback_nodes.size():
		return
	var feedback := _slot_trigger_feedback_nodes[slot_idx]
	if feedback == null or not is_instance_valid(feedback):
		return
	var existing: Tween = _slot_trigger_feedback_tweens.get(slot_idx, null) as Tween
	if existing != null and is_instance_valid(existing):
		existing.kill()
	feedback.visible = true
	feedback.set("feedback_color", color)
	feedback.set("intensity", 0.0)
	feedback.scale = Vector2(0.96, 0.96) if scale_pulse else Vector2.ONE
	var tween := create_tween()
	_slot_trigger_feedback_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(feedback, "intensity", clampf(peak_intensity, 0.0, 1.0), 0.06)
	if scale_pulse:
		tween.tween_property(feedback, "scale", Vector2(1.04, 1.04), 0.12)
	tween.set_parallel(false)
	tween.tween_property(feedback, "intensity", 0.0, 0.18)
	tween.parallel().tween_property(feedback, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func() -> void:
		if feedback != null and is_instance_valid(feedback):
			feedback.visible = false
			feedback.scale = Vector2.ONE
			_slot_trigger_feedback_tweens.erase(slot_idx)
	)

func _play_passive_track_flash(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_passive_charge_nodes.size():
		return
	var track := _slot_passive_charge_nodes[slot_idx]
	if track == null or not is_instance_valid(track) or not track.visible:
		return
	var existing: Tween = _slot_track_flash_tweens.get(slot_idx, null) as Tween
	if existing != null and is_instance_valid(existing):
		existing.kill()
	track.set("trigger_flash", 1.0)
	var tween := create_tween()
	_slot_track_flash_tweens[slot_idx] = tween
	tween.tween_property(track, "trigger_flash", 0.0, 0.22)
	tween.finished.connect(func() -> void:
		if track != null and is_instance_valid(track):
			track.set("trigger_flash", 0.0)
			_slot_track_flash_tweens.erase(slot_idx)
	)

func _pulse_passive_icon(slot_idx: int) -> void:
	var icon: Control = _readability_presenter.get_passive_icon(slot_idx)
	if icon == null or not icon.visible:
		return
	var existing: Tween = _slot_passive_icon_tweens.get(slot_idx, null) as Tween
	if existing != null and is_instance_valid(existing):
		existing.kill()
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2.ONE
	var tween := create_tween()
	_slot_passive_icon_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2(1.22, 1.22), 0.10)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.20)
	tween.finished.connect(func() -> void:
		if icon != null and is_instance_valid(icon):
			icon.scale = Vector2.ONE
			_slot_passive_icon_tweens.erase(slot_idx)
	)

func _play_ready_glow(slot_idx: int, is_mainhand_weapon: bool) -> void:
	if slot_idx < 0 or slot_idx >= _slot_glow_nodes.size():
		return
	var glow_node := _slot_glow_nodes[slot_idx]
	if glow_node == null or not is_instance_valid(glow_node):
		return
	var existing_tween: Tween = _slot_glow_tweens.get(slot_idx, null) as Tween
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	glow_node.visible = true
	glow_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow_node.scale = Vector2.ONE
	glow_node.pivot_offset = glow_node.size * 0.5
	glow_node.set("fill_color", MAINHAND_READY_GLOW_COLOR if is_mainhand_weapon else SUPPORT_READY_GLOW_COLOR)
	var tween := create_tween()
	_slot_glow_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(glow_node, "modulate:a", 0.95, 0.08)
	tween.tween_property(glow_node, "scale", Vector2(1.12, 1.12), 0.12)
	tween.set_parallel(false)
	tween.tween_property(glow_node, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(glow_node, "scale", Vector2(1.02, 1.02), 0.35)
	tween.finished.connect(func() -> void:
		if glow_node != null and is_instance_valid(glow_node):
			glow_node.visible = false
			glow_node.scale = Vector2.ONE
		_slot_glow_tweens.erase(slot_idx)
	)

func _play_weapon_status_alert(slot_idx: int, color: Color) -> void:
	if slot_idx < 0 or slot_idx >= _slot_glow_nodes.size():
		return
	var glow_node := _slot_glow_nodes[slot_idx]
	if glow_node == null or not is_instance_valid(glow_node):
		return
	var existing_tween: Tween = _slot_glow_tweens.get(slot_idx, null) as Tween
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	glow_node.visible = true
	glow_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow_node.scale = Vector2.ONE
	glow_node.pivot_offset = glow_node.size * 0.5
	glow_node.set("fill_color", color)
	var tween := create_tween()
	_slot_glow_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(glow_node, "modulate:a", 0.82, 0.06)
	tween.tween_property(glow_node, "scale", Vector2(1.06, 1.06), 0.10)
	tween.set_parallel(false)
	tween.tween_property(glow_node, "modulate:a", 0.0, 0.24)
	tween.parallel().tween_property(glow_node, "scale", Vector2.ONE, 0.24)
	tween.finished.connect(func() -> void:
		if glow_node != null and is_instance_valid(glow_node):
			glow_node.visible = false
			glow_node.scale = Vector2.ONE
		_slot_glow_tweens.erase(slot_idx)
	)

func _play_passive_glow(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_passive_glow_nodes.size():
		return
	var glow_node := _slot_passive_glow_nodes[slot_idx]
	if glow_node == null or not is_instance_valid(glow_node):
		return
	var existing_tween: Tween = _slot_passive_glow_tweens.get(slot_idx, null) as Tween
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	glow_node.visible = true
	glow_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow_node.scale = Vector2(0.9, 0.9)
	glow_node.pivot_offset = glow_node.size * 0.5
	glow_node.set("fill_color", PASSIVE_READY_COLOR)
	var tween := create_tween()
	_slot_passive_glow_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(glow_node, "modulate:a", 0.95, 0.06)
	tween.tween_property(glow_node, "scale", Vector2(1.18, 1.18), 0.14)
	tween.set_parallel(false)
	tween.tween_property(glow_node, "modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(glow_node, "scale", Vector2(1.04, 1.04), 0.28)
	tween.finished.connect(func() -> void:
		if glow_node != null and is_instance_valid(glow_node):
			glow_node.visible = false
			glow_node.scale = Vector2.ONE
		_slot_passive_glow_tweens.erase(slot_idx)
	)

func _play_passive_ready_glow(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_passive_glow_nodes.size():
		return
	var glow_node := _slot_passive_glow_nodes[slot_idx]
	if glow_node == null or not is_instance_valid(glow_node):
		return
	var existing_tween: Tween = _slot_passive_glow_tweens.get(slot_idx, null) as Tween
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	glow_node.visible = true
	glow_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow_node.scale = Vector2(0.96, 0.96)
	glow_node.pivot_offset = glow_node.size * 0.5
	glow_node.set("fill_color", Color(1.0, 1.0, 1.0, 0.82))
	var tween := create_tween()
	_slot_passive_glow_tweens[slot_idx] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(glow_node, "modulate:a", 0.38, 0.08)
	tween.tween_property(glow_node, "scale", Vector2(1.06, 1.06), 0.14)
	tween.set_parallel(false)
	tween.tween_property(glow_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(glow_node, "scale", Vector2.ONE, 0.3)
	tween.finished.connect(func() -> void:
		if glow_node != null and is_instance_valid(glow_node):
			glow_node.visible = false
			glow_node.scale = Vector2.ONE
		_slot_passive_glow_tweens.erase(slot_idx)
	)

func _ensure_debug_labels() -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		if slot_node == null:
			continue
		var label := slot_node.get_node_or_null("DebugIndex") as Label
		if label == null:
			label = Label.new()
			label.name = "DebugIndex"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(-20.0, -10.0)
			label.size = Vector2(40.0, 20.0)
			slot_node.add_child(label)
		label.visible = debug_mode

func _update_debug_labels() -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		if slot_node == null:
			continue
		var label := slot_node.get_node_or_null("DebugIndex") as Label
		if label == null:
			continue
		label.visible = debug_mode
		if not debug_mode:
			continue
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		label.text = str(weapon_idx) if weapon_idx >= 0 else "-"
		label.modulate = Color(1.0, 0.95, 0.2) if weapon_idx == PlayerData.main_weapon_index else Color(0.9, 0.9, 0.9)

func _debug_log_state(tag: String) -> void:
	if not debug_mode:
		return
	var weapons_desc: Array[String] = []
	for i in range(PlayerData.player_weapon_list.size()):
		var weapon: Variant = PlayerData.player_weapon_list[i]
		var item_name := "null"
		if is_instance_valid(weapon):
			var name_variant: Variant = weapon.get("ITEM_NAME")
			item_name = str(name_variant) if name_variant != null else str(weapon.name)
		weapons_desc.append("%d:%s" % [i, item_name])

	var slot_desc: Array[String] = []
	for slot_idx in range(SLOT_COUNT):
		var node_idx := _slot_nodes.find(_slot_nodes[slot_idx])
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		var pos: Vector2 = _slot_nodes[slot_idx].position
		slot_desc.append("slot%d(node=%d,w=%d,pos=%.1f,%.1f)" % [slot_idx, node_idx, weapon_idx, pos.x, pos.y])

	print("[WeaponSelector][%s] main=%d queued=%d anim=%s weapons=[%s] logical=%s slots=[%s]" % [
		tag,
		PlayerData.main_weapon_index,
		_queued_step,
		str(_is_animating),
		", ".join(weapons_desc),
		str(logical_order),
		", ".join(slot_desc)
	])

func _exit_tree() -> void:
	_switch_controller.stop()
	_disconnect_stale_reload_signals({})
	_disconnect_stale_passive_signals({})
