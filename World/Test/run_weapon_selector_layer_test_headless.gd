extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail("Failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	var selector := ui.weapon_selector as WeaponSelector
	if selector == null:
		_fail("Weapon selector is missing.")
		return
	var overlay := selector.get_node_or_null("CooldownOverlay") as Control
	if overlay == null or overlay.get_parent() != selector:
		_fail("Cooldown overlay must be a direct child of WeaponSelector.")
		return
	if overlay.z_index != 0:
		_fail("Cooldown overlay must share WeaponSelector z layer.")
		return
	for child in overlay.get_children():
		var canvas_item := child as CanvasItem
		if canvas_item != null and canvas_item.z_index != 0:
			_fail("Cooldown ring children must stay on WeaponSelector z layer.")
			return
	print("WeaponSelectorLayerTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("WeaponSelectorLayerTest: %s" % message)
	get_tree().quit(1)
