extends DashBlade
class_name FrostDashBlade

const FROST_FIELD_EFFECT_SCENE: PackedScene = preload("res://Player/Weapons/Effects/frost_field_effect.tscn")
const FROST_ITEM_NAME: String = "Frost Dash Blade"

@export var freeze_finish_ratio: float = 0.35
@export var frost_field_duration_sec: float = 1.2
@export var frost_field_radius: float = 90.0
@export var frost_field_tick_sec: float = 0.4
@export var frost_field_tick_ratio: float = 0.2

const FROST_WEAPON_DATA: Dictionary = {
	"1": {"level": "1", "damage": "34", "range": "360", "dash_speed": "1250", "return_speed": "900", "reload": "1.10", "cost": "12"},
	"2": {"level": "2", "damage": "41", "range": "380", "dash_speed": "1300", "return_speed": "940", "reload": "1.04", "cost": "12"},
	"3": {"level": "3", "damage": "49", "range": "400", "dash_speed": "1360", "return_speed": "980", "reload": "0.98", "cost": "12"},
	"4": {"level": "4", "damage": "59", "range": "420", "dash_speed": "1420", "return_speed": "1040", "reload": "0.92", "cost": "12"},
	"5": {"level": "5", "damage": "71", "range": "440", "dash_speed": "1480", "return_speed": "1100", "reload": "0.86", "cost": "12"},
}

func _ready() -> void:
	ITEM_NAME = FROST_ITEM_NAME
	super._ready()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = FROST_WEAPON_DATA.get(lv, FROST_WEAPON_DATA["1"])
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	attack_range = float(level_data["range"])
	base_dash_speed = float(level_data["dash_speed"])
	base_return_speed = float(level_data["return_speed"])
	base_attack_cooldown = float(level_data["reload"])
	sync_stats()
	_update_attack_range_shape()

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if target == null or not is_instance_valid(target):
		return
	var owner_player: Node = DamageManager.resolve_source_player(self)
	var freeze_damage: int = max(1, int(round(float(damage) * maxf(freeze_finish_ratio, 0.0))))
	var finish_damage: DamageData = DamageData.new().setup(
		freeze_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		self,
		owner_player
	)
	DamageManager.apply_to_target(target, finish_damage)
	_spawn_frost_field(target)

func _spawn_frost_field(target: Node) -> void:
	if not (target is Node2D):
		return
	var field: Node2D = FROST_FIELD_EFFECT_SCENE.instantiate() as Node2D
	if field == null:
		return
	if field.has_method("setup"):
		var tick_damage: int = max(1, int(round(float(damage) * maxf(frost_field_tick_ratio, 0.0))))
		field.call(
			"setup",
			self,
			DamageManager.resolve_source_player(self),
			Attack.TYPE_FREEZE,
			tick_damage,
			maxf(frost_field_tick_sec, 0.05),
			maxf(frost_field_duration_sec, 0.1),
			maxf(frost_field_radius, 8.0),
			false,
			3
		)
	field.global_position = (target as Node2D).global_position
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(field)
