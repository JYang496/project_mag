extends Weapon
class_name Melee

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

func setup_melee_attack_range_area(area: Area2D) -> void:
	_ensure_components()
	melee_contact_helper.setup_attack_range_area(area)

func center_melee_attack_range_area(area: Area2D) -> void:
	_ensure_components()
	melee_contact_helper.center_attack_range_area(area)

func supports_melee_contact() -> bool:
	return true
