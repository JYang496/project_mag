extends SceneTree

const ICON_TARGETS: Array[Dictionary] = [
	{"scene": "res://UI/scenes/shop_weapon_slot.tscn", "paths": ["Background/Image"]},
	{
		"scene": "res://UI/scenes/equipment_slot.tscn",
		"paths": [
			"Background/Image",
			"Background/Sockets/Socket1",
			"Background/Sockets/Socket2",
			"Background/Sockets/Socket3",
		],
	},
	{"scene": "res://UI/scenes/module_slot.tscn", "paths": ["Background/Image"]},
	{"scene": "res://UI/scenes/margin_item_card.tscn", "paths": ["ItemCard/ItemImage/Icon"]},
	{"scene": "res://UI/scenes/margin_upgrade_card.tscn", "paths": ["UpgradeCard/ItemImage/Icon"]},
	{
		"scene": "res://UI/scenes/upgrade_preview.tscn",
		"paths": ["UpgradeCard/ItemImage/Icon", "UpgradeCard/Icon"],
	},
	{"scene": "res://UI/scenes/mecha_select.tscn", "paths": ["MechTexture"]},
]


func _initialize() -> void:
	var failures: Array[String] = []
	for target: Dictionary in ICON_TARGETS:
		_validate_scene(target, failures)
	if failures.is_empty():
		print("UiIconScalingTest: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("UiIconScalingTest: FAIL (%d)" % failures.size())
	quit(1)


func _validate_scene(target: Dictionary, failures: Array[String]) -> void:
	var scene_path := str(target["scene"])
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		failures.append("%s could not be loaded" % scene_path)
		return
	var instance := packed_scene.instantiate()
	for node_path_variant: Variant in target["paths"]:
		var node_path := str(node_path_variant)
		var icon := instance.get_node_or_null(node_path) as TextureRect
		if icon == null:
			failures.append("%s:%s is not a TextureRect" % [scene_path, node_path])
			continue
		if icon.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
			failures.append("%s:%s does not ignore source texture size" % [scene_path, node_path])
		if icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			failures.append("%s:%s does not preserve aspect ratio" % [scene_path, node_path])
	instance.free()
