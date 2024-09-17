extends RayCast2D

var is_casting = false

@onready var duration = 0.5
@onready var player = get_tree().get_first_node_in_group("player")
var hit = false
var target = null

func _ready():
	pass

func _physics_process(delta):
	if target == null:
		target = get_global_mouse_position()
	$Line2D.set_point_position(1,target)
	$Line2D.set_point_position(0,get_parent().global_position)
	
	
