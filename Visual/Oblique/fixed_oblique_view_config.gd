class_name FixedObliqueViewConfig
extends Resource

@export var enabled: bool = true
@export_range(-20.0, 20.0, 0.5) var fixed_yaw_degrees: float = 0.0
@export_range(0.6, 1.0, 0.01) var ground_vertical_scale: float = 0.90
@export_range(1.0, 1.3, 0.01) var camera_overscan: float = 1.03
@export_range(0.5, 2.0, 0.05) var billboard_scale: float = 1.0
