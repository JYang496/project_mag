extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const WEAPON_SELECTOR := preload("res://UI/scripts/weapon_selector.gd")
const WEAPON_STATUS_BAR := preload("res://UI/scripts/weapon_slot_status_bar.gd")
const WEAPON_SWITCH_CONTROLLER := preload("res://UI/scripts/components/weapon_switch_controller.gd")
const WEAPON_SLOT_VIEW := preload("res://UI/scripts/components/weapon_slot_view.gd")
const WEAPON_SELECTOR_PASSIVE_PRESENTER := preload("res://UI/scripts/components/weapon_selector_passive_presenter.gd")
const WEAPON_SELECTOR_READABILITY_PRESENTER := preload("res://UI/scripts/components/weapon_selector_readability_presenter.gd")
const WEAPON_SKILL_CHARGE_TRACK := preload("res://UI/scripts/weapon_skill_charge_track.gd")
const WEAPON_TRIGGER_FEEDBACK := preload("res://UI/scripts/weapon_trigger_feedback.gd")

class DummyWeapon:
	extends Weapon
	var ammo_status: Dictionary = {}
	var passive_status: Dictionary = {}
	var active_supported := false

	func get_ammo_status() -> Dictionary:
		return ammo_status.duplicate()

	func get_passive_status() -> Dictionary:
		return passive_status.duplicate()

	func has_weapon_active_skill() -> bool:
		return active_supported

var _failed := false
var _selector

func _ready() -> void:
	_selector = WEAPON_SELECTOR.new()
	_test_full_mainhand_state()
	_test_low_and_empty_states()
	_test_reload_progress()
	_test_non_ammo_weapon_hides_bar()
	_test_top_bar_is_inset_from_frame()
	_test_ammo_label_is_centered_above_mainhand()
	_test_ammo_label_uses_text_only_status()
	_test_weapon_order_stays_fixed_when_mainhand_changes()
	_test_mainhand_slot_expands_without_reordering()
	_test_weapon_icon_follows_mainhand_role()
	_test_weapon_skill_footer_modes()
	_test_passive_feedback_ignores_routine_weapon_events()
	_test_active_skill_feedback_rules()
	_test_skill_hint_tracks_active_support()
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

func _test_top_bar_is_inset_from_frame() -> void:
	var bar = WEAPON_STATUS_BAR.new()
	bar.size = Vector2(96.0, 72.0)
	bar.placement = WeaponSlotStatusBar.Placement.TOP
	bar.top_offset = 8.0
	var rect: Rect2 = bar.get_bar_rect()
	_expect(is_equal_approx(rect.position.y, 8.0), "ammo bar must be inset below the top frame")
	_expect(rect.position.y >= 8.0, "ammo bar must retain visible separation from the frame")
	bar.free()

func _test_ammo_label_is_centered_above_mainhand() -> void:
	var rect: Rect2 = _selector.call(
		"get_weapon_availability_label_rect",
		Vector2(96.0, 72.0),
		true
	)
	_expect(rect.end.y <= 0.0, "mainhand ammo label must sit above the slot")
	_expect(
		is_equal_approx(rect.get_center().x, 48.0),
		"mainhand ammo label must be horizontally centered over the slot"
	)

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

func _test_mainhand_slot_expands_without_reordering() -> void:
	var controller = WEAPON_SWITCH_CONTROLLER.new()
	var rects: Array[Rect2] = controller.build_slot_rects(
		4,
		2,
		Vector2(72.0, 72.0),
		Vector2(96.0, 72.0),
		8.0
	)
	_expect(rects.size() == 4, "layout must retain all four weapon slots")
	_expect(rects[2].size == Vector2(96.0, 72.0), "current mainhand slot must use the expanded HUD size")
	_expect(rects[0].size == Vector2(72.0, 72.0), "non-mainhand slot 0 must retain offhand size")
	_expect(rects[1].size == Vector2(72.0, 72.0), "non-mainhand slot 1 must retain offhand size")
	_expect(rects[3].size == Vector2(72.0, 72.0), "non-mainhand slot 3 must retain offhand size")
	for slot_index in range(1, rects.size()):
		_expect(
			rects[slot_index].position.x > rects[slot_index - 1].position.x,
			"expanded mainhand layout must preserve left-to-right weapon order"
		)

func _test_weapon_icon_follows_mainhand_role() -> void:
	var slot_root := Control.new()
	slot_root.size = Vector2(96.0, 72.0)
	var background := TextureRect.new()
	background.name = "Background"
	slot_root.add_child(background)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER)
	slot_root.add_child(icon)
	var slot_view = WEAPON_SLOT_VIEW.new()
	slot_view.setup(slot_root, null)
	var source_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	source_image.fill(Color.TRANSPARENT)
	source_image.fill_rect(Rect2i(5, 4, 6, 8), Color.WHITE)
	var source_texture := ImageTexture.create_from_image(source_image)
	icon.texture = source_texture
	slot_view.set_role(true, null, null)
	_expect(
		is_equal_approx(icon.rotation_degrees, -45.0),
		"weapon icons must use a 45-degree upward angle"
	)
	var mainhand_bounds := _rotated_rect_size(icon.size, icon.rotation)
	_expect(
		mainhand_bounds.x <= slot_root.size.x and mainhand_bounds.y <= slot_root.size.y,
		"rotated mainhand icon must stay inside its slot"
	)
	_expect(
		mainhand_bounds.y >= slot_root.size.y - 8.0,
		"mainhand icon must use nearly all available slot height"
	)
	_expect(
		slot_view.icon_shadow != null,
		"weapon icons must receive a silhouette shadow against dynamic backgrounds"
	)
	slot_root.size = Vector2(72.0, 72.0)
	slot_view.set_role(false, null, null)
	var offhand_bounds := _rotated_rect_size(icon.size, icon.rotation)
	_expect(
		offhand_bounds.x <= slot_root.size.x and offhand_bounds.y <= slot_root.size.y,
		"rotated offhand icon must stay inside its slot"
	)
	_expect(
		offhand_bounds.y >= slot_root.size.y - 10.0,
		"offhand icon must use nearly all available slot height"
	)
	_expect(
		background.modulate.a < 1.0 and icon.modulate.a < 1.0,
		"offhand frame and weapon must be quieter than the mainhand"
	)
	var cropped_texture: Texture2D = slot_view.call("_crop_texture_to_content", source_texture)
	_expect(cropped_texture is AtlasTexture, "transparent weapon margins must be cropped for HUD display")
	if cropped_texture is AtlasTexture:
		var crop_region := (cropped_texture as AtlasTexture).region
		_expect(
			crop_region.size.x < 16.0 and crop_region.size.y < 16.0,
			"weapon crop must tighten the visible silhouette"
		)
	slot_root.free()

func _rotated_rect_size(rect_size: Vector2, rotation_radians: float) -> Vector2:
	var cosine := absf(cos(rotation_radians))
	var sine := absf(sin(rotation_radians))
	return Vector2(
		rect_size.x * cosine + rect_size.y * sine,
		rect_size.x * sine + rect_size.y * cosine
	)

func _test_weapon_skill_footer_modes() -> void:
	var presenter = WEAPON_SELECTOR_PASSIVE_PRESENTER.new()
	var weapon := DummyWeapon.new()
	var hidden: Dictionary = presenter.resolve_state(weapon)
	_expect(not bool(hidden.get("visible", true)), "weapons with no skill must hide the footer")
	weapon.passive_status = {
		"id": "single_passive",
		"state": "charging",
		"progress": 0.5,
		"charge_current": 0,
		"charge_max": 1,
	}
	var continuous: Dictionary = presenter.resolve_state(weapon)
	_expect(
		continuous.get("display_mode") == &"continuous",
		"passive-only single-state weapons must use one continuous footer track"
	)
	weapon.passive_status.charge_max = 3
	weapon.passive_status.charge_current = 1
	weapon.passive_status.progress_role = "trigger_condition"
	var segmented: Dictionary = presenter.resolve_state(weapon)
	_expect(
		segmented.get("display_mode") == &"segmented",
		"multi-charge weapon skills must use a segmented footer track"
	)
	_expect(
		bool(segmented.get("cycle_visible", false)),
		"multi-charge trigger progress must use a separate auxiliary track"
	)
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
	charge_track.show_cycle_progress = true
	charge_track.cycle_progress = 0.65
	charge_track.size = status_bar.size
	_expect(charge_track.get_segment_rects().size() == 3, "multi-charge footer must expose one segment per charge")
	_expect(
		charge_track.get_segment_fill_ratios() == [1.0, 0.0, 0.0],
		"charge pips must remain discrete while auxiliary progress grows"
	)
	_expect(
		charge_track.get_cycle_rect().has_area(),
		"multi-charge condition progress must occupy its own thin track"
	)
	charge_track.trigger_flash = 1.0
	_expect(is_equal_approx(charge_track.trigger_flash, 1.0), "triggered segmented track must expose a full flash state")
	weapon.free()
	slot.free()
	status_bar.free()
	charge_track.free()

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
	weapon.free()

func _test_active_skill_feedback_rules() -> void:
	_expect(
		_selector.call("_should_play_active_failure_feedback", "cd", true),
		"supported active skills must show cooldown failure feedback"
	)
	_expect(
		_selector.call("_should_play_active_failure_feedback", "resource", true),
		"supported active skills must show resource failure feedback"
	)
	_expect(
		not _selector.call("_should_play_active_failure_feedback", "phase", true),
		"non-combat phase rejection must not flash the weapon slot"
	)
	_expect(
		not _selector.call("_should_play_active_failure_feedback", "condition", false),
		"passive-only weapons must not show active-skill failure feedback"
	)
	var feedback = WEAPON_TRIGGER_FEEDBACK.new()
	feedback.intensity = 1.5
	_expect(is_equal_approx(feedback.intensity, 1.0), "whole-slot trigger feedback intensity must clamp safely")
	feedback.free()

func _test_skill_hint_tracks_active_support() -> void:
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
	var hint := root.get_node("SkillHint") as Label
	var passive_icon := slots[0].get_node("PassiveIcon") as Control
	_expect(not hint.visible, "passive-only main weapons must hide the active-skill key hint")
	_expect(
		not slots[0].has_node("MainhandBadge"),
		"mainhand slot must not show a role badge over the ammo bar"
	)
	_expect(
		passive_icon.position.y >= 72.0,
		"passive icon must join the skill footer instead of covering the weapon"
	)
	weapon.active_supported = true
	presenter.update_slot(0, weapon, true)
	_expect(hint.visible, "weapons with an active skill must show the active-skill key hint")
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
