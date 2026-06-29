extends SceneTree

const ENEMY_COUNTS := [100, 300, 600]
const QUERY_RADII := [160.0, 320.0]
const QUERY_COUNT := 240
const REPEAT_COUNT := 12
const GRID_CELL_SIZE := 160.0

var _case_root: Node2D
var _query_points: Array[Vector2] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := root.get_node_or_null("/root/EnemyRegistry")
	if registry == null:
		push_error("FAIL: missing EnemyRegistry autoload")
		quit(1)
		return
	_build_query_points()
	print("enemy_count,radius,queries,total_queries,group_ms,registry_ms,grid_build_ms,grid_query_ms,group_hits,registry_hits,grid_hits,avg_registry_candidates,grid_speedup_vs_registry,recommend_grid")
	for enemy_count in ENEMY_COUNTS:
		for radius in QUERY_RADII:
			var result := await _run_case(registry, int(enemy_count), float(radius))
			_print_result(result)
			if int(result.get("group_hits", -1)) != int(result.get("registry_hits", -2)):
				push_error("FAIL: registry hit count drifted from group scan")
				quit(1)
				return
			if int(result.get("group_hits", -1)) != int(result.get("grid_hits", -2)):
				push_error("FAIL: grid hit count drifted from group scan")
				quit(1)
				return
	print("PASS: enemy registry many-enemy benchmark completed")
	quit(0)

func _run_case(registry: Node, enemy_count: int, radius: float) -> Dictionary:
	_spawn_case_enemies(registry, enemy_count)
	await process_frame
	var enemies := _collect_group_enemies()
	var total_queries := QUERY_COUNT * REPEAT_COUNT
	var group_result := _measure_group_radius(radius)
	var registry_result := _measure_registry_radius(registry, radius)
	var grid_build_started := Time.get_ticks_usec()
	var grid := _build_grid(enemies)
	var grid_build_ms := _elapsed_ms(grid_build_started)
	var grid_result := _measure_grid_radius(grid, radius)
	_cleanup_case()
	await process_frame
	var registry_ms := float(registry_result.get("ms", 0.0))
	var grid_ms := float(grid_result.get("ms", 0.0)) + grid_build_ms
	var grid_speedup := registry_ms / maxf(grid_ms, 0.001)
	return {
		"enemy_count": enemy_count,
		"radius": radius,
		"queries": QUERY_COUNT,
		"total_queries": total_queries,
		"group_ms": group_result.get("ms", 0.0),
		"registry_ms": registry_ms,
		"grid_build_ms": grid_build_ms,
		"grid_query_ms": grid_result.get("ms", 0.0),
		"group_hits": group_result.get("hits", 0),
		"registry_hits": registry_result.get("hits", 0),
		"grid_hits": grid_result.get("hits", 0),
		"avg_registry_candidates": float(registry_result.get("hits", 0)) / float(total_queries),
		"grid_speedup_vs_registry": grid_speedup,
		"recommend_grid": grid_speedup >= 1.5 and enemy_count >= 300,
	}

func _spawn_case_enemies(registry: Node, enemy_count: int) -> void:
	_cleanup_case()
	_case_root = Node2D.new()
	_case_root.name = "EnemyRegistryManyEnemyBenchmarkCase"
	root.add_child(_case_root)
	for i in range(enemy_count):
		var enemy := Node2D.new()
		enemy.name = "BenchmarkEnemy%d" % i
		enemy.add_to_group("enemies")
		enemy.global_position = _enemy_position(i, enemy_count)
		_case_root.add_child(enemy)
		registry.call("register_enemy", enemy)

func _cleanup_case() -> void:
	if _case_root != null and is_instance_valid(_case_root):
		_case_root.queue_free()
	_case_root = null

func _build_query_points() -> void:
	_query_points.clear()
	for i in range(QUERY_COUNT):
		var angle := float(i) * 2.39996323
		var ring := sqrt(float(i) / float(maxi(QUERY_COUNT - 1, 1)))
		var radius := lerpf(80.0, 1050.0, ring)
		_query_points.append(Vector2(cos(angle), sin(angle)) * radius)

func _enemy_position(index: int, enemy_count: int) -> Vector2:
	var columns := int(ceil(sqrt(float(enemy_count))))
	var row := index / columns
	var col := index % columns
	var spacing := 48.0
	var centered := Vector2(
		(float(col) - float(columns) * 0.5) * spacing,
		(float(row) - float(columns) * 0.5) * spacing
	)
	var jitter := Vector2(
		sin(float(index) * 12.9898) * 17.0,
		cos(float(index) * 78.233) * 17.0
	)
	return centered + jitter

func _measure_group_radius(radius: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var hits := 0
	var radius_sq := radius * radius
	for repeat_idx in range(REPEAT_COUNT):
		for point in _query_points:
			for enemy_ref in root.get_tree().get_nodes_in_group("enemies"):
				var enemy := enemy_ref as Node2D
				if enemy == null or not is_instance_valid(enemy):
					continue
				if enemy.global_position.distance_squared_to(point) <= radius_sq:
					hits += 1
	return {"ms": _elapsed_ms(started), "hits": hits}

func _measure_registry_radius(registry: Node, radius: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var hits := 0
	for repeat_idx in range(REPEAT_COUNT):
		for point in _query_points:
			var candidates: Array = registry.call("get_enemies_in_radius", point, radius)
			hits += candidates.size()
	return {"ms": _elapsed_ms(started), "hits": hits}

func _build_grid(enemies: Array[Node2D]) -> Dictionary:
	var grid := {}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var cell := _cell_for_position(enemy.global_position)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(enemy)
	return grid

func _measure_grid_radius(grid: Dictionary, radius: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var hits := 0
	var radius_sq := radius * radius
	var cell_radius := int(ceil(radius / GRID_CELL_SIZE))
	for repeat_idx in range(REPEAT_COUNT):
		for point in _query_points:
			var center_cell := _cell_for_position(point)
			for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
				for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
					var cell := Vector2i(x, y)
					if not grid.has(cell):
						continue
					for enemy in grid[cell]:
						if enemy == null or not is_instance_valid(enemy):
							continue
						if enemy.global_position.distance_squared_to(point) <= radius_sq:
							hits += 1
	return {"ms": _elapsed_ms(started), "hits": hits}

func _collect_group_enemies() -> Array[Node2D]:
	var output: Array[Node2D] = []
	for enemy_ref in root.get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy != null and is_instance_valid(enemy):
			output.append(enemy)
	return output

func _cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GRID_CELL_SIZE), floori(position.y / GRID_CELL_SIZE))

func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0

func _print_result(result: Dictionary) -> void:
	print("%d,%.1f,%d,%d,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%.2f,%.2f,%s" % [
		int(result.get("enemy_count", 0)),
		float(result.get("radius", 0.0)),
		int(result.get("queries", 0)),
		int(result.get("total_queries", 0)),
		float(result.get("group_ms", 0.0)),
		float(result.get("registry_ms", 0.0)),
		float(result.get("grid_build_ms", 0.0)),
		float(result.get("grid_query_ms", 0.0)),
		int(result.get("group_hits", 0)),
		int(result.get("registry_hits", 0)),
		int(result.get("grid_hits", 0)),
		float(result.get("avg_registry_candidates", 0.0)),
		float(result.get("grid_speedup_vs_registry", 0.0)),
		str(bool(result.get("recommend_grid", false))),
	])
