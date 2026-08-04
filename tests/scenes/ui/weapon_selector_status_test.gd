extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const WEAPON_SELECTOR := preload("res://UI/scripts/weapon_selector.gd")
const WEAPON_STATUS_BAR := preload("res://UI/scripts/weapon_slot_status_bar.gd")
const WEAPON_SWITCH_CONTROLLER := preload("res://UI/scripts/components/weapon_switch_controller.gd")
const WEAPON_SELECTOR_PASSIVE_PRESENTER := preload("res://UI/scripts/components/weapon_selector_passive_presenter.gd")
const WEAPON_SELECTOR_READABILITY_PRESENTER := preload("res://UI/scripts/components/weapon_selector_readability_presenter.gd")
const WEAPON_SKILL_CHARGE_TRACK := preload("res://UI/scripts/weapon_skill_charge_track.gd")
const WEAPON_TRIGGER_FEEDBACK := preload("res://UI/scripts/weapon_trigger_feedback.gd")
const PLAYER_STATUS_MODIFIER_SYSTEM := preload("res://Player/Mechas/scripts/player_status_modifier_system.gd")

class DummyWeapon:
	extends Weapon
	var ammo_status: Dictionary = {}
	var passive_status: Dictionary = {}

	func get_ammo_status() -> Dictionary:
		return ammo_status.duplicate()

	func get_passive_status() -> Dictionary:
		return passive_status.duplicate()

class DummyHeatPlayer:
	extends Node2D
	var heat_expansion_active := false
	var heat_expansion_multiplier := 1.0
	var heat_prepared_active := false
	var heat_prepared_stack_count := 0
	var heat_prepared_bonus_per_stack := 0.10
	var heat_prepared_apply_count := 0
	var plasma_feedback_active := false

	func apply_heat_expansion(_duration: float, multiplier: float) -> bool:
		heat_expansion_active = true
		heat_expansion_multiplier = multiplier
		return true

	func has_heat_expansion() -> bool:
		return heat_expansion_active

	func apply_heat_prepared(_duration: float, bonus_per_stack: float, max_stacks: int) -> int:
		heat_prepared_active = true
		heat_prepared_bonus_per_stack = bonus_per_stack
		heat_prepared_stack_count = mini(heat_prepared_stack_count + 1, maxi(max_stacks, 1))
		heat_prepared_apply_count += 1
		return heat_prepared_stack_count

	func has_heat_prepared() -> bool:
		return heat_prepared_active

	func get_heat_prepared_stack_count() -> int:
		return heat_prepared_stack_count if heat_prepared_active else 0

	func get_heat_prepared_fire_damage_multiplier() -> float:
		return 1.0 + float(get_heat_prepared_stack_count()) * heat_prepared_bonus_per_stack

	func apply_plasma_lance_heat_feedback(_duration: float, _low: float, _high: float, _threshold: float) -> void:
		plasma_feedback_active = true

	func has_plasma_lance_heat_feedback() -> bool:
		return plasma_feedback_active

var _failed := false
var _selector

func _ready() -> void:
	_selector = WEAPON_SELECTOR.new()
	_test_full_mainhand_state()
	_test_low_and_empty_states()
	_test_reload_progress()
	_test_non_ammo_weapon_hides_bar()
	_test_ammo_label_uses_text_only_status()
	_test_weapon_order_stays_fixed_when_mainhand_changes()
	_test_weapon_skill_footer_modes()
	_test_weapon_passive_contract_classification()
	_test_continuous_effect_occupies_consumed_bean()
	_test_condition_based_skill_rearming()
	_test_reload_settlement_consumes_after_finish()
	_test_passive_feedback_ignores_routine_weapon_events()
	_test_reload_hint_is_unambiguous()
	print("FAIL weapon selector status" if _failed else "PASS weapon selector status")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, Callable(), [_selector])
	_selector = null

func _test_full_mainhand_state() -> void:
	var weapon := _make_weapon({
		"enabled": true,
		"current": 30,
		"max": 30,
		"is_reloading": false,
		"reload_left": 0.0,
		"reload_total": 2.0,
	})
	var state: Dictionary = _selector.call("_resolve_weapon_availability_state", weapon, true)
	_expect(state.get("kind") == &"normal", "full magazine must use the normal state")
	_expect(is_equal_approx(float(state.get("progress", 0.0)), 1.0), "full magazine bar must be full")
	_expect(str(state.get("label", "")) == "30/30", "mainhand must expose precise ammo")
	weapon.free()

func _test_low_and_empty_states() -> void:
	var weapon := _make_weapon({
		"enabled": true,
		"current": 5,
		"max": 30,
		"is_reloading": false,
	})
	var low: Dictionary = _selector.call("_resolve_weapon_availability_state", weapon, false)
	_expect(low.get("kind") == &"low", "quarter magazine threshold must use LOW")
	_expect(str(low.get("label", "")) == "LOW", "offhand low ammo must use a compact label")
	weapon.ammo_status.current = 0
	var empty: Dictionary = _selector.call("_resolve_weapon_availability_state", weapon, false)
	_expect(empty.get("kind") == &"empty", "zero ammo must use a distinct empty state")
	_expect(is_zero_approx(float(empty.get("progress", 1.0))), "empty ammo bar must be empty")
	_expect(empty.has("track_color"), "empty ammo must retain a visible danger track")
	weapon.free()

func _test_reload_progress() -> void:
	var weapon := _make_weapon({
		"enabled": true,
		"current": 0,
		"max": 30,
		"is_reloading": true,
		"reload_left": 1.0,
		"reload_total": 2.0,
	})
	var state: Dictionary = _selector.call("_resolve_weapon_availability_state", weapon, true)
	_expect(state.get("kind") == &"reloading", "reload must not look like ordinary ammo")
	_expect(is_equal_approx(float(state.get("progress", 0.0)), 0.5), "reload bar must grow from zero to full")
	_expect(str(state.get("label", "")).begins_with("RLD"), "reload must have a textual marker")
	weapon.free()

func _test_non_ammo_weapon_hides_bar() -> void:
	var weapon := _make_weapon({"enabled": false})
	var state: Dictionary = _selector.call("_resolve_weapon_availability_state", weapon, true)
	_expect(not bool(state.get("visible", true)), "non-ammo weapon must not show a misleading bar")
	weapon.free()

func _test_ammo_label_uses_text_only_status() -> void:
	var label := Label.new()
	var legacy_background := StyleBoxFlat.new()
	label.add_theme_stylebox_override("normal", legacy_background)
	_selector.call("_apply_weapon_availability_label", label, {
		"label": "RLD 1.2",
		"kind": &"reloading",
		"fill_color": Color.CYAN,
	})
	_expect(
		not label.has_theme_stylebox_override("normal"),
		"ammo status label must remove state backgrounds"
	)
	_expect(label.text == "RLD 1.2", "ammo status label must retain its text")
	label.free()

func _test_weapon_order_stays_fixed_when_mainhand_changes() -> void:
	var controller = WEAPON_SWITCH_CONTROLLER.new()
	var initial: Array[int] = controller.build_fixed_order(4, 4)
	var after_switch: Array[int] = controller.build_fixed_order(4, 4)
	_expect(initial == [0, 1, 2, 3], "weapon slots must follow stable inventory order")
	_expect(after_switch == initial, "changing the mainhand must not reorder weapon slots")

func _test_weapon_skill_footer_modes() -> void:
	var presenter = WEAPON_SELECTOR_PASSIVE_PRESENTER.new()
	var weapon := DummyWeapon.new()
	var hidden: Dictionary = presenter.resolve_state(weapon)
	_expect(not bool(hidden.get("visible", true)), "weapons with no skill must hide the footer")
	weapon.passive_status = {
		"id": "single_passive",
		"state": "charging",
		"progress": 0.5,
		"charge_current": 1,
		"charge_max": 1,
	}
	var single_bean: Dictionary = presenter.resolve_state(weapon)
	_expect(
		single_bean.get("display_mode") == &"segmented",
		"single-condition weapon skills must use one discrete skill bean"
	)
	_expect(
		not bool(single_bean.get("cycle_visible", true)),
		"single-condition weapon skills must not infer an auxiliary progress track"
	)
	weapon.passive_status.charge_max = 3
	weapon.passive_status.charge_current = 1
	var segmented: Dictionary = presenter.resolve_state(weapon)
	_expect(
		segmented.get("display_mode") == &"segmented",
		"multi-charge weapon skills must use a segmented footer track"
	)
	_expect(
		not bool(segmented.get("cycle_visible", true)),
		"charge count alone must not imply a condition progress track"
	)
	weapon.passive_status.condition_visible = true
	weapon.passive_status.condition_progress = 0.65
	weapon.passive_status.condition_thresholds = [0.5]
	weapon.passive_status.charge_states = ["ready", "active", "spent"]
	segmented = presenter.resolve_state(weapon)
	_expect(bool(segmented.get("cycle_visible", false)), "multi-condition skills must expose their progress track")
	_expect(segmented.get("charge_states") == ["ready", "active", "spent"], "presenter must preserve per-bean states")
	var slot := Control.new()
	slot.position = Vector2(12.0, 0.0)
	slot.size = Vector2(96.0, 72.0)
	var status_bar = WEAPON_STATUS_BAR.new()
	var charge_track = WEAPON_SKILL_CHARGE_TRACK.new()
	presenter.layout_status(status_bar, charge_track, slot, segmented, false)
	_expect(
		status_bar.position.y >= slot.position.y + slot.size.y + 2.0,
		"weapon skill footer must stay outside the weapon image"
	)
	_expect(
		status_bar.position.x >= slot.position.x + 16.0,
		"skill status must reserve a shared leading gutter for its icon"
	)
	_expect(
		status_bar.position == charge_track.position and status_bar.size == charge_track.size,
		"continuous and segmented states must share one stable footer region"
	)
	charge_track.max_charges = 3
	charge_track.current_charges = 1
	charge_track.charge_states = ["ready", "active", "spent"]
	charge_track.show_cycle_progress = true
	charge_track.cycle_progress = 0.65
	charge_track.cycle_thresholds = [0.5]
	charge_track.size = status_bar.size
	_expect(charge_track.get_segment_rects().size() == 3, "multi-charge footer must expose one segment per charge")
	_expect(
		charge_track.get_segment_fill_ratios() == [1.0, 1.0, 0.0],
		"ready and active beans must be filled while spent beans retain outline only"
	)
	_expect(
		charge_track.get_segment_states() == ["ready", "active", "spent"],
		"skill beans must distinguish ready, active, and spent semantics"
	)
	_expect(
		charge_track.get_cycle_rect().has_area(),
		"multi-charge condition progress must occupy its own thin track"
	)
	charge_track.trigger_flash = 1.0
	_expect(is_equal_approx(charge_track.trigger_flash, 1.0), "triggered segmented track must expose a full flash state")
	charge_track.max_charges = 1
	charge_track.charge_states = ["ready"]
	_expect(charge_track.get_segment_rects().size() == 1, "single-condition skills must still render one bean")
	_expect(
		charge_track.get_segment_rects()[0].size.x < charge_track.size.x * 0.5,
		"a single skill bean must not resemble a full-width progress bar"
	)
	weapon.free()
	slot.free()
	status_bar.free()
	charge_track.free()

func _test_weapon_passive_contract_classification() -> void:
	var multi_condition_paths := [
		"res://Player/Weapons/Instances/cannon.tscn",
		"res://Player/Weapons/Instances/dash_blade.tscn",
		"res://Player/Weapons/Instances/machine_gun.tscn",
		"res://Player/Weapons/Instances/flamethrower.tscn",
		"res://Player/Weapons/Instances/spear_launcher.tscn",
	]
	var single_condition_paths := [
		"res://Player/Weapons/Instances/sniper.tscn",
		"res://Player/Weapons/Instances/shotgun.tscn",
		"res://Player/Weapons/Instances/rocket_launcher.tscn",
		"res://Player/Weapons/Instances/orbit.tscn",
		"res://Player/Weapons/Instances/chainsaw_launcher.tscn",
		"res://Player/Weapons/Instances/glacier_projector.tscn",
		"res://Player/Weapons/Instances/pistol.tscn",
	]
	var energy_cycle_paths := [
		"res://Player/Weapons/Instances/laser.tscn",
		"res://Player/Weapons/Instances/charged_blaster.tscn",
		"res://Player/Weapons/Instances/plasma_lance.tscn",
	]
	for scene_path in multi_condition_paths:
		var weapon := (load(scene_path) as PackedScene).instantiate() as Weapon
		var status: Dictionary = weapon.get_passive_status()
		_expect(bool(status.get("condition_visible", false)), "%s must expose its separate charge condition" % scene_path)
		_expect((status.get("charge_states", []) as Array).size() >= 1, "%s must expose at least one skill bean" % scene_path)
		weapon.free()
	for scene_path in energy_cycle_paths:
		var weapon := (load(scene_path) as PackedScene).instantiate() as Weapon
		var status: Dictionary = weapon.get_passive_status()
		_expect(bool(status.get("condition_visible", false)), "%s must expose the global energy condition" % scene_path)
		_expect(int(status.get("required", 0)) == 100, "%s must require a full global energy pool" % scene_path)
		_expect((status.get("condition_thresholds", []) as Array).is_empty(), "%s must not expose obsolete hit-count divisions" % scene_path)
		_expect(status.get("trigger_hint") == "fire_at_full_global_energy", "%s must trigger only when fired at full global energy" % scene_path)
		_expect(bool(status.get("energy_full_fire_cycle", false)), "%s must advertise the simplified full-energy cycle" % scene_path)
		weapon.free()
	for scene_path in single_condition_paths:
		var weapon := (load(scene_path) as PackedScene).instantiate() as Weapon
		var status: Dictionary = weapon.get_passive_status()
		_expect(not bool(status.get("condition_visible", true)), "%s must remain bean-only" % scene_path)
		_expect((status.get("charge_states", []) as Array).size() >= 1, "%s must expose at least one skill bean" % scene_path)
		weapon.free()

func _test_reload_settlement_consumes_after_finish() -> void:
	var previous_player = PlayerData.player
	var dummy_player := DummyHeatPlayer.new()
	PlayerData.player = dummy_player
	var machine_gun := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	machine_gun.force_skill_cooldowns_ready()
	machine_gun.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": machine_gun,
		"spent_ratio": 0.1,
	})
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 4, "machine gun must start with four skill beans")
	machine_gun.call("_on_passive_event", &"on_reload_finished", {
		"source_weapon": machine_gun,
		"spent_ratio": 0.1,
	})
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 0, "reload finish must consume all machine-gun beans")
	_expect(
		is_equal_approx(dummy_player.heat_expansion_multiplier, 1.668),
		"four machine-gun beans must amplify elemental alignment without expanding fixed Heat bounds"
	)
	var status: Dictionary = machine_gun.get_passive_status()
	_expect(status.get("charge_states") == ["active", "active", "active", "active"], "machine-gun HUD must keep every consumed bean active for the shared effect duration")
	machine_gun.free()

	var flamethrower := (load("res://Player/Weapons/Instances/flamethrower.tscn") as PackedScene).instantiate() as Weapon
	flamethrower.force_skill_cooldowns_ready()
	flamethrower.call("_on_passive_event", &"on_reload_started", {"source_weapon": flamethrower})
	flamethrower.call("_on_passive_event", &"on_reload_finished", {"source_weapon": flamethrower})
	_expect(dummy_player.heat_prepared_apply_count == 0, "flamethrower reload must not trigger its firing-duration skill")
	flamethrower.free()

	PlayerData.player = null
	var spear := (load("res://Player/Weapons/Instances/spear_launcher.tscn") as PackedScene).instantiate() as Weapon
	add_child(spear)
	spear.force_skill_cooldowns_ready()
	spear.set("_piercing_blade_dance_charge", 10)
	spear.call("_on_passive_event", &"on_reload_started", {"source_weapon": spear})
	_expect(spear.passive_controller.get_passive_charge_current() == 1, "spear reload start must not launch the volley")
	spear.call("_on_passive_event", &"on_reload_finished", {"source_weapon": spear})
	_expect(spear.passive_controller.get_passive_charge_current() == 0, "spear reload finish must consume its bean")
	_expect(spear.get_passive_status().get("charge_states") == ["spent"], "instant spear settlement must leave an outlined bean")
	remove_child(spear)
	spear.free()

	PlayerData.player = previous_player
	dummy_player.free()

func _test_condition_based_skill_rearming() -> void:
	var previous_player = PlayerData.player
	PlayerData.player = null
	var machine_gun := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	machine_gun.force_skill_cooldowns_ready()
	for index in range(4):
		machine_gun.notify_offhand_skill_triggered(0.0)
	machine_gun.magazine_capacity = 40
	machine_gun.current_ammo = 31
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 0, "machine gun must not rearm below 25% magazine spend")
	_expect(is_equal_approx(float(machine_gun.get_passive_status().get("condition_progress", 0.0)), 0.9), "22.5% magazine spend must fill 90% of the next-bean progress bar")
	machine_gun.current_ammo = 30
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 1, "machine gun must restore one bean at 25% magazine spend")
	_expect(is_zero_approx(float(machine_gun.get_passive_status().get("condition_progress", 1.0))), "earning a bean at 25% spend must reset next-bean progress")
	machine_gun.current_ammo = 25
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(is_equal_approx(float(machine_gun.get_passive_status().get("condition_progress", 0.0)), 0.5), "37.5% magazine spend must fill half of the next-bean progress bar")
	machine_gun.current_ammo = 20
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 2, "machine gun must restore two beans at 50% magazine spend")
	_expect(is_zero_approx(float(machine_gun.get_passive_status().get("condition_progress", 1.0))), "earning the second bean at 50% spend must restart progress again")
	machine_gun.current_ammo = 10
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 3, "machine gun must restore three beans at 75% magazine spend")
	machine_gun.current_ammo = 0
	machine_gun.call("_try_rearm_heat_expansion_from_magazine_spend")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 4, "machine gun must restore four beans at 100% magazine spend")
	machine_gun.call("_refresh_offhand_skill_on_reload")
	_expect(machine_gun.passive_controller.get_passive_charge_current() == 4, "machine-gun reload must not restore extra beans")
	machine_gun.free()

	var flamethrower := (load("res://Player/Weapons/Instances/flamethrower.tscn") as PackedScene).instantiate() as Weapon
	var dummy_player := DummyHeatPlayer.new()
	add_child(dummy_player)
	PlayerData.player = dummy_player
	flamethrower.set("fire_duration_required_sec", 5.0)
	flamethrower.call("_accumulate_heat_prepared_firing_duration", 2.0)
	_expect(is_equal_approx(float(flamethrower.get_passive_status().get("condition_progress", 0.0)), 0.4), "two firing seconds must fill 40% of the flamethrower progress bar")
	flamethrower.call("_accumulate_heat_prepared_firing_duration", 3.0)
	_expect(dummy_player.heat_prepared_stack_count == 1, "five cumulative firing seconds must immediately grant the first stack")
	_expect(flamethrower.get_passive_status().get("charge_states") == ["active", "spent"], "the first fire-damage stack must occupy one of two HUD beans")
	flamethrower.call("_accumulate_heat_prepared_firing_duration", 5.0)
	_expect(dummy_player.heat_prepared_stack_count == 2, "the second completed firing cycle must grant the second stack")
	flamethrower.call("_accumulate_heat_prepared_firing_duration", 5.0)
	_expect(dummy_player.heat_prepared_stack_count == 2, "flamethrower fire-damage stacks must cap at two")
	_expect(dummy_player.heat_prepared_apply_count == 3, "a trigger at two stacks must still refresh the effect duration")
	_expect(flamethrower.get_passive_status().get("charge_states") == ["active", "active"], "both fire-damage stacks must be visible in the HUD")
	var previous_crit_rate: float = float(PlayerData.total_crit_rate)
	PlayerData.total_crit_rate = 0.0
	var modifier_system = PLAYER_STATUS_MODIFIER_SYSTEM.new()
	modifier_system.setup(dummy_player)
	_expect(modifier_system.compute_outgoing_damage_result(100, Attack.TYPE_FIRE).damage == 120, "two stacks must increase fire damage by 20%")
	_expect(modifier_system.compute_outgoing_damage_result(100, Attack.TYPE_PHYSICAL).damage == 100, "the flamethrower skill must not increase non-fire damage")
	PlayerData.total_crit_rate = previous_crit_rate
	flamethrower.free()
	PlayerData.player = null
	dummy_player.free()

	var plasma := (load("res://Player/Weapons/Instances/plasma_lance.tscn") as PackedScene).instantiate() as Weapon
	var plasma_status := plasma.get_passive_status()
	_expect(plasma_status.get("id") == "plasma_lance_energy_discharge_triggered", "plasma must expose its full-energy release")
	_expect(int(plasma_status.get("required", 0)) == 100, "plasma release must require a full global energy pool")
	_expect(plasma_status.get("refresh_hint") == "automatic_after_full_energy_attack", "plasma release must restart after consuming a full pool")
	plasma.free()
	PlayerData.player = previous_player

func _test_continuous_effect_occupies_consumed_bean() -> void:
	var pistol := (load("res://Player/Weapons/Instances/pistol.tscn") as PackedScene).instantiate() as Weapon
	pistol.force_skill_cooldowns_ready()
	pistol.notify_offhand_skill_triggered(0.0)
	pistol.set("_pierce_mark_window_remaining_sec", 2.0)
	var active_status: Dictionary = pistol.get_passive_status()
	_expect(
		active_status.get("charge_states") == ["ready", "ready", "active"],
		"a continuous effect must color its consumed bean active while preserving unused beans"
	)
	pistol.set("_pierce_mark_window_remaining_sec", 0.0)
	var spent_status: Dictionary = pistol.get_passive_status()
	_expect(
		spent_status.get("charge_states") == ["ready", "ready", "spent"],
		"an expired continuous effect must leave its consumed bean outlined"
	)
	pistol.free()

func _test_passive_feedback_ignores_routine_weapon_events() -> void:
	var weapon := DummyWeapon.new()
	weapon.passive_status = {"id": "machine_gun_heat_expansion"}
	_expect(
		not _selector.call(
			"_should_play_passive_trigger_feedback",
			weapon,
			&"on_shoot",
			{"passive_id": "on_shoot"}
		),
		"routine machine-gun shots must not replay passive trigger feedback"
	)
	_expect(
		_selector.call(
			"_should_play_passive_trigger_feedback",
			weapon,
			&"machine_gun_heat_expansion",
			{"passive_id": "machine_gun_heat_expansion"}
		),
		"the displayed machine-gun passive must retain trigger feedback"
	)
	_expect(
		_selector.call(
			"_should_play_passive_trigger_feedback",
			weapon,
			&"passive_effect_applied",
			{"passive_id": "machine_gun_heat_expansion"}
		),
		"an explicit displayed passive id must identify genuine trigger feedback"
	)
	var feedback = WEAPON_TRIGGER_FEEDBACK.new()
	feedback.intensity = 1.5
	_expect(is_equal_approx(feedback.intensity, 1.0), "whole-slot trigger feedback intensity must clamp safely")
	feedback.free()
	weapon.free()

func _test_reload_hint_is_unambiguous() -> void:
	var root := Control.new()
	var slots: Array[Control] = []
	for index in range(4):
		var slot := Control.new()
		slot.name = "Slot%d" % index
		root.add_child(slot)
		slots.append(slot)
	var presenter = WEAPON_SELECTOR_READABILITY_PRESENTER.new()
	presenter.setup(root, slots)
	var weapon := DummyWeapon.new()
	weapon.name = "FeedbackTestWeapon"
	presenter.update_slot(0, weapon, true)
	var hint := root.get_node("ReloadHint") as Label
	var passive_icon := slots[0].get_node("PassiveIcon") as Control
	_expect(hint.visible, "the reload key hint must remain visible for the main weapon")
	_expect(hint.text == LocalizationManager.tr_key("ui.weapon_hud.reload_hint", "[R]  RELOAD"),
		"the R hint must describe reload only")
	_expect(slots[0].tooltip_text.contains(LocalizationManager.get_weapon_instance_display_name(weapon)),
		"the main weapon tooltip must retain the weapon identity")
	_expect(slots[0].tooltip_text.contains("R: RELOAD") or slots[0].tooltip_text.contains("R：装填"),
		"the main weapon tooltip must describe R as reload")
	_expect(
		not slots[0].has_node("MainhandBadge"),
		"mainhand slot must not show a role badge over the ammo bar"
	)
	_expect(
		passive_icon.position.y >= 72.0,
		"passive icon must join the skill footer instead of covering the weapon"
	)
	weapon.free()
	root.free()

func _make_weapon(status: Dictionary) -> DummyWeapon:
	var weapon := DummyWeapon.new()
	weapon.ammo_status = status
	return weapon

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
