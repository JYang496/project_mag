extends RealCombatDpsBenchmark
class_name WeaponBranchDpsBenchmark

const BRANCH_REPORT_FILE_PREFIX := "weapon_branch_dps"

var _current_branch_id: String = ""
var _current_branch_name: String = ""
var _current_case_label: String = ""
var _current_target_distance: float = 260.0

func _build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var ids := DataHandler.get_weapon_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(a) < int(b)
	)
	for weapon_id in ids:
		var weapon_name := _resolve_weapon_name(weapon_id)
		var weapon_max_level := _get_weapon_max_benchmark_level(weapon_id)
		queue.append({
			"weapon_id": weapon_id,
			"weapon_name": weapon_name,
			"level": 1,
			"max_level": weapon_max_level,
			"branch_id": "",
			"branch_name": "Base",
			"case_label": weapon_name,
		})
		for branch_def in _get_branch_definitions_for_weapon(weapon_id):
			var branch_name := LocalizationManager.get_branch_display_name(branch_def)
			queue.append({
				"weapon_id": weapon_id,
				"weapon_name": weapon_name,
				"level": 1,
				"max_level": weapon_max_level,
				"branch_id": str(branch_def.branch_id),
				"branch_name": branch_name,
				"case_label": "%s / %s" % [weapon_name, branch_name],
				"branch_unlock_fuse": int(branch_def.unlock_fuse),
			})
	return queue

func _prepare_case(case_data: Dictionary) -> void:
	_current_branch_id = str(case_data.get("branch_id", ""))
	_current_branch_name = str(case_data.get("branch_name", "Base"))
	_current_case_label = str(case_data.get("case_label", ""))
	_cleanup_case()
	_ensure_battle_phase_for_test()
	_current_weapon_id = str(case_data.get("weapon_id", ""))
	var case_max_level := int(case_data.get("max_level", _get_weapon_max_benchmark_level(_current_weapon_id)))
	_current_weapon_level = clampi(int(case_data.get("level", min_weapon_level)), min_weapon_level, case_max_level)
	_spawn_player()
	_equip_weapon(_current_weapon_id, _current_weapon_level)
	var weapon := _resolve_main_weapon_node()
	_current_target_distance = _resolve_target_distance_for_case(_current_weapon_id, weapon)
	_apply_case_target_position(_current_target_distance)
	_spawn_target()
	_prime_case_target_for_weapon(weapon)
	_apply_benchmark_aim_meta()
	await get_tree().physics_frame
	await get_tree().physics_frame

func _run_case(case_data: Dictionary, case_index: int, total_cases: int) -> void:
	await _prepare_case(case_data)
	Input.action_press("ATTACK")
	weapon_label.text = "%s | Lv.%d" % [_current_case_label, _current_weapon_level]
	_update_progress(case_index, total_cases, "Warmup")
	var warmup_left := maxf(warmup_sec, 0.0)
	while warmup_left > 0.0:
		_step_weapon(false)
		await get_tree().physics_frame
		_track_current_weapon_state(false)
		var delta := _get_benchmark_delta()
		warmup_left -= delta

	_reset_measurement_state()
	_measurement_active = true
	while _elapsed_test_sec < test_duration_sec:
		_step_weapon(true)
		await get_tree().physics_frame
		_track_current_weapon_state(true)
		var delta := _get_benchmark_delta()
		_elapsed_test_sec += delta
		_update_progress(case_index, total_cases, "%.2f / %.2fs" % [minf(_elapsed_test_sec, test_duration_sec), test_duration_sec])
	_measurement_active = false
	Input.action_release("ATTACK")

	_results.append(_build_result())
	_cleanup_runtime_effects_outside_case()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_cleanup_case()
	await get_tree().physics_frame

func _equip_weapon(weapon_id: String, level_value: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_clear_player_weapons_for_case()
	_player.create_weapon(weapon_id, level_value)
	PlayerData.set_main_weapon_index(0)
	var weapon := _resolve_main_weapon_node()
	if weapon != null and _current_branch_id != "":
		_apply_branch_to_weapon(weapon, _current_branch_id)
	if weapon != null and weapon.has_method("set_level"):
		weapon.call("set_level", level_value)
	if weapon != null and weapon.has_signal("weapon_reload_completed"):
		weapon.connect("weapon_reload_completed", Callable(self, "_on_weapon_reload_completed"))
	if weapon != null and weapon.has_signal("shoot"):
		weapon.connect("shoot", Callable(self, "_on_weapon_shot"))
	_previous_reloading = _is_weapon_reloading(weapon)

func _cleanup_case() -> void:
	Input.action_release("ATTACK")
	_disable_runtime_subtree(self)
	if target_root != null and is_instance_valid(target_root):
		for child in target_root.get_children():
			child.queue_free()
	for child in spawn_root.get_children():
		if child is Marker2D or child == target_root:
			continue
		child.queue_free()
	for child in get_children():
		if child == spawn_root or child.name == "UI":
			continue
		child.queue_free()
	_player = null
	_target = null

func _cleanup_runtime_effects_outside_case() -> void:
	for child in get_children():
		if child == spawn_root or child.name == "UI":
			continue
		_disable_node_tree(child)
		child.queue_free()

func _disable_runtime_subtree(root: Node) -> void:
	for child in root.get_children():
		if child == spawn_root or child.name == "UI":
			continue
		_disable_node_tree(child)
	for child in spawn_root.get_children():
		if child is Marker2D:
			continue
		_disable_node_tree(child)

func _disable_node_tree(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(false)
	node.set_physics_process(false)
	var area := node as Area2D
	if area != null:
		area.monitoring = false
		area.monitorable = false
	var collision_shape := node as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true
	for child in node.get_children():
		_disable_node_tree(child)

func _build_result() -> Dictionary:
	var result := super._build_result()
	result["branch_id"] = _current_branch_id
	result["branch_name"] = _current_branch_name
	result["case_label"] = _current_case_label
	result["target_distance"] = snapped(_current_target_distance, 0.001)
	result["max_level"] = _get_weapon_max_benchmark_level(_current_weapon_id)
	result["level_estimates"] = _build_level_estimates(
		_current_weapon_id,
		_current_branch_id,
		float(result.get("dps", 0.0)),
		int(result.get("max_level", max_weapon_level))
	)
	result["notes"] = _build_result_notes(result)
	return result

func _write_html_report() -> String:
	_ensure_report_dir(report_dir)
	var stamp := _build_file_stamp()
	var path := "%s/%s_%s.html" % [report_dir, BRANCH_REPORT_FILE_PREFIX, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("weapon_branch_dps_benchmark: failed to open HTML report %s" % path)
		return ""
	file.store_string(_build_html(stamp))
	file.flush()
	file.close()
	return path

func _build_html(stamp: String) -> String:
	var sorted_results := _results.duplicate(true)
	sorted_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dps", 0.0)) > float(b.get("dps", 0.0))
	)
	var rows := PackedStringArray()
	for i in range(sorted_results.size()):
		var result: Dictionary = sorted_results[i]
		var estimates_text := _format_estimates_summary(result.get("level_estimates", []))
		rows.append(
			"<tr><td class=\"num\">%d</td><td>%s</td><td>%s</td><td>%s</td><td class=\"num\">%.3f</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%.3f</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%.0f</td><td>%s</td><td>%s</td></tr>" % [
				i + 1,
				_html_escape(str(result.get("case_label", ""))),
				_html_escape(str(result.get("weapon_id", ""))),
				_html_escape(str(result.get("branch_id", "base")) if str(result.get("branch_id", "")) != "" else "base"),
				float(result.get("dps", 0.0)),
				int(result.get("total_damage", 0)),
				int(result.get("hit_count", 0)),
				float(result.get("avg_hit", 0.0)),
				int(result.get("fire_success", 0)),
				int(result.get("reload_finished", 0)),
				float(result.get("target_distance", 0.0)),
				_html_escape(estimates_text),
				_html_escape(str(result.get("notes", ""))),
			]
		)
	var chart_json := JSON.stringify(_build_chart_payload(sorted_results))
	return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Weapon Branch DPS Benchmark</title>
  <style>
    body { margin: 0; padding: 28px; background: #f6f8fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    h2 { margin: 26px 0 10px; font-size: 18px; }
    .meta, .note { margin: 0 0 14px; color: #64748b; line-height: 1.45; }
    .chart-wrap { width: 100%%; overflow-x: auto; background: #fff; border: 1px solid #d8dee9; padding: 14px; box-sizing: border-box; }
    canvas { display: block; max-width: none; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; }
    th, td { padding: 8px 9px; border-bottom: 1px solid #e5eaf1; text-align: left; font-size: 12px; vertical-align: top; }
    th { background: #eef2f7; position: sticky; top: 0; z-index: 1; }
    tr:nth-child(even) td { background: #fafbfd; }
    .num { text-align: right; font-variant-numeric: tabular-nums; }
  </style>
</head>
<body>
  <h1>Weapon Branch DPS Benchmark</h1>
  <p class="meta">Generated: %s | Cases: %d | Measured level: 1 | Duration: %.1fs | Target mode: adaptive single dummy placement</p>
  <p class="note">Lv.1 DPS is measured through the real Player/Weapon/Target runtime path. Each weapon is given a target distance that matches its output shape instead of using one fixed dummy distance. Lv.2+ values are estimates derived from runtime stat changes for the same weapon and branch; no extra trigger-state priming is applied.</p>

  <h2>Lv.1 Measured DPS Ranking</h2>
  <div class="chart-wrap"><canvas id="rankChart"></canvas></div>

  <h2>Estimated Level Curves</h2>
  <div class="chart-wrap"><canvas id="curveChart"></canvas></div>

  <h2>Results</h2>
  <table>
    <thead>
      <tr>
        <th class="num">Rank</th><th>Case</th><th>Weapon ID</th><th>Branch</th><th class="num">Lv.1 DPS</th><th class="num">Damage</th><th class="num">Hits</th><th class="num">Avg Hit</th><th class="num">Shots</th><th class="num">Reloads</th><th class="num">Target px</th><th>Estimated DPS by Level</th><th>Notes</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>
  <script>
    const payload = %s;
    function fitCanvas(canvas, width, height) {
      const ratio = window.devicePixelRatio || 1;
      canvas.style.width = width + "px";
      canvas.style.height = height + "px";
      canvas.width = Math.floor(width * ratio);
      canvas.height = Math.floor(height * ratio);
      const ctx = canvas.getContext("2d");
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      return ctx;
    }
    function drawRankChart() {
      const rows = payload.ranking;
      const width = Math.max(920, rows.length * 26 + 220);
      const height = 360;
      const ctx = fitCanvas(document.getElementById("rankChart"), width, height);
      ctx.clearRect(0, 0, width, height);
      const max = Math.max(1, ...rows.map(r => r.dps));
      const left = 64, right = 20, bottom = 94, top = 24;
      const chartW = width - left - right;
      const chartH = height - top - bottom;
      ctx.strokeStyle = "#cbd5e1";
      ctx.beginPath();
      ctx.moveTo(left, top);
      ctx.lineTo(left, top + chartH);
      ctx.lineTo(left + chartW, top + chartH);
      ctx.stroke();
      rows.forEach((row, i) => {
        const barW = Math.max(10, chartW / rows.length - 4);
        const x = left + i * (chartW / rows.length) + 2;
        const h = chartH * row.dps / max;
        const y = top + chartH - h;
        ctx.fillStyle = row.branch_id ? "#2563eb" : "#0f766e";
        ctx.fillRect(x, y, barW, h);
        ctx.save();
        ctx.translate(x + barW / 2, top + chartH + 8);
        ctx.rotate(-Math.PI / 3);
        ctx.fillStyle = "#334155";
        ctx.font = "11px Arial";
        ctx.fillText(row.label, 0, 0);
        ctx.restore();
      });
      ctx.fillStyle = "#1f2937";
      ctx.font = "12px Arial";
      ctx.fillText("DPS", 12, top + 10);
      ctx.fillText(max.toFixed(1), 12, top + 4);
      ctx.fillText("0", 44, top + chartH + 4);
    }
    function drawCurveChart() {
      const series = payload.curves.slice(0, 12);
      const width = 1100;
      const height = 420;
      const ctx = fitCanvas(document.getElementById("curveChart"), width, height);
      ctx.clearRect(0, 0, width, height);
      const left = 62, right = 240, bottom = 44, top = 24;
      const chartW = width - left - right;
      const chartH = height - top - bottom;
      const maxLevel = Math.max(1, ...series.flatMap(s => s.points.map(p => p.level)));
      const maxDps = Math.max(1, ...series.flatMap(s => s.points.map(p => p.dps)));
      ctx.strokeStyle = "#cbd5e1";
      ctx.beginPath();
      ctx.moveTo(left, top);
      ctx.lineTo(left, top + chartH);
      ctx.lineTo(left + chartW, top + chartH);
      ctx.stroke();
      const colors = ["#2563eb", "#dc2626", "#16a34a", "#9333ea", "#ea580c", "#0891b2", "#be123c", "#4f46e5", "#0f766e", "#a16207", "#7c3aed", "#0369a1"];
      series.forEach((item, idx) => {
        ctx.strokeStyle = colors[idx %% colors.length];
        ctx.fillStyle = colors[idx %% colors.length];
        ctx.lineWidth = 2;
        ctx.beginPath();
        item.points.forEach((point, i) => {
          const x = left + ((point.level - 1) / Math.max(1, maxLevel - 1)) * chartW;
          const y = top + chartH - (point.dps / maxDps) * chartH;
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.stroke();
        item.points.forEach(point => {
          const x = left + ((point.level - 1) / Math.max(1, maxLevel - 1)) * chartW;
          const y = top + chartH - (point.dps / maxDps) * chartH;
          ctx.beginPath();
          ctx.arc(x, y, 3, 0, Math.PI * 2);
          ctx.fill();
        });
        ctx.font = "12px Arial";
        ctx.fillText(item.label, left + chartW + 18, top + 18 + idx * 22);
      });
      ctx.fillStyle = "#1f2937";
      ctx.font = "12px Arial";
      ctx.fillText("Estimated DPS", 8, top + 10);
      ctx.fillText(maxDps.toFixed(1), 8, top + 4);
      ctx.fillText("Lv.1", left - 8, top + chartH + 24);
      ctx.fillText("Lv." + maxLevel, left + chartW - 22, top + chartH + 24);
    }
    drawRankChart();
    drawCurveChart();
  </script>
</body>
</html>
""" % [
		_html_escape(stamp),
		_results.size(),
		test_duration_sec,
		"\n      ".join(rows),
		chart_json,
	]

func _get_branch_definitions_for_weapon(weapon_id: String) -> Array[WeaponBranchDefinition]:
	var output: Array[WeaponBranchDefinition] = []
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return output
	var options := DataHandler.read_weapon_branch_options(str(weapon_def.scene_path), 999)
	options.sort_custom(func(a: WeaponBranchDefinition, b: WeaponBranchDefinition) -> bool:
		if int(a.unlock_fuse) == int(b.unlock_fuse):
			return int(a.sort_order) < int(b.sort_order)
		return int(a.unlock_fuse) < int(b.unlock_fuse)
	)
	for option in options:
		if option != null:
			output.append(option)
	return output

func _build_result_notes(result: Dictionary) -> String:
	if int(result.get("total_damage", 0)) > 0:
		return "Measured Lv.1 damage at %.0f px adaptive target distance." % float(result.get("target_distance", _current_target_distance))
	var weapon_id := str(result.get("weapon_id", ""))
	var fire_success := int(result.get("fire_success", 0))
	var distance := float(result.get("target_distance", _current_target_distance))
	match weapon_id:
		"21":
			return "No damage after adaptive placement: Glacier target was %.0f px away; cone overlap or held-fire handling needs verification." % distance
		"11":
			return "No damage after adaptive placement: Dash Blade target was %.0f px away; melee target acquisition needs verification." % distance
		"7":
			return "No damage after adaptive placement: Orbit target was %.0f px away; satellite contact needs verification." % distance
		"4":
			return "No damage after adaptive placement: Shotgun target was %.0f px away; close-range spread hit needs verification." % distance
		"2":
			return "Fired beam but no dummy damage was recorded after adaptive placement; needs beam-specific verification before treating zero as balance data."
		"9":
			return "Fired beam but no dummy damage was recorded after adaptive placement; needs raycast/beam-specific verification before treating zero as balance data."
		_:
			if fire_success > 0:
				return "Fired but no hit was registered against the adaptive single dummy."
			return "No successful attack was triggered in this benchmark setup."

func _apply_case_target_position(distance: float) -> void:
	_current_target_distance = maxf(distance, 1.0)
	target_position = player_position + Vector2(_current_target_distance, 0.0)
	if player_spawn != null and is_instance_valid(player_spawn):
		player_spawn.global_position = player_position
	if target_spawn != null and is_instance_valid(target_spawn):
		target_spawn.global_position = target_position

func _resolve_target_distance_for_case(weapon_id: String, weapon: Node) -> float:
	match weapon_id:
		"2":
			return 160.0
		"4":
			return 96.0
		"7":
			return 80.0
		"9":
			return 160.0
		"11":
			return 120.0
		"21":
			return 120.0
		_:
			return _resolve_generic_target_distance(weapon)

func _resolve_generic_target_distance(weapon: Node) -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 260.0
	if weapon.has_method("_get_effective_attack_range"):
		var range_value := float(weapon.call("_get_effective_attack_range"))
		if range_value > 0.0 and range_value < 260.0:
			return clampf(range_value * 0.7, 48.0, 240.0)
	var attack_range_variant: Variant = weapon.get("attack_range")
	if attack_range_variant != null:
		var attack_range := float(attack_range_variant)
		if attack_range > 0.0 and attack_range < 260.0:
			return clampf(attack_range * 0.7, 48.0, 240.0)
	return 260.0

func _prime_case_target_for_weapon(weapon: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if _target == null or not is_instance_valid(_target):
		return
	if _current_weapon_id == "11" and weapon.has_method("_on_attack_range_body_entered"):
		weapon.call("_on_attack_range_body_entered", _target)

func _apply_branch_to_weapon(weapon_node: Node, branch_id: String) -> bool:
	var weapon := weapon_node as Weapon
	if weapon == null or branch_id == "":
		return false
	var branch_def := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, branch_id)
	if branch_def == null:
		push_warning("weapon_branch_dps_benchmark: missing branch %s for %s" % [branch_id, weapon.scene_file_path])
		return false
	weapon.fuse = maxi(int(weapon.fuse), int(branch_def.unlock_fuse))
	var branch_ok := bool(weapon.branch_runtime.add_branch(branch_id))
	if not branch_ok:
		push_warning("weapon_branch_dps_benchmark: failed to apply branch %s to weapon %s" % [branch_id, weapon.name])
	return branch_ok

func _build_level_estimates(weapon_id: String, branch_id: String, measured_lv1_dps: float, max_level_value: int) -> Array[Dictionary]:
	var estimates: Array[Dictionary] = []
	var base_score := _estimate_level_output_score(weapon_id, branch_id, 1)
	for level_value in range(1, max_level_value + 1):
		var score := _estimate_level_output_score(weapon_id, branch_id, level_value)
		var ratio := 1.0
		if base_score > 0.0:
			ratio = score / base_score
		estimates.append({
			"level": level_value,
			"ratio": snapped(ratio, 0.001),
			"estimated_dps": snapped(measured_lv1_dps * ratio, 0.001),
			"score": snapped(score, 0.001),
		})
	return estimates

func _estimate_level_output_score(weapon_id: String, branch_id: String, level_value: int) -> float:
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null or weapon_def.scene == null:
		return 0.0
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return 0.0
	add_child(weapon)
	if branch_id != "":
		_apply_branch_to_weapon(weapon, branch_id)
	if weapon.has_method("set_level"):
		weapon.call("set_level", level_value)
	var damage := _estimate_runtime_damage_component(weapon)
	var shot_count := _estimate_shot_count_component(weapon)
	var cooldown := _estimate_cooldown_component(weapon)
	var score := damage * shot_count / cooldown
	weapon.queue_free()
	return maxf(score, 0.001)

func _estimate_runtime_damage_component(weapon: Weapon) -> float:
	if weapon == null:
		return 1.0
	if weapon.get("damage") != null:
		var base_damage := float(weapon.get("damage"))
		if weapon.has_method("get_runtime_damage_value"):
			return float(weapon.call("get_runtime_damage_value", base_damage))
		return base_damage
	if weapon.get("base_damage") != null:
		var base_value := float(weapon.get("base_damage"))
		if weapon.has_method("get_runtime_damage_value"):
			return float(weapon.call("get_runtime_damage_value", base_value))
		return base_value
	return 1.0

func _estimate_shot_count_component(weapon: Weapon) -> float:
	if weapon == null:
		return 1.0
	var shot_count := 1
	if weapon.get("bullet_count") != null:
		shot_count = maxi(int(weapon.get("bullet_count")), 1)
	elif weapon.get("number") != null:
		shot_count = maxi(int(weapon.get("number")), 1)
	var branch_runtime := weapon.branch_runtime
	if branch_runtime != null:
		var directions := branch_runtime.get_branch_shot_directions(Vector2.RIGHT, shot_count)
		if directions.size() > shot_count:
			shot_count = directions.size()
		for behavior in branch_runtime.get_branch_behaviors():
			if behavior != null and is_instance_valid(behavior):
				shot_count = maxi(int(behavior.get_projectile_count_override(shot_count)), 1)
	return float(maxi(shot_count, 1))

func _estimate_cooldown_component(weapon: Weapon) -> float:
	if weapon == null:
		return 1.0
	var cooldown := 1.0
	if weapon.get("attack_cooldown") != null:
		cooldown = float(weapon.get("attack_cooldown"))
	elif weapon.get("base_attack_cooldown") != null:
		cooldown = float(weapon.get("base_attack_cooldown"))
	if weapon.has_method("get_effective_cooldown"):
		cooldown = float(weapon.call("get_effective_cooldown", cooldown))
	if weapon.branch_runtime != null:
		cooldown *= weapon.branch_runtime.get_branch_cooldown_multiplier()
	return maxf(cooldown, 0.05)

func _format_estimates_summary(estimates_variant: Variant) -> String:
	if not (estimates_variant is Array):
		return ""
	var chunks := PackedStringArray()
	for estimate_variant in estimates_variant:
		if not (estimate_variant is Dictionary):
			continue
		var estimate: Dictionary = estimate_variant
		chunks.append("Lv.%d %.1f" % [
			int(estimate.get("level", 0)),
			float(estimate.get("estimated_dps", 0.0)),
		])
	return " | ".join(chunks)

func _build_chart_payload(sorted_results: Array) -> Dictionary:
	var ranking: Array[Dictionary] = []
	var curves: Array[Dictionary] = []
	for result_variant in sorted_results:
		if not (result_variant is Dictionary):
			continue
		var result: Dictionary = result_variant
		var label := str(result.get("case_label", ""))
		ranking.append({
			"label": label,
			"weapon_id": str(result.get("weapon_id", "")),
			"branch_id": str(result.get("branch_id", "")),
			"dps": float(result.get("dps", 0.0)),
		})
		var points: Array[Dictionary] = []
		var estimates_variant: Variant = result.get("level_estimates", [])
		if estimates_variant is Array:
			for estimate_variant in estimates_variant:
				if estimate_variant is Dictionary:
					var estimate: Dictionary = estimate_variant
					points.append({
						"level": int(estimate.get("level", 0)),
						"dps": float(estimate.get("estimated_dps", 0.0)),
					})
		curves.append({
			"label": label,
			"points": points,
		})
	return {
		"ranking": ranking,
		"curves": curves,
	}
