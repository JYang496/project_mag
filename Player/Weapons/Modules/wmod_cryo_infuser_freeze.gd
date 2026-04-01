extends Module
# Converts part of hit damage into extra freeze damage to seed frost stacks.

var ITEM_NAME := "Cryo Infuser"

@export var ratio_lv1: float = 0.35
@export var ratio_lv2: float = 0.45
@export var ratio_lv3: float = 0.55
@export var max_ratio_cap: float = 0.8

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	var base_damage: int = 1
	if source_weapon and source_weapon.has_method("get_runtime_shot_damage"):
		base_damage = max(1, int(source_weapon.call("get_runtime_shot_damage")))
	elif source_weapon and source_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon.damage))
	var conversion_ratio: float = _get_conversion_ratio_by_level()
	conversion_ratio = clampf(conversion_ratio, 0.0, maxf(max_ratio_cap, 0.0))
	var freeze_damage: int = max(1, int(round(float(base_damage) * conversion_ratio)))
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var damage_data: DamageData = DamageData.new().setup(
		freeze_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_conversion_ratio_by_level() -> float:
	match module_level:
		3:
			return ratio_lv3
		2:
			return ratio_lv2
		_:
			return ratio_lv1
