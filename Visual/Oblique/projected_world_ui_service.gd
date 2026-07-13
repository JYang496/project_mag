class_name ProjectedWorldUiService
extends RefCounted

const LAYER_NAME := "HybridWorldUi"

static func ensure_layer(tree: SceneTree) -> CanvasLayer:
	var existing := tree.root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if existing != null:
		return existing
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = 30
	tree.root.add_child(layer)
	return layer

static func get_hybrid_view(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var views := tree.get_nodes_in_group(&"hybrid_ground_view_3d")
	return views[0] as Node if not views.is_empty() else null

static func project_to_screen(tree: SceneTree, world_position: Vector2, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var view := get_hybrid_view(tree)
	return view.call("project_world_to_screen", world_position) as Vector2 if view != null else fallback

static func project_to_canvas(node: CanvasItem, world_position: Vector2) -> Vector2:
	if node == null or not node.is_inside_tree():
		return world_position
	var view := get_hybrid_view(node.get_tree())
	return view.call("project_world_to_canvas", world_position, node.get_viewport()) as Vector2 if view != null else world_position
