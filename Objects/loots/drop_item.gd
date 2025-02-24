extends Node2D

var item_id : String = "1"
var level := 1
var item : Node2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var detect_area: Area2D = $DetectArea


func _ready() -> void:
	if item_id is String:
		item = load(WeaponData.weapon_list.data[item_id]["res"]).instantiate()
		item.level = level
	sprite.texture = item.sprite.texture
	
func play_animation() -> void:
	var start_position = position
	var rand_pos = get_random_position_in_circle()
	var dest_tween = create_tween()
	dest_tween.tween_property(self,"rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	dest_tween.connect("finished", _on_dest_tween_finished)

func get_random_position_in_circle(radius: float = 50.0) -> Vector2:
	var angle = randf_range(0, TAU)  # TAU is 2*PI in Godot
	var distance = randf() * radius  # Random distance between 0 and radius
	var x = cos(angle) * distance
	var y = sin(angle) * distance
	return Vector2(x, y)

func _on_dest_tween_finished():
	print("finish")
