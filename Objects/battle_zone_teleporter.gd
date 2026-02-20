extends Node2D

@onready var detect_area = $DetectArea

var move := false
@onready var tp_disable = $DetectArea/CollisionShape2D.disabled
@onready var texture = $Texture
@onready var enable_timer = $EnableTimer
@onready var depart = $Departure
var origin_position

func _ready() -> void:
	texture.position = depart.position
	if PhaseManager.current_state() != PhaseManager.REWARD:
		self.visible = false
		tp_disable = true


func _physics_process(delta: float) -> void:
	if !move:
		return
	texture.position = texture.position.move_toward(Vector2.ZERO,delta*300)
	if texture.position.distance_to(Vector2.ZERO) < 10:
		move = false
		enable_timer.start()
	
func _on_detect_area_body_entered(body: Node2D) -> void:
	if body is Player and PhaseManager.current_state() == PhaseManager.REWARD:
		return

func move_teleporter() -> void:
	self.visible = true
	move = true


func _on_enable_timer_timeout() -> void:
	tp_disable = false


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	texture.position = depart.position
	self.visible = false
	tp_disable = true
