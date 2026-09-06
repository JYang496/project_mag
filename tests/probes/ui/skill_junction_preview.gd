extends Node2D
const TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
func _ready() -> void:
	var root := Control.new()
	root.position = Vector2(100,100)
	root.size = Vector2(92,124)
	add_child(root)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(icon)
	var weapon: Node = load("res://Player/Weapons/Instances/machine_gun.tscn").instantiate()
	var view := preload("res://UI/scripts/components/weapon_slot_view.gd").new()
	view.setup(root,null)
	view.set_role(true,null,null)
	view.show_weapon(weapon)
	view.frame.call("set_ammo_state",true,0.6,Color("73e7ef"),Color("274650"))
	var disk := preload("res://UI/scripts/components/weapon_skill_state_icon.gd").new()
	disk.size = Vector2(48,48)
	disk.scale = Vector2.ONE * WeaponSelector.SKILL_DISK_SCALE
	disk.position = view.WEAPON_DISK_CENTER + WeaponSelector.SKILL_DISK_CENTER_OFFSET - Vector2(24,24)*WeaponSelector.SKILL_DISK_SCALE
	root.add_child(disk)
	disk.set_effect_id("machine_gun_infinite_chain")
	disk.set_status({"available":true,"ready":true,"unlock_ready":true})
	assert(WeaponSelector.SKILL_DISK_CENTER_OFFSET.length() - 24.0 * WeaponSelector.SKILL_DISK_SCALE > 28.0)
	assert(disk.position.x + 48 * disk.scale.x <= 92)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().get_region(Rect2i(96,166,104,106)).save_png("C:/Users/koalg/.codex/visualizations/2026/09/05/01a073ab-9493-7460-a395-141898905133/weapon-skill-junction-fixed.png")
	print("PASS skill disk clearance and slot bounds")
	weapon.free()
	await TEARDOWN.finish(self,0)
