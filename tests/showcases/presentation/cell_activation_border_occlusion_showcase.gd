extends Node

const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const UNIT_BILLBOARD := preload("res://Visual/Oblique/unit_billboard_visual_2d.gd")
const PLAYER_TEXTURE := preload("res://asset/images/characters/pixel/idle_bottom.png")

const TEST_POSITIONS := [
	{"label": "1/3 INSIDE — player 46 px inside right border", "position": Vector2(199.76, 0.0)},
	{"label": "2/3 ON BORDER — player centered on right border", "position": Vector2(245.76, 0.0)},
	{"label": "3/3 OUTSIDE — player 54 px beyond right border", "position": Vector2(299.76, 0.0)},
]
const AUTO_STEP_SECONDS := 3.0

class ShowcaseBoard:
	extends Node2D
	var cells: Array = []
	var _board_active := true

	func get_cells() -> Array:
		return cells

var _player_owner: Node2D
var _activation: CellActivationVisual
var _view: Node
var _cell: Cell
var _state_label: Label
var _position_index := 0
var _elapsed := 0.0


func _ready() -> void:
	var board := ShowcaseBoard.new()
	board.name = "Board"
	add_child(board)

	_cell = CELL_SCENE.instantiate() as Cell
	_cell.name = "OcclusionTestCell"
	_cell.position = Vector2(-256.0, -256.0)
	board.add_child(_cell)
	board.cells.append(_cell)
	_activation = _cell.get_node("ActivationVisual") as CellActivationVisual
	_activation.highlight_amount = 1.0

	_player_owner = Node2D.new()
	_player_owner.name = "BorderTestPlayer"
	add_child(_player_owner)
	var sprite := Sprite2D.new()
	sprite.name = "PlayerBillboard"
	sprite.texture = PLAYER_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0.0, -13.0)
	sprite.set_script(UNIT_BILLBOARD)
	_player_owner.add_child(sprite)

	_view = HYBRID_VIEW.new()
	_view.name = "HybridGroundView3D"
	_view.board_path = NodePath("../Board")
	add_child(_view)

	_create_overlay()
	_apply_position(0)
	call_deferred("_capture_all_states")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= AUTO_STEP_SECONDS:
		_apply_position((_position_index + 1) % TEST_POSITIONS.size())
	if Input.is_key_pressed(KEY_LEFT):
		_apply_position((_position_index - 1 + TEST_POSITIONS.size()) % TEST_POSITIONS.size())
	elif Input.is_key_pressed(KEY_RIGHT):
		_apply_position((_position_index + 1) % TEST_POSITIONS.size())


func _apply_position(index: int) -> void:
	_position_index = index
	_elapsed = 0.0
	var state := TEST_POSITIONS[_position_index] as Dictionary
	_player_owner.position = state.position as Vector2
	if _activation != null:
		_activation.highlight_amount = 1.0
	if _state_label != null:
		_state_label.text = "%s\nExpected: all non-overlapping portions of the right border remain visible" % str(state.label)


func _create_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(20.0, 18.0)
	panel.size = Vector2(620.0, 70.0)
	panel.color = Color(0.01, 0.025, 0.04, 0.88)
	layer.add_child(panel)
	_state_label = Label.new()
	_state_label.position = Vector2(16.0, 10.0)
	_state_label.size = Vector2(590.0, 52.0)
	_state_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_state_label)


func _capture_all_states() -> void:
	for index in range(TEST_POSITIONS.size()):
		_apply_position(index)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := OS.get_temp_dir().path_join("magarena-border-occlusion-%d.png" % (index + 1))
		var error := image.save_png(path)
		var entries := _view.get("_activation_meshes") as Dictionary
		var entry := entries.get(_cell.get_instance_id(), {}) as Dictionary
		var mesh := entry.get("mesh") as MeshInstance3D
		print("SHOWCASE_STATE state=%d highlight=%.2f mesh_visible=%s outline_alpha=%s priority=%s" % [
			index + 1,
			_activation.highlight_amount,
			str(mesh != null and mesh.visible),
			str(mesh.get_instance_shader_parameter("outline_alpha") if mesh != null else null),
			str((_view.get("_activation_material") as ShaderMaterial).render_priority),
		])
		print("SHOWCASE_CAPTURE state=%d path=%s error=%d" % [index + 1, path, error])
	print("SHOWCASE_READY cell activation border occlusion capture complete")
