extends Node2D

@export var player_scene: PackedScene = preload("res://Player/Mechas/scenes/Player.tscn")
@export var dummy_scene: PackedScene = preload("res://World/Test/dps_test_dummy_enemy.tscn")
@export var dummy_texture: Texture2D = preload("res://Textures/test/square.png")
@export var weapon_level: int = 7
@export var dummy_hp: int = 20000
@export var cannon_spectator_offsets: Array[Vector2] = [
	Vector2(0.0, -96.0),
	Vector2(0.0, 96.0),
	Vector2(0.0, 220.0),
]

@onready var spawn_root: Node2D = $SpawnRoot
@onready var player_spawn: Marker2D = $SpawnRoot/PlayerSpawn
@onready var target_spawn: Marker2D = $SpawnRoot/TargetSpawn
@onready var target_root: Node2D = $SpawnRoot/Targets
@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var weapon_label: Label = $UI/Panel/VBox/WeaponLabel
@onready var heat_label: Label = $UI/Panel/VBox/HeatLabel
@onready var heat_decay_label: Label = $UI/Panel/VBox/HeatDecayLabel
@onready var event_label: Label = $UI/Panel/VBox/EventLabel
@onready var damage_label: Label = $UI/Panel/VBox/DamageLabel

var _player: Player
var _dummy: Node2D
var _weapons_by_name: Dictionary = {}
var _last_event_text: String = "--"
var _last_damage_text: String = "--"
var _status_elapsed: float = 0.0

func _ready() -> void:
	_connect_buttons()
	_reset_test()

func _physics_process(delta: float) -> void:
	_status_elapsed += delta
	if _status_elapsed >= 0.1:
		_status_elapsed = 0.0
		_update_status()

func _connect_buttons() -> void:
	$UI/Panel/VBox/ButtonsA/ResetButton.pressed.connect(_reset_test)
	$UI/Panel/VBox/ButtonsA/AddHeatButton.pressed.connect(_add_heat)
	$UI/Panel/VBox/ButtonsA/ClearButton.pressed.connect(_clear_heat_state)
	$UI/Panel/VBox/ButtonsB/FlameButton.pressed.connect(_fire_flamethrower)
	$UI/Panel/VBox/ButtonsB/MachineGunButton.pressed.connect(_trigger_machine_gun_reload)
	$UI/Panel/VBox/ButtonsC/PlasmaButton.pressed.connect(_fire_plasma_lance)
	$UI/Panel/VBox/ButtonsC/CannonButton.pressed.connect(_fire_cannon_thermal)
	$UI/Panel/VBox/ButtonsD/ReadyCannonButton.pressed.connect(_ready_cannon_body_passive)
	$UI/Panel/VBox/ButtonsD/ReloadCannonButton.pressed.connect(_finish_cannon_reload)

func _reset_test() -> void:
	_cleanup()
	if PhaseManager != null and PhaseManager.has_method("reset_runtime_state"):
		PhaseManager.reset_runtime_state()
	if PhaseManager != null and PhaseManager.has_method("enter_battle"):
		PhaseManager.enter_battle()
	PlayerData.reset_runtime_state()
	PlayerData.set_hp_safety_for_testing(true)
	PlayerData.max_weapon_num = 4
	_spawn_player()
	_spawn_dummy()
	await get_tree().physics_frame
	_setup_heat_weapons()
	_set_main_weapon("Flamethrower")
	_update_aim_target()
	_last_event_text = "--"
	_last_damage_text = "--"
	_update_status()

func _cleanup() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_dummy = null
	_weapons_by_name.clear()
	for child in target_root.get_children():
		child.queue_free()

func _spawn_player() -> void:
	var instance := player_scene.instantiate()
	_player = instance as Player
	if _player == null:
		push_error("heat_passive_test: player_scene must instantiate Player.")
		return
	spawn_root.add_child(_player)
	_player.global_position = player_spawn.global_position
	PlayerData.player = _player
	_player.set_meta("_benchmark_mouse_target", target_spawn.global_position)

func _spawn_dummy() -> void:
	_dummy = _spawn_dummy_at(target_spawn.global_position, "Primary")
	for offset in cannon_spectator_offsets:
		_spawn_dummy_at(target_spawn.global_position + offset, "Spectator")

func _spawn_dummy_at(position_value: Vector2, role: String) -> Node2D:
	var instance := dummy_scene.instantiate()
	var dummy := instance as Node2D
	if dummy == null:
		push_error("heat_passive_test: dummy_scene must instantiate Node2D.")
		return null
	if dummy.get("max_hp_value") != null:
		dummy.set("max_hp_value", maxi(dummy_hp, 1))
	dummy.set_meta("heat_passive_test_role", role)
	target_root.add_child(dummy)
	dummy.global_position = position_value
	_make_dummy_visible(dummy)
	if dummy.has_signal("damage_received"):
		dummy.connect("damage_received", Callable(self, "_on_dummy_damage_received"))
	if dummy.has_signal("dummy_died"):
		dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
	return dummy

func _make_dummy_visible(dummy: Node2D) -> void:
	var body := dummy.get_node_or_null("Body") as Sprite2D
	if body == null:
		return
	body.texture = dummy_texture
	body.scale = Vector2(1.5, 1.5)
	body.modulate = Color(1.0, 0.25, 0.1, 1.0)
	body.z_index = 10
	var hurt_shape_node := dummy.get_node_or_null("HurtBox/CollisionShape2D") as CollisionShape2D
	if hurt_shape_node != null:
		var hurt_shape := RectangleShape2D.new()
		hurt_shape.size = Vector2(56.0, 56.0)
		hurt_shape_node.shape = hurt_shape
	var body_shape_node := dummy.get_node_or_null("NPCCollision") as CollisionShape2D
	if body_shape_node != null:
		var body_shape := RectangleShape2D.new()
		body_shape.size = Vector2(48.0, 48.0)
		body_shape_node.shape = body_shape

func _setup_heat_weapons() -> void:
	_clear_player_weapons()
	_add_weapon_from_definition("13", "Flamethrower")
	_add_weapon_from_definition("1", "Machine Gun")
	_add_weapon_from_definition("17", "Plasma Lance")
	var cannon := _add_weapon_from_definition("25", "Cannon")
	if cannon != null:
		cannon.fuse = maxi(int(cannon.fuse), 2)
		cannon.call("add_branch", "thermal_cannon_branch")
		_weapons_by_name["Cannon Thermal"] = cannon
	if _player != null and is_instance_valid(_player):
		_player.call("_rebuild_shared_heat_pool")
	_update_aim_target()

func _clear_player_weapons() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Node
		if weapon != null and is_instance_valid(weapon):
			weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1
	PlayerData.on_select_weapon = -1

func _add_weapon_from_definition(weapon_id: String, label: String) -> Weapon:
	var def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if def == null or def.scene == null:
		push_warning("heat_passive_test: missing weapon definition %s" % weapon_id)
		return null
	var weapon := def.scene.instantiate() as Weapon
	if weapon == null:
		push_warning("heat_passive_test: weapon %s is not Weapon" % weapon_id)
		return null
	weapon.level = weapon_level
	_player.create_weapon(weapon)
	_weapons_by_name[label] = weapon
	if weapon.has_signal("passive_triggered"):
		weapon.connect("passive_triggered", Callable(self, "_on_weapon_passive_triggered").bind(label))
	weapon.set_meta("_benchmark_mouse_target", target_spawn.global_position)
	return weapon

func _set_main_weapon(label: String) -> void:
	var weapon := _weapons_by_name.get(label, null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	var idx := PlayerData.player_weapon_list.find(weapon)
	if idx < 0:
		return
	var old_main := _player.get_main_weapon() if _player != null and is_instance_valid(_player) else null
	PlayerData.set_main_weapon_index(idx)
	_player.call("_apply_weapon_roles")
	_player.call("_broadcast_weapon_passive_event", &"on_main_swapped", {
		"old_main": old_main,
		"new_main": weapon,
	})
	_update_aim_target()

func _update_aim_target() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.set_meta("_benchmark_mouse_target", target_spawn.global_position)
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Node
		if weapon != null and is_instance_valid(weapon):
			weapon.set_meta("_benchmark_mouse_target", target_spawn.global_position)

func _fire_flamethrower() -> void:
	_set_main_weapon("Flamethrower")
	var weapon := _weapons_by_name.get("Flamethrower", null) as Weapon
	_force_weapon_ready(weapon)
	_prime_weapon_heat_ratio(weapon, 0.72)
	_request_fire("Flamethrower")

func _trigger_machine_gun_reload() -> void:
	var weapon := _weapons_by_name.get("Machine Gun", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	_set_main_weapon("Machine Gun")
	weapon.force_skill_cooldowns_ready()
	weapon.is_reloading = false
	weapon.current_ammo = maxi(0, int(round(float(weapon.magazine_capacity) * 0.25)))
	weapon.request_reload()
	_update_status()

func _fire_plasma_lance() -> void:
	_set_main_weapon("Plasma Lance")
	_force_weapon_ready(_weapons_by_name.get("Plasma Lance", null) as Weapon)
	_request_fire("Plasma Lance")

func _fire_cannon_thermal() -> void:
	_set_main_weapon("Cannon Thermal")
	_force_weapon_ready(_weapons_by_name.get("Cannon Thermal", null) as Weapon)
	_request_fire("Cannon Thermal")

func _ready_cannon_body_passive() -> void:
	var weapon := _weapons_by_name.get("Cannon Thermal", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	_set_main_weapon("Cannon Thermal")
	_force_weapon_ready(weapon)
	weapon.set("_idle_fire_reload_ready", true)
	weapon.set("_idle_fire_ready", true)
	weapon.set("_idle_fire_empowered_shots_remaining", 0)
	var timer := weapon.get_node_or_null("IdleFireTimer") as Timer
	if timer != null:
		timer.stop()
	_last_event_text = "Cannon body passive is ready; next Cannon shot triggers 3 empowered shots"
	_update_status()

func _finish_cannon_reload() -> void:
	var weapon := _weapons_by_name.get("Cannon Thermal", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	_set_main_weapon("Cannon Thermal")
	weapon.is_reloading = false
	weapon.current_ammo = 0
	if weapon.request_reload() and weapon.has_method("_finish_reload"):
		weapon.call("_finish_reload")
	_last_event_text = "Cannon reload finished; old empowered shots cleared and idle timer restarted"
	_update_status()

func _request_fire(label: String) -> void:
	var weapon := _weapons_by_name.get(label, null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	_update_aim_target()
	weapon.request_primary_fire()
	_update_status()

func _force_weapon_ready(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	weapon.is_on_cooldown = false
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0
	weapon.force_skill_cooldowns_ready()
	if weapon.has_method("refill_ammo_instantly"):
		weapon.call("refill_ammo_instantly")

func _prime_weapon_heat_ratio(weapon: Weapon, ratio: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("lock_heat_value") or not weapon.has_method("get_heat_max_value"):
		return
	var max_heat := maxf(float(weapon.call("get_heat_max_value")), 1.0)
	weapon.call("lock_heat_value", max_heat * clampf(ratio, 0.0, 1.0), 0.2)

func _add_heat() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pool = _player.call("get_shared_heat_pool")
	if pool != null and pool.has_method("add_heat_amount"):
		pool.call("add_heat_amount", 100.0)
	_update_status()

func _clear_heat_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("clear_heat_statuses"):
		_player.call("clear_heat_statuses")
	if _player.has_method("consume_shared_heat"):
		_player.call("consume_shared_heat", 999999.0)
	_update_status()

func _update_status() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var main_weapon := _player.get_main_weapon()
	var main_name := "--"
	if main_weapon != null and main_weapon.get("ITEM_NAME") != null:
		main_name = str(main_weapon.get("ITEM_NAME"))
	var heat_value := float(_player.call("get_total_heat_value"))
	var heat_max := float(_player.call("get_total_heat_max"))
	var heat_ratio := float(_player.call("get_total_heat_ratio"))
	var prepared := bool(_player.call("has_heat_prepared"))
	var stabilized := bool(_player.call("has_heat_stabilized"))
	var selected_decay_rate := float(_player.call("get_selected_heat_decay_rate"))
	var effective_decay_rate := float(_player.call("get_effective_heat_decay_rate"))
	var selected_decay_source := str(_player.call("get_selected_heat_decay_source_name"))
	var last_decay_source := str(_player.call("get_last_heat_decay_source_name"))
	var stabilized_decay_mul := float(_player.call("get_heat_stabilized_decay_mul"))
	status_label.text = "Status: Prepared=%s  Stabilized=%s" % [str(prepared), str(stabilized)]
	weapon_label.text = "Main Weapon: %s" % main_name
	heat_label.text = "Shared Heat: %.1f / %.1f (%.0f%%)" % [heat_value, heat_max, heat_ratio * 100.0]
	heat_decay_label.text = "Heat Decay: selected=%.1f source=%s last=%s stabilized_mul=%.2f effective=%.1f" % [
		selected_decay_rate,
		selected_decay_source,
		last_decay_source,
		stabilized_decay_mul,
		effective_decay_rate,
	]
	event_label.text = "Last Passive: %s" % _last_event_text
	damage_label.text = "Last Damage: %s" % _last_damage_text

func _on_weapon_passive_triggered(event_name: StringName, detail: Dictionary, label: String) -> void:
	var event_text := str(event_name)
	var passive_scope: StringName = detail.get("passive_scope", Weapon.PASSIVE_SCOPE_BODY)
	if passive_scope == Weapon.PASSIVE_SCOPE_GLOBAL or event_text.ends_with("_triggered") or event_text.ends_with("_spend"):
		print("[PassiveTest] ", label, " event=", event_name, " detail=", detail)
	_last_event_text = "%s -> %s %s" % [label, str(event_name), str(detail)]
	_update_status()

func _on_dummy_damage_received(_dummy_node: Node, amount: int, attack: Attack, hp_after: int) -> void:
	var damage_type := Attack.normalize_damage_type(attack.damage_type) if attack != null else Attack.TYPE_PHYSICAL
	var role := str(_dummy_node.get_meta("heat_passive_test_role", "Dummy"))
	_last_damage_text = "%s: %d damage, type=%s, hp=%d" % [role, amount, str(damage_type), hp_after]
	_update_status()

func _on_dummy_died(dummy_node: Node, _killing_attack: Attack) -> void:
	if dummy_node == _dummy:
		_dummy = _spawn_dummy_at(target_spawn.global_position, "Primary")
	_update_aim_target()
