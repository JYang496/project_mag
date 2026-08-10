extends Resource
class_name WeaponFireFeedbackProfile

@export var muzzle_flash_scene: PackedScene
@export_group("Muzzle Signature")
@export_range(0.65, 1.6, 0.05) var muzzle_scale := 1.0
@export_range(0.65, 1.6, 0.05) var muzzle_length_scale := 1.0
@export_range(0.65, 1.6, 0.05) var muzzle_width_scale := 1.0
@export_range(0.0, 0.65, 0.05) var muzzle_tint_strength := 0.0
@export var muzzle_tint := Color.WHITE
@export_group("")
@export var recoil_distance: float = 0.0
@export var recoil_duration: float = 0.04
@export var recoil_recover_duration: float = 0.08
@export var recoil_rotation_deg: float = 0.0
@export var camera_trauma: float = 0.0
@export var camera_max_distance: float = 900.0
@export var feedback_cooldown_sec: float = 0.0
@export var fire_category: StringName = &"projectile"
@export var fire_audio_stream: AudioStream
@export var fire_audio_volume_db: float = -8.0
@export var fire_audio_pitch_scale: float = 1.0
@export var fire_audio_pitch_random: float = 0.04
@export var hit_audio_stream: AudioStream
@export var hit_audio_volume_db: float = -10.0
@export var hit_audio_pitch_scale: float = 1.0
@export var hit_audio_pitch_random: float = 0.05
@export var hit_feedback_cooldown_sec: float = 0.04
@export var audio_max_distance: float = 900.0
@export var audio_attenuation: float = 1.0
