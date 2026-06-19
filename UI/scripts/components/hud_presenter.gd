extends RefCounted
class_name HudPresenter

var hp_bar: ProgressBar
var hp_label_text: Label
var heat_label: Label
var ammo_label: Label
var weapon_state_label: Label
var gold_label: Label
var resource_label: Label
var time_label: Label
var equipped_label: Label
var augments_label: Label

const HUD_MARGIN := 16.0
const CONTINUOUS_REFRESH_INTERVAL := 0.1

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
	p_time_label: Label,
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

func configure_hp_bar_anim(anim_time: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	_hp_bar_anim_time = anim_time
	_hp_bar_trans = trans
	_hp_bar_ease = ease

func layout_hud(viewport_size: Vector2, hp_label_root: Control, weapon_selector: WeaponSelector = null) -> void:
	if equipped_label and is_instance_valid(equipped_label):
		equipped_label.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.set_layout_origin(Vector2(HUD_MARGIN + 12.0, HUD_MARGIN - 2.0))
	if hp_label_root and is_instance_valid(hp_label_root):
		hp_label_root.position = Vector2(HUD_MARGIN, viewport_size.y - 120.0)
	if heat_label and is_instance_valid(heat_label):
		var heat_spacing := 8.0
		var heat_height := maxf(heat_label.get_combined_minimum_size().y, 20.0)
		var hp_y := hp_label_root.position.y if hp_label_root and is_instance_valid(hp_label_root) else viewport_size.y - 120.0
		heat_label.position = Vector2(HUD_MARGIN, hp_y - heat_height - heat_spacing)
	if ammo_label and is_instance_valid(ammo_label):
		ammo_label.position = Vector2(64.0, 64.0)
	if weapon_state_label and is_instance_valid(weapon_state_label):
		weapon_state_label.position = Vector2(HUD_MARGIN, viewport_size.y - 300.0)
	if gold_label and is_instance_valid(gold_label):
		gold_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN)
	if time_label and is_instance_valid(time_label):
		time_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN + 56.0)
	if resource_label and is_instance_valid(resource_label):
		resource_label.position = Vector2(64.0, 88.0)

func ensure_heat_label(character_root: Control) -> Label:
	if heat_label != null and is_instance_valid(heat_label):
		return heat_label
	heat_label = Label.new()
	heat_label.name = "Heat"
	heat_label.text = LocalizationManager.tr_key("ui.hud.heat_empty", "Heat: --")
	heat_label.visible = false
	character_root.add_child(heat_label)
	return heat_label

func ensure_ammo_label(hp_label_root: Control) -> Label:
	if ammo_label != null and is_instance_valid(ammo_label):
		return ammo_label
	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
	ammo_label.visible = true
	hp_label_root.add_child(ammo_label)
	return ammo_label

func ensure_resource_label_under_hp(current_resource_label: Label, hp_label_root: Control) -> Label:
	resource_label = current_resource_label
	if resource_label == null or not is_instance_valid(resource_label):
		return resource_label
	if hp_label_root == null or not is_instance_valid(hp_label_root):
		return resource_label
	if resource_label.get_parent() == hp_label_root:
		return resource_label
	var previous_parent := resource_label.get_parent()
	if previous_parent:
		previous_parent.remove_child(resource_label)
	hp_label_root.add_child(resource_label)
	return resource_label

func ensure_weapon_state_label(character_root: Control) -> Label:
	if weapon_state_label != null and is_instance_valid(weapon_state_label):
		return weapon_state_label
	weapon_state_label = Label.new()
	weapon_state_label.name = "WeaponState"
	weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | WS: -- | PS: --")
	weapon_state_label.visible = false
	character_root.add_child(weapon_state_label)
	return weapon_state_label

func init_hp_bar() -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	var current_hp: int = clampi(int(PlayerData.player_hp), 0, max_hp)
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(current_hp)
	_hp_bar_display_value = hp_bar.value

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
	_update_ammo_label_text()

func refresh_weapon_state() -> void:
	_update_weapon_state_label_text()

func refresh_inventory() -> void:
	_refresh_inventory_text_values()

func refresh_resource() -> void:
	_refresh_resource_text_value()

func refresh_time() -> void:
	_refresh_time_text_value()

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
		var next_text := LocalizationManager.tr_format("ui.hud.hp", {"current": current_hp, "max": max_hp}, "HP: %d/%d" % [current_hp, max_hp])
		if _last_hp_text != next_text:
			_last_hp_text = next_text
			hp_label_text.text = next_text
	_set_hp_bar_max(max_hp)
	_animate_hp_bar_to(current_hp)

func _update_heat_label_text() -> void:
	if heat_label == null or not is_instance_valid(heat_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		heat_label.visible = false
		return
	if not PlayerData.player.has_method("get_total_heat_max"):
		heat_label.visible = false
		return
	var heat_max: float = float(PlayerData.player.call("get_total_heat_max"))
	if heat_max <= 0.0:
		heat_label.visible = false
		return
	var heat_value: float = float(PlayerData.player.call("get_total_heat_value"))
	var percent: int = int(round(clampf(heat_value / heat_max, 0.0, 1.0) * 100.0))
	var overheated := _any_heat_weapon_overheated()
	var overheat_text := LocalizationManager.tr_key("ui.hud.heat_overheat", " (OVERHEAT)") if overheated else ""
	var next_text := LocalizationManager.tr_format(
		"ui.hud.heat",
		{
			"value": int(round(heat_value)),
			"max": int(round(heat_max)),
			"percent": percent,
			"overheat": overheat_text
		},
		"Heat: %d/%d (%d%%)%s" % [int(round(heat_value)), int(round(heat_max)), percent, overheat_text]
	)
	if _last_heat_label_text != next_text:
		_last_heat_label_text = next_text
		heat_label.text = next_text
	heat_label.visible = true

func _update_ammo_label_text() -> void:
	if ammo_label == null or not is_instance_valid(ammo_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	if not PlayerData.player.has_method("get_main_weapon"):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var main_weapon_variant: Variant = PlayerData.player.call("get_main_weapon")
	if not (main_weapon_variant is Node):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var main_weapon := main_weapon_variant as Node
	if main_weapon == null or not is_instance_valid(main_weapon):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	if not main_weapon.has_method("get_ammo_status"):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var status := status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var current := int(status.get("current", 0))
	var max_ammo := int(status.get("max", 0))
	var is_reloading := bool(status.get("is_reloading", false))
	var reload_left := maxf(float(status.get("reload_left", 0.0)), 0.0)
	var reload_text := ""
	if is_reloading:
		reload_text = LocalizationManager.tr_format("ui.hud.ammo_reloading", {"sec": snappedf(reload_left, 0.1)}, " (Reloading %.1fs)" % reload_left)
	var next_ammo_text := LocalizationManager.tr_format(
		"ui.hud.ammo",
		{"current": current, "max": max_ammo, "reload": reload_text},
		"Ammo: %d/%d%s" % [current, max_ammo, reload_text]
	)
	if _last_ammo_label_text != next_ammo_text:
		_last_ammo_label_text = next_ammo_text
		ammo_label.text = next_ammo_text

func _any_heat_weapon_overheated() -> bool:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("has_heat_system"):
			continue
		if not bool(weapon.call("has_heat_system")):
			continue
		if weapon.has_method("is_weapon_overheated") and bool(weapon.call("is_weapon_overheated")):
			return true
	return false

func _update_weapon_state_label_text() -> void:
	if weapon_state_label == null or not is_instance_valid(weapon_state_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | WS: -- | PS: --")
		return
	var weapon_count := PlayerData.player_weapon_list.size()
	var main_text := LocalizationManager.tr_key("ui.hud.weapon.main.none", "None")
	if weapon_count == 1:
		main_text = LocalizationManager.tr_key("ui.hud.weapon.main.locked", "W1 (locked)")
	elif PlayerData.main_weapon_index >= 0:
		main_text = LocalizationManager.tr_format("ui.hud.weapon.main.slot", {"index": PlayerData.main_weapon_index + 1}, "W%s" % str(PlayerData.main_weapon_index + 1))
	var ws_cd: float = PlayerData.player.get_weapon_active_cd_remaining() if PlayerData.player.has_method("get_weapon_active_cd_remaining") else 0.0
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
	var next_state_text := LocalizationManager.tr_format(
		"ui.hud.weapon_state",
		{
			"main": main_text,
			"offhand": maxi(0, weapon_count - 1),
			"swap": lock_text,
			"ws": "%.1fs" % ws_cd,
			"ps": ps_text,
			"fail": fail_text
		},
		"Main:%s Offhand:%d Swap:%s WS:%.1fs PS:%s%s" % [main_text, maxi(0, weapon_count - 1), lock_text, ws_cd, ps_text, fail_text]
	)
	if _last_weapon_state_text != next_state_text:
		_last_weapon_state_text = next_state_text
		weapon_state_label.text = next_state_text

func _refresh_inventory_text_values() -> void:
	if equipped_label and is_instance_valid(equipped_label):
		equipped_label.text = LocalizationManager.tr_key("ui.hud.equipped", "Equipped:")
	if augments_label and is_instance_valid(augments_label):
		var next_augments_text := str(PlayerData.player_augment_list)
		if _last_augments_text != next_augments_text:
			_last_augments_text = next_augments_text
			augments_label.text = next_augments_text
	if gold_label and is_instance_valid(gold_label):
		var next_gold_text := LocalizationManager.tr_format("ui.hud.gold", {"value": PlayerData.player_gold}, "Gold: %s" % str(PlayerData.player_gold))
		if _last_gold_text != next_gold_text:
			_last_gold_text = next_gold_text
			gold_label.text = next_gold_text

func _refresh_resource_text_value() -> void:
	if resource_label and is_instance_valid(resource_label):
		var next_resource_text := ""
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("get_current_energy"):
			next_resource_text = LocalizationManager.tr_format(
				"ui.hud.energy",
				{"value": int(round(PlayerData.player.get_current_energy()))},
				"Energy: %d" % int(round(PlayerData.player.get_current_energy()))
			)
		else:
			next_resource_text = LocalizationManager.tr_key("ui.hud.energy_none", "Energy: --")
		if _last_resource_text != next_resource_text:
			_last_resource_text = next_resource_text
			resource_label.text = next_resource_text

func _refresh_time_text_value() -> void:
	if time_label and is_instance_valid(time_label):
		var time_remaining := PhaseManager.get_battle_time_remaining() if PhaseManager.has_method("get_battle_time_remaining") else PhaseManager.battle_time
		var next_time_text := LocalizationManager.tr_format("ui.hud.time", {"value": time_remaining}, "Time Left: %s" % str(time_remaining))
		if _last_time_text != next_time_text:
			_last_time_text = next_time_text
			time_label.text = next_time_text

func refresh_heat_fallback_text() -> void:
	if heat_label and is_instance_valid(heat_label) and not heat_label.visible:
		heat_label.text = LocalizationManager.tr_key("ui.hud.heat_empty", "Heat: --")
	if ammo_label and is_instance_valid(ammo_label):
		if PlayerData.player == null or not is_instance_valid(PlayerData.player):
			ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
