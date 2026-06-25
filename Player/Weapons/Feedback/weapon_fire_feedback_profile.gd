extends Resource
class_name WeaponFireFeedbackProfile

@export var muzzle_flash_scene: PackedScene
@export var recoil_distance: float = 0.0
@export var recoil_duration: float = 0.04
@export var recoil_recover_duration: float = 0.08
@export var recoil_rotation_deg: float = 0.0
@export var camera_trauma: float = 0.0
@export var camera_max_distance: float = 900.0
@export var feedback_cooldown_sec: float = 0.0
@export var fire_category: StringName = &"projectile"
