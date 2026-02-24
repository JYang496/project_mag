extends Effect
class_name DmgUpOnDeath

@onready var detect_area: Area2D = $DetectArea
@export var dmg_up_per_kill : int = 2
var _host_weapon: Weapon

func _ready() -> void:
	supports_melee = true
	super._ready()
	if melee:
		_host_weapon = melee
	elif projectile and projectile.get("source_weapon") != null:
		_host_weapon = projectile.source_weapon

func _on_detect_area_area_entered(area: Area2D) -> void:
	if area is HurtBox and area.hurtbox_owner.is_in_group("enemies"):
		# Check if the signal is already connected before attempting to connect
		if not area.hurtbox_owner.is_connected("enemy_death", Callable(self, "_on_enemy_death")):
			area.hurtbox_owner.connect("enemy_death", Callable(self, "_on_enemy_death"))

func _on_enemy_death() -> void:
	if _host_weapon and _host_weapon.get("damage") != null:
		_host_weapon.damage += dmg_up_per_kill
	elif projectile and "damage" in projectile:
		projectile.damage += dmg_up_per_kill

func _on_detect_area_area_exited(area: Area2D) -> void:
	if area is HurtBox and area.hurtbox_owner.is_in_group("enemies"):
		# Check if the signal is already connected before attempting to connect
		if area.hurtbox_owner.is_connected("enemy_death", Callable(self, "_on_enemy_death")):
			area.hurtbox_owner.disconnect("enemy_death", Callable(self, "_on_enemy_death"))
