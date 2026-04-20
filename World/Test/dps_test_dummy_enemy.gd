extends BaseEnemy
class_name DpsTestDummyEnemy

signal damage_received(dummy: DpsTestDummyEnemy, amount: int, attack: Attack, hp_after: int)
signal dummy_died(dummy: DpsTestDummyEnemy, killing_attack: Attack)

@export var max_hp_value: int = 3000

func _ready() -> void:
	super._ready()
	movement_speed = 0.0
	damage = 0
	hp = max(1, max_hp_value)
	is_dead = false
	damage_taken_multiplier = 1.0
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	# Keep dummy stationary.
	velocity = Vector2.ZERO
	move_and_slide()

func damaged(attack: Attack) -> void:
	var hp_before: int = int(hp)
	super.damaged(attack)
	var dealt: int = max(0, hp_before - int(hp))
	if dealt > 0:
		damage_received.emit(self, dealt, attack, int(hp))

func death(killing_attack: Attack = null) -> void:
	is_dead = true
	dummy_died.emit(self, killing_attack)
	queue_free()
