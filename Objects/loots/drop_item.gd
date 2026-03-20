extends Node2D

const FALLBACK_MODULE_ICON: Texture2D = preload("res://Textures/test/star.png")

@export var item_id : String = "1"
@export var level := 3
@export var module_scene: PackedScene
@export var module_level: int = 1
@export var spawn_ready: bool = false
var item : Node2D
var module_instance: Module
var player_near : bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var detect_area: Area2D = $DetectArea
@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
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
		if not spawn_ready:
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
		if not spawn_ready:
			play_animation()

func _input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("INTERACT"):
		if module_instance:
			_pick_module()
			return
		PlayerData.player.create_weapon(item)
		queue_free()

func _pick_module() -> void:
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_module_equip_selection"):
		var opened: bool = bool(ui.request_module_equip_selection(module_instance, Callable(self, "_on_module_selection_completed")))
		if opened:
			interact_hint.visible = false
			player_near = false
			set_process_input(false)
			return
	InventoryData.obtain_module(module_instance)
	queue_free()

func _on_module_selection_completed(assigned: bool) -> void:
	if not assigned and module_instance and is_instance_valid(module_instance):
		InventoryData.obtain_module(module_instance)
	queue_free()
	
func play_animation() -> void:
	var dest_tween = create_tween()
	dest_tween.tween_property(self,"rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	dest_tween.connect("finished", _on_dest_tween_finished)

func _on_dest_tween_finished():
	detect_area.set_collision_mask_value(1,true)

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		interact_hint.visible = true
		player_near = true


func _on_detect_area_body_exited(body: Node2D) -> void:
	if body is Player:
		interact_hint.visible = false
		player_near = false
