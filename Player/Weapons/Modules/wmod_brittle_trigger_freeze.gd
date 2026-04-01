extends Module
# Deals bonus physical damage when hitting targets with high frost stacks.

var ITEM_NAME := "Brittle Trigger"

@export var ratio_lv1: float = 0.20
@export var ratio_lv2: float = 0.28
@export var ratio_lv3: float = 0.36
@export var required_frost_stacks: int = 3
@export var target_icd_sec: float = 0.8

var _target_last_proc_msec: Dictionary = {}

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
	if not target.has_meta("_incoming_damage_state"):
		return
	if not target.has_method("damaged"):
		return
	var state_variant: Variant = target.get_meta("_incoming_damage_state", {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var frost_stacks: int = int(state.get("frost_stacks", 0))
	if frost_stacks < max(1, required_frost_stacks):
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_proc_msec: int = int(_target_last_proc_msec.get(target_id, 0))
	if now_msec - last_proc_msec < int(maxf(target_icd_sec, 0.0) * 1000.0):
		return
	_target_last_proc_msec[target_id] = now_msec
	var base_damage: int = 1
	if source_weapon and source_weapon.has_method("get_runtime_shot_damage"):
		base_damage = max(1, int(source_weapon.call("get_runtime_shot_damage")))
	elif source_weapon and source_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon.damage))
	var bonus_ratio: float = _get_bonus_ratio_by_level()
	var bonus_damage: int = max(1, int(round(float(base_damage) * maxf(bonus_ratio, 0.0))))
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var damage_data: DamageData = DamageData.new().setup(
		bonus_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_bonus_ratio_by_level() -> float:
	match module_level:
		3:
			return ratio_lv3
		2:
			return ratio_lv2
		_:
			return ratio_lv1
