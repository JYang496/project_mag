extends Control

const HUD_SCENE := preload("res://UI/scenes/runtime/battle_hud.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const WEAPON_SCENES := [
	preload("res://Player/Weapons/Instances/pistol.tscn"),
	preload("res://Player/Weapons/Instances/machine_gun.tscn"),
	preload("res://Player/Weapons/Instances/charged_blaster.tscn"),
]

var _weapons: Array[Node] = []

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.035, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	for index in range(WEAPON_SCENES.size()):
		var weapon_scene: PackedScene = WEAPON_SCENES[index]
		var weapon := weapon_scene.instantiate() as Node
		var status: Dictionary = weapon.call("get_ammo_status") if weapon.has_method("get_ammo_status") else {}
		var max_ammo := maxi(int(status.get("max", 0)), 1)
		if index == 0:
			weapon.set("current_ammo", max_ammo)
		elif index == 1:
			weapon.set("current_ammo", maxi(1, int(floor(float(max_ammo) * 0.2))))
		else:
			weapon.set("current_ammo", maxi(1, int(floor(float(max_ammo) * 0.6))))
			weapon.set("_beam_multi_hit_target_ids", {101: true})
		_weapons.append(weapon)
	PlayerData.player_weapon_list = _weapons.duplicate()
	PlayerData.main_weapon_index = 0
	var hud := HUD_SCENE.instantiate() as Control
	add_child(hud)
	for child in hud.get_children():
		if child.name != "WeaponSelector" and child is CanvasItem:
			child.visible = false
	var selector := hud.get_node("WeaponSelector") as Control
	selector.position = Vector2(32.0, 32.0)
	selector.bind_player_data()
	selector.refresh_slots()
	await get_tree().process_frame
	await get_tree().process_frame
	var qa_failed := false
	var cycle_track := selector.get_node_or_null(
		"CooldownOverlay/PassiveChargeTrack2"
	) as Control
	if cycle_track == null \
			or not cycle_track.visible \
			or not bool(cycle_track.get("show_cycle_progress")) \
			or not is_equal_approx(float(cycle_track.get("cycle_progress")), 1.0 / 3.0):
		qa_failed = true
		push_error("Weapon selector probe must expose a visible 1/3 condition-progress track")
	var output_path := OS.get_environment("WEAPON_SELECTOR_QA_PATH")
	if not output_path.is_empty():
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(output_path)
		if error != OK:
			qa_failed = true
			push_error("Weapon selector screenshot failed: %s" % error_string(error))
	await TEST_TEARDOWN.finish(self, 1 if qa_failed else 0, _reset_probe_state, _weapons)
	_weapons.clear()

func _reset_probe_state() -> void:
	PlayerData.player_weapon_list = []
	PlayerData.main_weapon_index = 0
