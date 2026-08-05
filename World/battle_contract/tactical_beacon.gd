extends Area2D

signal presence_changed(beacon_id: int, player_inside: bool, enemy_count: int)

const ProjectedVisual := preload("res://World/battle_contract/beacon_projected_visual.gd")
const VISUAL_LAYER_NAME := "BattleContractWorldVisuals"
const VISUAL_LAYER_ORDER := -1

@export var beacon_id := 0
@export var visual_kind: StringName = &"operation":
	set(value):
		visual_kind = value
		_apply_ground_style()

var _player_inside := false
var _enemies: Dictionary = {}
var _progress := 0.0
var _projected_visual: Control
var _removal_scheduled := false
var _visually_completed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_ground_style()
	call_deferred("_setup_projected_visual")

func _setup_projected_visual() -> void:
	if not is_inside_tree() or _projected_visual != null:
		return
	_projected_visual = ProjectedVisual.new()
	_projected_visual.name = "BeaconProjectedVisual_%s" % get_instance_id()
	_ensure_visual_layer().add_child(_projected_visual)
	_projected_visual.configure(self, visual_kind, beacon_id, _get_footprint_size())
	_projected_visual.set_progress(_progress)
	_projected_visual.set_presence(_player_inside, _enemies.size())

func _ensure_visual_layer() -> CanvasLayer:
	var existing := get_tree().root.get_node_or_null(VISUAL_LAYER_NAME) as CanvasLayer
	if existing != null:
		return existing
	var layer := CanvasLayer.new()
	layer.name = VISUAL_LAYER_NAME
	layer.layer = VISUAL_LAYER_ORDER
	get_tree().root.add_child(layer)
	return layer

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _progress >= 1.0 and visual_kind != &"extraction":
		_visually_completed = true
	if _projected_visual != null:
		_projected_visual.set_progress(_progress)

func play_completion() -> void:
	_visually_completed = true
	if _projected_visual != null:
		_projected_visual.play_completion()

func play_completion_and_remove() -> void:
	if _removal_scheduled:
		return
	_removal_scheduled = true
	set_deferred("monitoring", false)
	if _projected_visual != null:
		_projected_visual.play_completion_and_remove()
		_projected_visual = null
	var timer := get_tree().create_timer(0.74)
	timer.timeout.connect(queue_free)

func is_visually_completed() -> bool:
	return _visually_completed

func _exit_tree() -> void:
	if _projected_visual != null and is_instance_valid(_projected_visual):
		_projected_visual.queue_free()
	_projected_visual = null

func _on_body_entered(body: Node2D) -> void:
	if body == PlayerData.player:
		_player_inside = true
	elif body.is_in_group("enemies"):
		_enemies[body.get_instance_id()] = body
	_emit_presence()

func _on_body_exited(body: Node2D) -> void:
	if body == PlayerData.player:
		_player_inside = false
	else:
		_enemies.erase(body.get_instance_id())
	_emit_presence()

func _emit_presence() -> void:
	for id in _enemies.keys():
		if not is_instance_valid(_enemies[id]):
			_enemies.erase(id)
	if _projected_visual != null:
		_projected_visual.set_presence(_player_inside, _enemies.size())
	presence_changed.emit(beacon_id, _player_inside, _enemies.size())

func _apply_ground_style() -> void:
	var ground := get_node_or_null("OuterGround")
	if ground == null:
		return
	match visual_kind:
		&"containment":
			ground.visual_modulate = Color(0.70, 0.18, 0.78, 0.24)
		&"extraction":
			ground.visual_modulate = Color(0.50, 0.86, 0.20, 0.22)
		_:
			ground.visual_modulate = Color(0.22, 0.68, 0.82, 0.18)

func _get_footprint_size() -> Vector2:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := shape_node.shape as RectangleShape2D if shape_node != null else null
	return rectangle.size if rectangle != null else Vector2(140.0, 140.0)
