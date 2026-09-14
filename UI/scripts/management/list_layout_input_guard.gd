extends RefCounted

# New rows must receive pointer input only after containers finish sorting them.
static func settle(roots: Array[Node]) -> void:
	if roots.is_empty() or not is_instance_valid(roots[0]) or not roots[0].is_inside_tree():
		return
	var buttons: Array[Button] = []
	var filters: Array[int] = []
	for root in roots:
		_collect_buttons(root, buttons, filters)
	var tree := roots[0].get_tree()
	await tree.process_frame
	await tree.process_frame
	for index in range(buttons.size()):
		var button := buttons[index]
		if is_instance_valid(button) and button.is_inside_tree():
			button.mouse_filter = filters[index]

static func _collect_buttons(root: Node, buttons: Array[Button], filters: Array[int]) -> void:
	if root is Button:
		buttons.append(root)
		filters.append(root.mouse_filter)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		_collect_buttons(child, buttons, filters)
