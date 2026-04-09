extends Module
# Applies bonus freeze damage on hit so frost stacks can be seeded by module hits.

var ITEM_NAME := "Cryo Infuser"

@export var freeze_damage_lv1: int = 3
@export var freeze_damage_lv2: int = 4
@export var freeze_damage_lv3: int = 5

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
	var freeze_damage := _get_freeze_damage_by_level()
	if freeze_damage <= 0:
		return
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var attack := Attack.new()
	attack.damage = freeze_damage
	attack.damage_type = Attack.TYPE_FREEZE
	attack.source_node = source_weapon
	attack.source_player = owner_player
	target.damaged(attack)

func _get_freeze_damage_by_level() -> int:
	match module_level:
		3:
			return max(1, freeze_damage_lv3)
		2:
			return max(1, freeze_damage_lv2)
		_:
			return max(1, freeze_damage_lv1)
