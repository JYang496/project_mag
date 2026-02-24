extends Node2D

@export var item_id : String = "1"
@export var level := 3
var item : Node2D
var player_near : bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var detect_area: Area2D = $DetectArea
@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
	if item_id is String:
		var weapon_def = DataHandler.read_weapon_data(str(item_id))
		if weapon_def == null:
			push_warning("DropItem failed to load weapon id=%s" % str(item_id))
			queue_free()
			return
		item = weapon_def.scene.instantiate()
		sprite.texture = weapon_def.icon
		item.level = level
		play_animation()

func _input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("INTERACT"):
		PlayerData.player.create_weapon(item)
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
