extends Node

const PANEL_SCENE := "res://UI/scenes/branch_select_panel.tscn"
const TEST_BRANCHES: Array[String] = [
	"res://data/weapon_branches/machine_gun_twin.tres",
	"res://data/weapon_branches/machine_gun_shield.tres",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var panel_scene := load(PANEL_SCENE) as PackedScene
	if panel_scene == null:
		_fail(["BranchSelectPanel scene could not be loaded."])
		return
	var panel := panel_scene.instantiate() as BranchSelectPanel
	if panel == null:
		_fail(["BranchSelectPanel scene did not instantiate as BranchSelectPanel."])
		return
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	var branch_defs: Array[WeaponBranchDefinition] = []
	for path in TEST_BRANCHES:
		var definition := load(path) as WeaponBranchDefinition
		if definition == null:
			failures.append("%s could not be loaded." % path)
			continue
		if definition.icon == null:
			failures.append("%s has no icon." % path)
			continue
		branch_defs.append(definition)
	panel.open_for_weapon(null, branch_defs)
	await get_tree().process_frame
	if not panel.visible:
		failures.append("BranchSelectPanel did not become visible.")
	var buttons := _collect_buttons(panel)
	if buttons.size() != branch_defs.size():
		failures.append("Expected %d branch cards, got %d." % [branch_defs.size(), buttons.size()])
	var icons := _collect_texture_rects(panel)
	if icons.size() < branch_defs.size():
		failures.append("Expected at least %d branch icons, got %d." % [branch_defs.size(), icons.size()])
	for icon in icons:
		if icon.texture == null:
			failures.append("%s has no texture." % icon.get_path())
		if icon.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
			failures.append("%s does not ignore source texture size." % icon.get_path())
		if icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			failures.append("%s does not preserve aspect ratio." % icon.get_path())
	panel.free()
	if failures.is_empty():
		print("BranchSelectPanelUiTest: PASS")
		get_tree().quit(0)
		return
	_fail(failures)

func _collect_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			result.append(child as Button)
		result.append_array(_collect_buttons(child))
	return result

func _collect_texture_rects(node: Node) -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for child in node.get_children():
		if child is TextureRect:
			result.append(child as TextureRect)
		result.append_array(_collect_texture_rects(child))
	return result

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	print("BranchSelectPanelUiTest: FAIL (%d)" % failures.size())
	get_tree().quit(1)
