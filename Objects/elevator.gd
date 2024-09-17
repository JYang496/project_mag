extends Sprite2D

var spawn_position:Vector2
var to_position:Vector2
var body_enetered = []

@export var dest_position:Vector2
@export var speed = 1

# Called when the node enters the scene tree for the first time.
func _ready(): 
	spawn_position = position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if position.distance_to(to_position) > 0.1:
		move()

func move():
	if not body_enetered.is_empty():
		for i in range(body_enetered.size()):
			body_enetered[0].position += position.direction_to(to_position).normalized() * speed
	position += position.direction_to(to_position).normalized() * speed

	
func _on_area_2d_body_entered(body):
	body_enetered.append(body)
	to_position = dest_position
	set_z_index(-1)


func _on_area_2d_body_exited(body):
	if body_enetered.has(body):
		body_enetered.erase(body)
	to_position = spawn_position
	set_z_index(0)
