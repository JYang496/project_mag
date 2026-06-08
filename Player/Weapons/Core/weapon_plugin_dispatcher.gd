extends RefCounted
class_name WeaponPluginDispatcher

var weapon: Weapon
var on_hit_plugins: Array[Node] = []
var projectile_spawn_plugins: Array[Node] = []
var reload_duration_plugins: Array[Node] = []

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func register_on_hit_plugin(plugin: Node) -> void:
	if plugin and not on_hit_plugins.has(plugin):
		on_hit_plugins.append(plugin)

func unregister_on_hit_plugin(plugin: Node) -> void:
	on_hit_plugins.erase(plugin)

func apply_on_hit_plugins(target: Node) -> void:
	for plugin in on_hit_plugins:
		if is_instance_valid(plugin) and plugin.has_method("apply_on_hit"):
			plugin.apply_on_hit(weapon, target)

func register_projectile_spawn_plugin(plugin: Node) -> void:
	if plugin and not projectile_spawn_plugins.has(plugin):
		projectile_spawn_plugins.append(plugin)

func unregister_projectile_spawn_plugin(plugin: Node) -> void:
	projectile_spawn_plugins.erase(plugin)

func notify_projectile_spawned(projectile: Node2D) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	for i in range(projectile_spawn_plugins.size() - 1, -1, -1):
		var plugin := projectile_spawn_plugins[i]
		if plugin == null or not is_instance_valid(plugin):
			projectile_spawn_plugins.remove_at(i)
			continue
		if plugin.has_method("on_projectile_spawned"):
			plugin.call("on_projectile_spawned", weapon, projectile)

func register_reload_duration_plugin(plugin: Node) -> void:
	if plugin and not reload_duration_plugins.has(plugin):
		reload_duration_plugins.append(plugin)

func unregister_reload_duration_plugin(plugin: Node) -> void:
	reload_duration_plugins.erase(plugin)

func get_effective_reload_duration(base_duration: float) -> float:
	var duration: float = maxf(base_duration, 0.0)
	if reload_duration_plugins.is_empty():
		return duration
	var final_multiplier: float = 1.0
	for i in range(reload_duration_plugins.size() - 1, -1, -1):
		var plugin := reload_duration_plugins[i]
		if plugin == null or not is_instance_valid(plugin):
			reload_duration_plugins.remove_at(i)
			continue
		if not plugin.has_method("get_reload_duration_multiplier"):
			continue
		final_multiplier *= maxf(float(plugin.call("get_reload_duration_multiplier", weapon, duration)), 0.05)
	return maxf(duration * final_multiplier, 0.0)

func clear_for_weapon_exit() -> void:
	on_hit_plugins.clear()
	projectile_spawn_plugins.clear()
	reload_duration_plugins.clear()
