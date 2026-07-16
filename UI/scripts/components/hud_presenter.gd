extends RefCounted
class_name HudPresenter

var hp_bar: ProgressBar
var hp_label_text: Label
var heat_label: Label
var ammo_label: Label
var weapon_state_label: Label
var gold_label: Label
var resource_label: Label
var time_label: Control
var battle_time_meter: Control
var equipped_label: Label
var augments_label: Label
var health_meter
var energy_meter
var primary_resource_meter
var ammo_resource_meter
var combat_resource_slot_container: VBoxContainer
var special_resource_slot_container: Control
var character_hud_root: Control

const HUD_MARGIN := 16.0
const CONTINUOUS_REFRESH_INTERVAL := 0.1
const COMBAT_RESOURCE_ORIGIN := Vector2(64.0, 88.0)
const COMBAT_RESOURCE_WIDTH := 192.0
const SPECIAL_RESOURCE_OFFSET := Vector2(96.0, 76.0)
const SPECIAL_RESOURCE_OPACITY := 0.62
const HEALTH_METER_ORIGIN := Vector2(38.0, 16.0)
const COMBAT_RESOURCE_METER_SCRIPT := preload("res://UI/scripts/components/combat_resource_meter.gd")
const PLAYER_HEALTH_METER_SCRIPT := preload("res://UI/scripts/components/player_health_meter.gd")
const SKILL_ENERGY_METER_SCRIPT := preload("res://UI/scripts/components/skill_energy_meter.gd")
const BATTLE_TIME_METER_SCRIPT := preload("res://UI/scripts/components/battle_time_meter.gd")

var _continuous_refresh_timer := 0.0

var _hp_bar_display_value: float = 0.0
var _hp_bar_tween: Tween
var _last_hp_text: String = ""
var _last_heat_label_text: String = ""
var _last_ammo_label_text: String = ""
var _last_weapon_state_text: String = ""
var _last_gold_text: String = ""
var _last_resource_text: String = ""
var _last_time_text: String = ""
var _last_augments_text: String = ""
var _last_energy_signature: String = ""

var _hp_bar_anim_time: float = 0.2
var _hp_bar_trans: Tween.TransitionType = Tween.TRANS_SINE
var _hp_bar_ease: Tween.EaseType = Tween.EASE_OUT

func bind_nodes(
	p_hp_bar: ProgressBar,
	p_hp_label_text: Label,
	p_heat_label: Label,
	p_ammo_label: Label,
	p_weapon_state_label: Label,
	p_gold_label: Label,
	p_resource_label: Label,
	p_time_label: Control,
	p_equipped_label: Label,
	p_augments_label: Label
) -> void:
	hp_bar = p_hp_bar
	hp_label_text = p_hp_label_text
	heat_label = p_heat_label
	ammo_label = p_ammo_label
	weapon_state_label = p_weapon_state_label
	gold_label = p_gold_label
	resource_label = p_resource_label
	time_label = p_time_label
	equipped_label = p_equipped_label
	augments_label = p_augments_label
	_ensure_battle_time_meter()

func configure_hp_bar_anim(anim_time: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_hp_bar_anim_time = anim_time
	_hp_bar_trans = trans
	_hp_bar_ease = ease_type

func layout_hud(viewport_size: Vector2, hp_label_root: Control, weapon_selector: WeaponSelector = null) -> void:
	if equipped_label and is_instance_valid(equipped_label):
		equipped_label.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.set_layout_origin(Vector2(HUD_MARGIN + 12.0, HUD_MARGIN - 2.0))
	if hp_label_root and is_instance_valid(hp_label_root):
		var dock_height := hp_label_root.size.y * hp_label_root.scale.y
		if dock_height <= 0.0:
			dock_height = 108.0
		hp_label_root.position = Vector2(HUD_MARGIN, viewport_size.y - dock_height - HUD_MARGIN)
	if weapon_state_label and is_instance_valid(weapon_state_label):
		weapon_state_label.position = Vector2(HUD_MARGIN, viewport_size.y - 300.0)
	var time_display := _get_time_display_control()
	if time_display and is_instance_valid(time_display):
		time_display.position = Vector2(viewport_size.x * 0.5 - 58.0, HUD_MARGIN + 22.0)
	if gold_label and is_instance_valid(gold_label):
		var timer_left := viewport_size.x * 0.5 - 58.0
		gold_label.position = Vector2(timer_left - gold_label.size.x - 18.0, HUD_MARGIN + 8.0)
	if resource_label and is_instance_valid(resource_label):
		resource_label.position = Vector2(64.0, 88.0)
	if combat_resource_slot_container and is_instance_valid(combat_resource_slot_container):
		combat_resource_slot_container.position = COMBAT_RESOURCE_ORIGIN
	if special_resource_slot_container and is_instance_valid(special_resource_slot_container):
		special_resource_slot_container.position = viewport_size * 0.5 + SPECIAL_RESOURCE_OFFSET

func ensure_heat_label(character_root: Control) -> Label:
	character_hud_root = character_root
	if heat_label != null and is_instance_valid(heat_label):
		heat_label.visible = false
		return heat_label
	heat_label = Label.new()
	heat_label.name = "Heat"
	heat_label.text = ""
	heat_label.visible = false
	heat_label.custom_minimum_size = Vector2(156.0, 26.0)
	character_root.add_child(heat_label)
	return heat_label

func ensure_ammo_label(hp_label_root: Control) -> Label:
	_ensure_combat_resource_slot_container(hp_label_root)
	if ammo_label != null and is_instance_valid(ammo_label):
		ammo_label.visible = false
		return ammo_label
	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = ""
	ammo_label.visible = false
	ammo_label.custom_minimum_size = Vector2(128.0, 24.0)
	return ammo_label

func ensure_resource_label_under_hp(current_resource_label: Label, hp_label_root: Control) -> Label:
	resource_label = current_resource_label
	if resource_label == null or not is_instance_valid(resource_label):
		return resource_label
	if hp_label_root == null or not is_instance_valid(hp_label_root):
		return resource_label
	resource_label.visible = false
	resource_label.text = ""
	if resource_label.get_parent() == hp_label_root:
		_ensure_energy_meter_under_hp(hp_label_root)
		return resource_label
	var previous_parent := resource_label.get_parent()
	if previous_parent:
		previous_parent.remove_child(resource_label)
	hp_label_root.add_child(resource_label)
	_ensure_energy_meter_under_hp(hp_label_root)
	return resource_label

func _ensure_energy_meter_under_hp(hp_label_root: Control) -> void:
	_ensure_combat_resource_slot_container(hp_label_root)
	if energy_meter != null and is_instance_valid(energy_meter):
		if energy_meter.get_parent() != combat_resource_slot_container:
			var current_parent: Node = energy_meter.get_parent()
			if current_parent:
				current_parent.remove_child(energy_meter)
			combat_resource_slot_container.add_child(energy_meter)
		return
	energy_meter = SKILL_ENERGY_METER_SCRIPT.new()
	energy_meter.name = "SkillEnergyMeter"
	energy_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_resource_slot_container.add_child(energy_meter)

func _ensure_combat_resource_slot_container(hp_label_root: Control) -> void:
	if hp_label_root == null or not is_instance_valid(hp_label_root):
		return
	if combat_resource_slot_container != null and is_instance_valid(combat_resource_slot_container):
		if combat_resource_slot_container.get_parent() != hp_label_root:
			var previous_parent := combat_resource_slot_container.get_parent()
			if previous_parent:
				previous_parent.remove_child(combat_resource_slot_container)
			hp_label_root.add_child(combat_resource_slot_container)
		return
	combat_resource_slot_container = VBoxContainer.new()
	combat_resource_slot_container.name = "CombatResourceSlots"
	combat_resource_slot_container.position = COMBAT_RESOURCE_ORIGIN
	combat_resource_slot_container.custom_minimum_size = Vector2(COMBAT_RESOURCE_WIDTH, 0.0)
	combat_resource_slot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_resource_slot_container.add_theme_constant_override("separation", 5)
	hp_label_root.add_child(combat_resource_slot_container)

func ensure_weapon_state_label(character_root: Control) -> Label:
	if weapon_state_label != null and is_instance_valid(weapon_state_label):
		return weapon_state_label
	weapon_state_label = Label.new()
	weapon_state_label.name = "WeaponState"
	weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | PS: --")
	weapon_state_label.visible = false
	weapon_state_label.custom_minimum_size = Vector2(168.0, 24.0)
	character_root.add_child(weapon_state_label)
	return weapon_state_label

func init_hp_bar() -> void:
	_ensure_health_meter()
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	var current_hp: int = clampi(int(PlayerData.player_hp), 0, max_hp)
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(current_hp)
	_hp_bar_display_value = hp_bar.value
	hp_bar.visible = false
	if hp_label_text and is_instance_valid(hp_label_text):
		hp_label_text.visible = false
		hp_label_text.text = ""
	if health_meter != null and is_instance_valid(health_meter):
		health_meter.call("set_health", current_hp, max_hp)

func refresh_static_texts() -> void:
	_clear_text_cache()
	if equipped_label and is_instance_valid(equipped_label):
		equipped_label.text = LocalizationManager.tr_key("ui.hud.equipped", "Equipped:")

func refresh_dynamic_texts() -> void:
	refresh_hp()
	refresh_heat()
	refresh_ammo()
	refresh_weapon_state()
	refresh_inventory()
	refresh_resource()
	refresh_time()

func refresh_continuous(delta: float) -> bool:
	_continuous_refresh_timer += maxf(delta, 0.0)
	if _continuous_refresh_timer < CONTINUOUS_REFRESH_INTERVAL:
		return false
	_continuous_refresh_timer = 0.0
	refresh_heat()
	refresh_ammo()
	refresh_weapon_state()
	refresh_resource()
	refresh_time()
	return true

func refresh_hp() -> void:
	_refresh_hp_hud()

func refresh_heat() -> void:
	_update_heat_label_text()

func refresh_ammo() -> void:
	_sync_ammo_resource_slot(_find_resource_slot(_collect_primary_weapon_resource_slots(), &"ammo"))

func refresh_weapon_state() -> void:
	_update_weapon_state_label_text()

func refresh_inventory() -> void:
	_refresh_inventory_text_values()

func refresh_resource() -> void:
	_refresh_resource_text_value()

func refresh_time() -> void:
	_refresh_time_text_value()

func _ensure_battle_time_meter() -> Control:
	if battle_time_meter != null and is_instance_valid(battle_time_meter):
		return battle_time_meter
	if time_label == null or not is_instance_valid(time_label):
		return null
	if time_label.has_method("set_time"):
		battle_time_meter = time_label
		return battle_time_meter
	var anchor_label := time_label as Label
	var parent := time_label.get_parent() as Control
	if parent == null:
		return null
	battle_time_meter = BATTLE_TIME_METER_SCRIPT.new() as Control
	battle_time_meter.name = "BattleTimeMeter"
	battle_time_meter.position = time_label.position
	battle_time_meter.visible = false
	parent.add_child(battle_time_meter)
	if anchor_label != null:
		anchor_label.visible = false
		anchor_label.text = ""
	return battle_time_meter

func _get_time_display_control() -> Control:
	var meter := _ensure_battle_time_meter()
	if meter != null and is_instance_valid(meter):
		return meter
	return time_label

func _clear_text_cache() -> void:
	_last_hp_text = ""
	_last_heat_label_text = ""
	_last_ammo_label_text = ""
	_last_weapon_state_text = ""
	_last_gold_text = ""
	_last_resource_text = ""
	_last_time_text = ""
	_last_augments_text = ""

func _set_hp_bar_max(max_hp: int) -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var safe_max: int = max(1, max_hp)
	if not is_equal_approx(hp_bar.max_value, float(safe_max)):
		hp_bar.max_value = float(safe_max)
	if hp_bar.value > hp_bar.max_value:
		hp_bar.value = hp_bar.max_value
	_hp_bar_display_value = clampf(_hp_bar_display_value, 0.0, hp_bar.max_value)

func _animate_hp_bar_to(target_hp: int) -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var clamped_target: float = clampf(float(target_hp), 0.0, hp_bar.max_value)
	if is_equal_approx(_hp_bar_display_value, clamped_target):
		return
	if _hp_bar_tween != null and is_instance_valid(_hp_bar_tween):
		_hp_bar_tween.kill()
	_hp_bar_tween = hp_bar.create_tween()
	_hp_bar_tween.set_trans(_hp_bar_trans)
	_hp_bar_tween.set_ease(_hp_bar_ease)
	_hp_bar_tween.tween_property(hp_bar, "value", clamped_target, _hp_bar_anim_time)
	_hp_bar_display_value = clamped_target

func _refresh_hp_hud() -> void:
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	var current_hp: int = clampi(int(PlayerData.player_hp), 0, max_hp)
	if hp_label_text and is_instance_valid(hp_label_text):
		hp_label_text.visible = false
		if _last_hp_text != "":
			_last_hp_text = ""
			hp_label_text.text = ""
	_set_hp_bar_max(max_hp)
	_animate_hp_bar_to(current_hp)
	if hp_bar and is_instance_valid(hp_bar):
		hp_bar.visible = false
	_ensure_health_meter()
	if health_meter != null and is_instance_valid(health_meter):
		health_meter.call("set_health", current_hp, max_hp)

func _ensure_health_meter() -> void:
	if health_meter != null and is_instance_valid(health_meter):
		return
	var hp_label_root: Control = null
	if hp_bar != null and is_instance_valid(hp_bar):
		hp_label_root = hp_bar.get_parent() as Control
	if hp_label_root == null and hp_label_text != null and is_instance_valid(hp_label_text):
		hp_label_root = hp_label_text.get_parent() as Control
	if hp_label_root == null:
		return
	health_meter = PLAYER_HEALTH_METER_SCRIPT.new()
	health_meter.name = "PlayerHealthMeter"
	health_meter.position = HEALTH_METER_ORIGIN
	health_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label_root.add_child(health_meter)

func _update_heat_label_text() -> void:
	_sync_primary_resource_slot(_select_special_resource_slot(_collect_primary_weapon_resource_slots()))

func _collect_primary_weapon_resource_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var active_weapon := _get_active_weapon()
	if active_weapon == null:
		return slots
	if active_weapon.has_method("get_combat_resource_slots"):
		var value: Variant = active_weapon.call("get_combat_resource_slots")
		if value is Array:
			for slot in value:
				if slot is Dictionary:
					slots.append(slot)
	return slots

func _get_active_weapon() -> Node:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return null
	if PlayerData.player.has_method("get_main_weapon"):
		var value: Variant = PlayerData.player.call("get_main_weapon")
		if value is Node and is_instance_valid(value):
			return value as Node
	return null

func _select_primary_resource_slot(slots: Array[Dictionary]) -> Dictionary:
	if slots.is_empty():
		return {}
	var best := slots[0]
	for slot in slots:
		if int(slot.get("priority", 0)) > int(best.get("priority", 0)):
			best = slot
	return best

func _find_resource_slot(slots: Array[Dictionary], resource_type: StringName) -> Dictionary:
	for slot in slots:
		if StringName(str(slot.get("type", ""))) == resource_type:
			return slot
	return {}

func _select_special_resource_slot(slots: Array[Dictionary]) -> Dictionary:
	var special_slots: Array[Dictionary] = []
	for slot in slots:
		if StringName(str(slot.get("type", ""))) != &"ammo":
			special_slots.append(slot)
	return _select_primary_resource_slot(special_slots)

func _sync_primary_resource_slot(slot: Dictionary) -> void:
	if slot.is_empty():
		_hide_primary_resource_slot()
		return
	_ensure_primary_resource_meter()
	if primary_resource_meter == null or not is_instance_valid(primary_resource_meter):
		return
	var resource_type := StringName(str(slot.get("type", slot.get("id", "ammo"))))
	var ratio := clampf(float(slot.get("ratio", 0.0)), 0.0, 1.0)
	var tooltip := str(slot.get("tooltip", ""))
	var state := StringName(str(slot.get("state", "normal")))
	var text := str(slot.get("short_text", slot.get("text", "")))
	primary_resource_meter.call("set_resource", resource_type, ratio, state, text, tooltip)
	primary_resource_meter.modulate.a = 1.0 if resource_type == &"heat" else SPECIAL_RESOURCE_OPACITY
	primary_resource_meter.visible = true
	if heat_label and is_instance_valid(heat_label):
		heat_label.visible = false
		heat_label.text = ""

func _hide_primary_resource_slot() -> void:
	if primary_resource_meter and is_instance_valid(primary_resource_meter):
		primary_resource_meter.call("set_resource", &"ammo", 0.0, &"normal", "", "")
		primary_resource_meter.visible = false
	if heat_label and is_instance_valid(heat_label):
		heat_label.visible = false
	_last_heat_label_text = ""

func _ensure_primary_resource_meter() -> void:
	_ensure_special_resource_slot_container()
	if special_resource_slot_container == null or not is_instance_valid(special_resource_slot_container):
		return
	if primary_resource_meter != null and is_instance_valid(primary_resource_meter):
		if primary_resource_meter.get_parent() != special_resource_slot_container:
			var previous_parent: Node = primary_resource_meter.get_parent()
			if previous_parent:
				previous_parent.remove_child(primary_resource_meter)
			special_resource_slot_container.add_child(primary_resource_meter)
		return
	primary_resource_meter = COMBAT_RESOURCE_METER_SCRIPT.new()
	primary_resource_meter.name = "SpecialResourceMeter"
	primary_resource_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_resource_meter.modulate.a = SPECIAL_RESOURCE_OPACITY
	special_resource_slot_container.add_child(primary_resource_meter)

func _ensure_special_resource_slot_container() -> void:
	if special_resource_slot_container != null and is_instance_valid(special_resource_slot_container):
		return
	var parent := character_hud_root
	if parent == null:
		return
	special_resource_slot_container = Control.new()
	special_resource_slot_container.name = "SpecialResourceSlot"
	special_resource_slot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	special_resource_slot_container.position = parent.get_viewport_rect().size * 0.5 + SPECIAL_RESOURCE_OFFSET
	parent.add_child(special_resource_slot_container)

func _sync_ammo_resource_slot(slot: Dictionary) -> void:
	if slot.is_empty():
		if ammo_resource_meter and is_instance_valid(ammo_resource_meter):
			ammo_resource_meter.visible = false
		return
	_ensure_ammo_resource_meter()
	if ammo_resource_meter == null or not is_instance_valid(ammo_resource_meter):
		return
	ammo_resource_meter.call("set_resource", &"ammo", clampf(float(slot.get("ratio", 0.0)), 0.0, 1.0), StringName(str(slot.get("state", "normal"))), str(slot.get("short_text", "")), str(slot.get("tooltip", "")))
	ammo_resource_meter.visible = true

func _ensure_ammo_resource_meter() -> void:
	if combat_resource_slot_container == null or not is_instance_valid(combat_resource_slot_container):
		return
	if ammo_resource_meter != null and is_instance_valid(ammo_resource_meter):
		return
	ammo_resource_meter = COMBAT_RESOURCE_METER_SCRIPT.new()
	ammo_resource_meter.name = "AmmoResourceMeter"
	ammo_resource_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_resource_slot_container.add_child(ammo_resource_meter)

func _update_ammo_label_text() -> void:
	_hide_legacy_ammo_slot()

func _hide_legacy_ammo_slot() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if ammo_label and is_instance_valid(ammo_label):
		ammo_label.visible = false
		ammo_label.text = ""

func _style_status_label(label: Label, color: Color, urgent: bool) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18 if not urgent else 0.28)
	style.border_color = Color(color.r, color.g, color.b, 0.74 if not urgent else 0.95)
	style.set_border_width_all(1 if not urgent else 2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	label.add_theme_stylebox_override("normal", style)

func _update_weapon_state_label_text() -> void:
	if weapon_state_label == null or not is_instance_valid(weapon_state_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | PS: --")
		return
	var weapon_count := PlayerData.player_weapon_list.size()
	var main_text := LocalizationManager.tr_key("ui.hud.weapon.main.none", "None")
	if weapon_count == 1:
		main_text = LocalizationManager.tr_key("ui.hud.weapon.main.locked", "W1 (locked)")
	elif PlayerData.main_weapon_index >= 0:
		main_text = LocalizationManager.tr_format("ui.hud.weapon.main.slot", {"index": PlayerData.main_weapon_index + 1}, "W%s" % str(PlayerData.main_weapon_index + 1))
	var ps_cd := 0.0
	var active_skill_node: Node = null
	if PlayerData.player.active_skill_holder and PlayerData.player.active_skill_holder.get_child_count() > 0:
		active_skill_node = PlayerData.player.active_skill_holder.get_child(0)
	if active_skill_node != null and active_skill_node.has_method("get_cooldown_remaining"):
		ps_cd = float(active_skill_node.call("get_cooldown_remaining"))
	var fail_reason := ""
	if PlayerData.player.has_method("get_last_weapon_skill_fail_reason"):
		fail_reason = str(PlayerData.player.get_last_weapon_skill_fail_reason())
	var lock_text := LocalizationManager.tr_key("ui.hud.weapon.swap.on", "on") if weapon_count > 1 else LocalizationManager.tr_key("ui.hud.weapon.swap.off", "off")
	var ps_text := "%.1fs" % ps_cd if ps_cd > 0.0 else LocalizationManager.tr_key("ui.hud.weapon.ready", "Ready")
	var fail_text := ""
	if fail_reason != "":
		fail_text = LocalizationManager.tr_format("ui.hud.weapon.fail", {"reason": fail_reason}, " Fail:%s" % fail_reason)
	var long_state_text := LocalizationManager.tr_format(
		"ui.hud.weapon_state",
		{
			"main": main_text,
			"offhand": maxi(0, weapon_count - 1),
			"swap": lock_text,
			"ps": ps_text,
			"fail": fail_text
		},
		"Main:%s Offhand:%d Swap:%s PS:%s%s" % [main_text, maxi(0, weapon_count - 1), lock_text, ps_text, fail_text]
	)
	var next_state_text := "W:%s  PS:%s" % [main_text, ps_text]
	if fail_reason != "":
		next_state_text = "W:%s  !" % main_text
	if _last_weapon_state_text != next_state_text:
		_last_weapon_state_text = next_state_text
		weapon_state_label.text = next_state_text
		weapon_state_label.tooltip_text = long_state_text
	_style_status_label(weapon_state_label, Color(0.46, 0.68, 0.92, 1.0) if fail_reason == "" else Color(1.0, 0.38, 0.28, 1.0), fail_reason != "")

func _refresh_inventory_text_values() -> void:
	if equipped_label and is_instance_valid(equipped_label):
		equipped_label.text = LocalizationManager.tr_key("ui.hud.equipped", "Equipped:")
	if augments_label and is_instance_valid(augments_label):
		var next_augments_text := str(PlayerData.player_augment_list)
		if _last_augments_text != next_augments_text:
			_last_augments_text = next_augments_text
			augments_label.text = next_augments_text
	if gold_label and is_instance_valid(gold_label):
		var next_gold_text := str(PlayerData.player_gold)
		if _last_gold_text != next_gold_text:
			_last_gold_text = next_gold_text
			if gold_label.has_method("set_gold_value"):
				gold_label.call("set_gold_value", PlayerData.player_gold, true)
			else:
				gold_label.text = LocalizationManager.tr_format("ui.hud.gold", {"value": PlayerData.player_gold}, "Gold: %s" % str(PlayerData.player_gold))

func _refresh_resource_text_value() -> void:
	if resource_label and is_instance_valid(resource_label):
		resource_label.visible = false
		resource_label.text = ""
	if energy_meter == null or not is_instance_valid(energy_meter):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player) \
			or not PlayerData.player.has_method("get_current_energy"):
		_update_skill_energy_meter(0.0, 100.0, 0.0, 0.0)
		return
	var current_energy := maxf(float(PlayerData.player.call("get_current_energy")), 0.0)
	var max_energy := current_energy
	if PlayerData.player.has_method("get_max_energy"):
		max_energy = maxf(float(PlayerData.player.call("get_max_energy")), 0.0)
	var skill_cost := 0.0
	if PlayerData.player.has_method("get_active_skill_energy_cost"):
		skill_cost = maxf(float(PlayerData.player.call("get_active_skill_energy_cost")), 0.0)
	var cooldown_ratio := 0.0
	var active_skill_node: Node = null
	if PlayerData.player.active_skill_holder and PlayerData.player.active_skill_holder.get_child_count() > 0:
		active_skill_node = PlayerData.player.active_skill_holder.get_child(0)
	if active_skill_node != null and active_skill_node.has_method("get_cooldown_ratio"):
		cooldown_ratio = clampf(float(active_skill_node.call("get_cooldown_ratio")), 0.0, 1.0)
	_update_skill_energy_meter(current_energy, max_energy, skill_cost, cooldown_ratio)

func _update_skill_energy_meter(current_energy: float, max_energy: float, skill_cost: float, cooldown_ratio: float) -> void:
	var next_signature := "%.1f:%.1f:%.1f:%.2f" % [
		snappedf(current_energy, 0.1),
		snappedf(max_energy, 0.1),
		snappedf(skill_cost, 0.1),
		snappedf(cooldown_ratio, 0.01)
	]
	if _last_energy_signature == next_signature:
		return
	_last_energy_signature = next_signature
	energy_meter.call("set_energy", current_energy, max_energy)
	energy_meter.call("set_skill_cost", skill_cost)
	energy_meter.call("set_cooldown_ratio", cooldown_ratio)

func _refresh_time_text_value() -> void:
	var time_display := _get_time_display_control()
	if time_display == null or not is_instance_valid(time_display):
		return
	var time_remaining := PhaseManager.get_battle_time_remaining() if PhaseManager.has_method("get_battle_time_remaining") else PhaseManager.battle_time
	var time_duration := maxi(int(PhaseManager.time_out), 1) if PhaseManager != null else 1
	var phase := PhaseManager.current_state() if PhaseManager.has_method("current_state") else str(PhaseManager.phase)
	var contract_owns_timer: bool = phase == PhaseManager.BATTLE and BattleContractManager.state in [
		BattleContractManager.ACTIVE,
		BattleContractManager.COMPLETED,
	]
	if time_display.has_method("set_suppressed"):
		time_display.call("set_suppressed", contract_owns_timer)
	var next_signature := "%s:%d:%d:%s" % [phase, time_remaining, time_duration, str(BattleContractManager.state)]
	if _last_time_text == next_signature:
		return
	_last_time_text = next_signature
	if time_display.has_method("set_time"):
		time_display.call("set_time", time_remaining, time_duration, phase)
	elif time_display is Label:
		var next_time_text := LocalizationManager.tr_format("ui.hud.time", {"value": time_remaining}, "Time Left: %s" % str(time_remaining))
		(time_display as Label).text = next_time_text
	# Keep the final visibility authoritative even if a legacy display changes it in set_time().
	time_display.visible = phase == PhaseManager.BATTLE and not contract_owns_timer

func refresh_heat_fallback_text() -> void:
	if heat_label and is_instance_valid(heat_label) and not heat_label.visible:
		heat_label.text = ""
	if ammo_label and is_instance_valid(ammo_label):
		if PlayerData.player == null or not is_instance_valid(PlayerData.player) or not ammo_label.visible:
			ammo_label.text = ""
