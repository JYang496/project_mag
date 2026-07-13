extends Node2D

const FALLBACK_MODULE_ICON: Texture2D = preload("res://asset/images/modules/missing_module.png")
const FixedObliqueProjectionType := preload("res://Visual/Oblique/fixed_oblique_projection_2d.gd")

@export var item_id : String = "1"
@export var level := 3
@export var module_scene: PackedScene
@export var module_level: int = 1
@export var spawn_ready: bool = false
@export var auto_collect_on_landing: bool = false
@export var trajectory_animation_managed: bool = false
@export var settle_unclaimed_on_battle_start: bool = false
var item : Node2D
var module_instance: Module
var player_near : bool = false
var _resolved: bool = false
@onready var spin_root: Node2D = $BillboardVisual/SpinRoot
@onready var sprite: Sprite2D = $BillboardVisual/SpinRoot/Sprite2D
@onready var detect_area: Area2D = $DetectArea
@onready var interact_hint: Label = $BillboardVisual/InteractHint


func _ready() -> void:
	z_index = int(round(FixedObliqueProjectionType.get_projected_depth(global_position) / 16.0))
	if settle_unclaimed_on_battle_start:
		add_to_group(&"unclaimed_battle_rewards")
	if spawn_ready:
		detect_area.set_collision_mask_value(1, true)
	if module_scene:
		module_instance = module_scene.instantiate() as Module
		if module_instance == null:
			push_warning("DropItem failed to instantiate module scene.")
			queue_free()
			return
		module_instance.set_module_level(module_level)
		var module_sprite: Sprite2D = module_instance.get_node_or_null("%Sprite") as Sprite2D
		if module_sprite and module_sprite.texture:
			sprite.texture = module_sprite.texture
		else:
			sprite.texture = FALLBACK_MODULE_ICON
		if not spawn_ready and not trajectory_animation_managed:
			play_animation()
		return
	if item_id is String:
		var weapon_def = DataHandler.read_weapon_data(str(item_id))
		if weapon_def == null:
			push_warning("DropItem failed to load weapon id=%s" % str(item_id))
			queue_free()
			return
		item = weapon_def.scene.instantiate()
		sprite.texture = weapon_def.icon
		item.level = level
		if not spawn_ready and not trajectory_animation_managed:
			play_animation()

func _input(event: InputEvent) -> void:
	if not _resolved and player_near and event.is_action_pressed("INTERACT"):
		if module_instance:
			_pick_module()
			return
		_pick_weapon()

func collect_automatically() -> void:
	if _resolved:
		return
	if module_instance:
		_resolved = true
		InventoryData.obtain_module(module_instance)
		module_instance = null
		queue_free()
		return
	_pick_weapon()

func settle_unclaimed() -> void:
	if _resolved:
		return
	_resolved = true
	set_process_input(false)
	interact_hint.visible = false
	player_near = false
	if module_instance:
		InventoryData.sell_unclaimed_module(module_instance)
		module_instance = null
		queue_free()
		return
	if item and is_instance_valid(item):
		InventoryData.settle_unclaimed_weapon_reward(item as Weapon)
		item = null
	queue_free()

func _pick_weapon() -> void:
	if _resolved:
		return
	_resolved = true
	if item == null or not is_instance_valid(item):
		queue_free()
		return
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_weapon_pickup_selection"):
		var queued := bool(ui.request_weapon_pickup_selection(item as Weapon))
		if queued:
			item = null
			interact_hint.visible = false
			player_near = false
			set_process_input(false)
			queue_free()
			return
	InventoryData.obtain_weapon_reward(item as Weapon)
	item = null
	queue_free()

func _pick_module() -> void:
	if _resolved:
		return
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_module_pickup_selection"):
		var queued := bool(ui.request_module_pickup_selection(module_instance, Callable(self, "_on_module_selection_completed")))
		if queued:
			_resolved = true
			interact_hint.visible = false
			player_near = false
			set_process_input(false)
			return
	if ui and is_instance_valid(ui) and ui.has_method("request_module_equip_selection"):
		var opened: bool = bool(ui.request_module_equip_selection(module_instance, Callable(self, "_on_module_selection_completed")))
		if opened:
			_resolved = true
			interact_hint.visible = false
			player_near = false
			set_process_input(false)
			return
	_resolved = true
	InventoryData.obtain_module(module_instance)
	module_instance = null
	queue_free()

func _on_module_selection_completed(assigned: bool) -> void:
	if not assigned and module_instance and is_instance_valid(module_instance):
		InventoryData.obtain_module(module_instance)
	module_instance = null
	queue_free()
	
func play_animation() -> void:
	var dest_tween = create_tween()
	if spin_root == null:
		activate_pickup_detection()
		return
	dest_tween.tween_property(spin_root, "rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	dest_tween.connect("finished", _on_dest_tween_finished)

func activate_pickup_detection() -> void:
	spawn_ready = true
	detect_area.set_collision_mask_value(1,true)

func _on_dest_tween_finished() -> void:
	activate_pickup_detection()

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		interact_hint.visible = true
		player_near = true


func _on_detect_area_body_exited(body: Node2D) -> void:
	if body is Player:
		interact_hint.visible = false
		player_near = false
