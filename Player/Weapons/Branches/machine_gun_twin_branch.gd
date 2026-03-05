extends WeaponBranchBehavior
class_name MachineGunTwinBranch

@export var cooldown_multiplier: float = 0.7
@export var extra_spread_deg: float = 4.0
@export var heat_per_shot: float = 0.1
@export var heat_cool_rate: float = 0.18
@export var max_heat: float = 1.0
@export var max_move_slow: float = 0.45

var heat: float = 0.0
var _move_mul_source_id: StringName

func setup(target_weapon: Weapon) -> void:
	super.setup(target_weapon)
	_move_mul_source_id = StringName("twin_mg_heat_%s" % str(target_weapon.get_instance_id()))

func _physics_process(delta: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	heat = move_toward(heat, 0.0, heat_cool_rate * delta)
	_apply_move_speed_penalty()

func get_additional_shot_directions(base_direction: Vector2) -> Array[Vector2]:
	return [base_direction.rotated(deg_to_rad(extra_spread_deg))]

func get_cooldown_multiplier() -> float:
	return cooldown_multiplier

func on_weapon_shot(_base_direction: Vector2) -> void:
	heat = clampf(heat + heat_per_shot, 0.0, max_heat)
	_apply_move_speed_penalty()

func on_removed() -> void:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		PlayerData.player.remove_move_speed_mul(_move_mul_source_id)

func _apply_move_speed_penalty() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var heat_ratio: float = 0.0
	if max_heat > 0.0:
		heat_ratio = clampf(heat / max_heat, 0.0, 1.0)
	var move_mul := clampf(1.0 - max_move_slow * heat_ratio, 0.05, 1.0)
	PlayerData.player.apply_move_speed_mul(_move_mul_source_id, move_mul)
