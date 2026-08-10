extends Weapon
class_name Melee

@export_range(0.0, 45.0, 0.5) var attack_alignment_tolerance_degrees: float = 5.0

var melee_contact_helper: MeleeContactHelper = MeleeContactHelper.new()

func _ready() -> void:
	super._ready()
	_ensure_components()

func _ensure_components() -> void:
	if melee_contact_helper == null:
		melee_contact_helper = MeleeContactHelper.new()
	melee_contact_helper.setup(self)

# Shared melee rule: attack-range queries should be centered on player.
func get_melee_range_center() -> Vector2:
	_ensure_components()
	return melee_contact_helper.get_range_center()

func get_auto_fire_target_origin() -> Vector2:
	return get_melee_range_center()

func setup_melee_attack_range_area(area: Area2D) -> void:
	_ensure_components()
	melee_contact_helper.setup_attack_range_area(area)

func center_melee_attack_range_area(area: Area2D) -> void:
	_ensure_components()
	melee_contact_helper.center_attack_range_area(area)

# Shared melee attack gate: entering range does not bypass the weapon's turn speed.
# Returns true only after the attack anchor has turned close enough to the target.
func turn_melee_anchor_toward_attack(
		anchor: Node2D,
		world_target: Vector2,
		delta: float,
		rotation_offset: float = deg_to_rad(90.0)
) -> bool:
	if anchor == null or not is_instance_valid(anchor):
		return false
	var direction := world_target - anchor.global_position
	if direction == Vector2.ZERO:
		return true
	var target_rotation := direction.angle() + rotation_offset
	var max_step := deg_to_rad(maxf(turn_speed_degrees_per_second, 0.0)) * maxf(delta, 0.0)
	anchor.global_rotation = rotate_toward(anchor.global_rotation, target_rotation, max_step)
	var tolerance := deg_to_rad(maxf(attack_alignment_tolerance_degrees, 0.0))
	return absf(angle_difference(anchor.global_rotation, target_rotation)) <= tolerance

func supports_melee_contact() -> bool:
	return true
