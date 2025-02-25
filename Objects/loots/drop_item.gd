extends Node2D

var item_id : String = "1"
var level := 1
var item : Node2D
var player_near : bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var detect_area: Area2D = $DetectArea
@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
	if item_id is String:
		item = load(WeaponData.weapon_list.data[item_id]["res"]).instantiate()
		sprite.texture = load(WeaponData.weapon_list.data[item_id]["img"])
		item.level = level
		play_animation()
	
func play_animation() -> void:
	var start_position = position
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
