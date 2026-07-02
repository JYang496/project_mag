extends Node

const REWARD_MANAGER_SCENE_PATH := "res://World/rewards/reward_manager.tscn"
const SEED_VALUE: int = 20260702
const SAMPLE_RUNS: int = 1000
const DRAFTS_PER_RUN: int = 6

var _data_handler: Node
var _player_data: Node
var _inventory_data: Node
var _reward_draft_runtime: Node
var _run_route_manager: Node
var _global_variables: Node
var _reward_manager: Node
var _route: Resource

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _resolve_autoloads():
		get_tree().quit(1)
		return
	seed(SEED_VALUE)
	_data_handler.call("prepare_world_data")
	_player_data.call("reset_runtime_state")
	_inventory_data.call("reset_runtime_state")
	_reward_draft_runtime.call("reset_runtime_state")
	_run_route_manager.call("reset_runtime_state")
	_run_route_manager.call("reload_route_definitions")
	_configure_economy()
	var reward_manager_scene := load(REWARD_MANAGER_SCENE_PATH) as PackedScene
	if reward_manager_scene == null:
		push_error("Cannot load RewardManager scene: %s" % REWARD_MANAGER_SCENE_PATH)
		get_tree().quit(1)
		return
	_reward_manager = reward_manager_scene.instantiate()
	if _reward_manager == null:
		push_error("Cannot instantiate RewardManager scene.")
		get_tree().quit(1)
		return
	add_child(_reward_manager)
	var module_cache: Array = _reward_manager.call("_build_module_candidates_uncached", true)
	_reward_manager.set("_module_candidate_cache", module_cache)
	_reward_manager.set("_module_candidate_cache_ready", true)
	_route = _run_route_manager.call("get_route_for_level", 0) as Resource
	var stats := _simulate()
	var findings := _evaluate(stats)
	var output_path := _write_report(stats, findings)
	var status := str(findings.get("status", "FAIL"))
	print("RewardDraftSimulationReport: %s %s" % [status, output_path])
	get_tree().quit(0 if status != "FAIL" else 1)

func _resolve_autoloads() -> bool:
	_data_handler = get_node_or_null("/root/DataHandler")
	_player_data = get_node_or_null("/root/PlayerData")
	_inventory_data = get_node_or_null("/root/InventoryData")
	_reward_draft_runtime = get_node_or_null("/root/RewardDraftRuntime")
	_run_route_manager = get_node_or_null("/root/RunRouteManager")
	_global_variables = get_node_or_null("/root/GlobalVariables")
	if _data_handler == null \
			or _player_data == null \
			or _inventory_data == null \
			or _reward_draft_runtime == null \
			or _run_route_manager == null \
			or _global_variables == null:
		push_error("Missing required autoload for reward draft simulation report.")
		return false
	return true

func _configure_economy() -> void:
	var economy := _global_variables.get("economy_data") as EconomyConfig
	if economy == null:
		economy = EconomyConfig.new()
	economy.reward_module_options_enabled = true
	economy.reward_weapon_option_chance = 0.6
	economy.reward_economy_option_chance = 0.15
	economy.early_standard_draft_count = 3
	economy.early_weapon_progress_slot_enabled = true
	economy.early_module_option_chances = PackedFloat32Array([0.0, 0.2, -1.0])
	economy.early_economy_option_enabled = false
	economy.early_allow_fallback_economy = true
	_global_variables.set("economy_data", economy)

func _simulate() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	for draft_index in range(1, DRAFTS_PER_RUN + 1):
		stats.append({
			"draft": draft_index,
			"options": 0,
			"rollable_options": 0,
			"weapon": 0,
			"module": 0,
			"economy": 0,
			"fallback": 0,
			"weapon_progress_presence": 0,
	})
	for _run_index in range(SAMPLE_RUNS):
		_reward_draft_runtime.call("reset_runtime_state")
		for draft_index in range(1, DRAFTS_PER_RUN + 1):
			_reward_draft_runtime.set("standard_draft_count", draft_index - 1)
			_reward_draft_runtime.call("clear_pending_standard_draft")
			var options: Array = _reward_manager.call("build_standard_battle_draft_options", 0, _route, 3)
			var stat := stats[draft_index - 1]
			stat["options"] = int(stat["options"]) + options.size()
			stat["rollable_options"] = int(stat["rollable_options"]) + maxi(options.size() - (1 if draft_index <= 3 else 0), 0)
			if _has_weapon_progress_reward(options):
				stat["weapon_progress_presence"] = int(stat["weapon_progress_presence"]) + 1
			for reward in options:
				if reward == null:
					continue
				if str(reward.reward_key_override).begins_with("fallback_economy:"):
					stat["fallback"] = int(stat["fallback"]) + 1
				elif str(reward.reward_key_override).begins_with("economy:") or reward.reward_kind == RewardInfo.KIND_ECONOMY:
					stat["economy"] = int(stat["economy"]) + 1
				elif reward.module_scene != null:
					stat["module"] = int(stat["module"]) + 1
				elif reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE or reward.item_id.strip_edges() != "":
					stat["weapon"] = int(stat["weapon"]) + 1
			stats[draft_index - 1] = stat
	return stats

func _evaluate(stats: Array[Dictionary]) -> Dictionary:
	var messages: PackedStringArray = []
	var warnings: PackedStringArray = []
	var failed := false
	var economy := _global_variables.get("economy_data") as EconomyConfig
	var draft_one := stats[0]
	var draft_two := stats[1]
	var draft_three := stats[2]
	for index in range(3):
		var presence_rate := _presence_rate(stats[index])
		if presence_rate != 1.0:
			failed = true
			messages.append("Draft %d weapon-progress presence is %.2f%%, expected 100%%." % [index + 1, presence_rate * 100.0])
		if _normal_economy_rate(stats[index]) != 0.0:
			failed = true
			messages.append("Draft %d normal economy appeared during early gate." % [index + 1])
	if _module_roll_rate(draft_one) != 0.0:
		failed = true
		messages.append("Draft 1 module roll rate is %.2f%%, expected 0%%." % (_module_roll_rate(draft_one) * 100.0))
	var draft_two_module_rate := _module_roll_rate(draft_two)
	if draft_two_module_rate < 0.15 or draft_two_module_rate > 0.25:
		failed = true
		messages.append("Draft 2 module rate is %.2f%%, expected 15%%-25%%." % (draft_two_module_rate * 100.0))
	var normal_module_target := 1.0 - economy.get_reward_weapon_option_chance()
	var draft_three_module_rate := _module_roll_rate(draft_three)
	if absf(draft_three_module_rate - normal_module_target) > 0.07:
		failed = true
		messages.append("Draft 3 module rate is %.2f%%, target %.2f%% +/-7%%." % [draft_three_module_rate * 100.0, normal_module_target * 100.0])
	for index in range(3, DRAFTS_PER_RUN):
		var stat := stats[index]
		var weapon_rate := _weapon_rate(stat)
		var module_rate := _module_rate(stat)
		var economy_rate := _normal_economy_rate(stat)
		if absf(weapon_rate - 0.51) > 0.12 or absf(module_rate - 0.34) > 0.12 or absf(economy_rate - 0.15) > 0.08:
			warnings.append("Draft %d long-term distribution is weapon %.2f%%, module %.2f%%, economy %.2f%%." % [
				index + 1,
				weapon_rate * 100.0,
				module_rate * 100.0,
				economy_rate * 100.0,
			])
	var status := "FAIL" if failed else ("WARN" if not warnings.is_empty() else "PASS")
	return {
		"status": status,
		"messages": messages,
		"warnings": warnings,
	}

func _write_report(stats: Array[Dictionary], findings: Dictionary) -> String:
	var reports_dir := ProjectSettings.globalize_path("res://docs/reports")
	DirAccess.make_dir_recursive_absolute(reports_dir)
	var timestamp := Time.get_datetime_string_from_system(false, true) \
		.replace(":", "") \
		.replace("-", "") \
		.replace("T", "_") \
		.replace(" ", "_")
	var path := "res://docs/reports/reward_draft_simulation_%s.html" % timestamp
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write reward draft simulation report.")
		return path
	file.store_string(_build_html(stats, findings))
	return path

func _build_html(stats: Array[Dictionary], findings: Dictionary) -> String:
	var economy := _global_variables.get("economy_data") as EconomyConfig
	var rows := PackedStringArray()
	for stat in stats:
		rows.append("<tr><td>Draft %d</td><td>%d</td><td>%.2f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.2f%%</td><td>%.2f%%</td></tr>" % [
			int(stat.get("draft", 0)),
			int(stat.get("options", 0)),
			_weapon_rate(stat) * 100.0,
			_module_rate(stat) * 100.0,
			_module_roll_rate(stat) * 100.0,
			_normal_economy_rate(stat) * 100.0,
			_fallback_rate(stat) * 100.0,
			_presence_rate(stat) * 100.0,
		])
	var messages := _list_items(findings.get("messages", []), "No failures.")
	var warnings := _list_items(findings.get("warnings", []), "No warnings.")
	return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Reward Draft Simulation</title>
<style>
body { font-family: Arial, sans-serif; margin: 32px; color: #1f2937; background: #f8fafc; }
table { border-collapse: collapse; width: 100%%; background: white; }
th, td { border: 1px solid #cbd5e1; padding: 8px 10px; text-align: left; }
th { background: #e2e8f0; }
.status { display: inline-block; padding: 4px 10px; border-radius: 4px; font-weight: 700; background: #e0f2fe; }
pre { background: #111827; color: #f8fafc; padding: 14px; overflow: auto; }
</style>
</head>
<body>
<h1>Reward Draft Simulation</h1>
<p>Status: <span class="status">%s</span></p>
<p>Seed: %d</p>
<p>Sample count: %d runs, first %d standard battle Drafts per run.</p>
<h2>Config Snapshot</h2>
<pre>%s</pre>
<h2>Draft 1-6 Distribution</h2>
<table>
<thead><tr><th>Draft</th><th>Options</th><th>Weapon</th><th>Module / All Options</th><th>Module / Rollable Slots</th><th>Normal Economy</th><th>Fallback Economy</th><th>Weapon-Progress Presence</th></tr></thead>
<tbody>%s</tbody>
</table>
<h2>Failures</h2>
%s
<h2>Warnings</h2>
%s
</body>
</html>
""" % [
		str(findings.get("status", "FAIL")),
		SEED_VALUE,
		SAMPLE_RUNS,
		DRAFTS_PER_RUN,
		_config_snapshot(economy),
		"\n".join(rows),
		messages,
		warnings,
	]

func _config_snapshot(economy: EconomyConfig) -> String:
	return JSON.stringify({
		"reward_module_options_enabled": economy.reward_module_options_enabled,
		"reward_weapon_option_chance": economy.get_reward_weapon_option_chance(),
		"reward_economy_option_chance": economy.get_reward_economy_option_chance(),
		"early_standard_draft_count": economy.get_early_standard_draft_count(),
		"early_weapon_progress_slot_enabled": economy.early_weapon_progress_slot_enabled,
		"early_module_option_chances": Array(economy.early_module_option_chances),
		"early_economy_option_enabled": economy.early_economy_option_enabled,
		"early_allow_fallback_economy": economy.early_allow_fallback_economy,
	}, "\t")

func _list_items(items_variant: Variant, empty_text: String) -> String:
	var items: Array = items_variant if items_variant is Array else []
	if items.is_empty():
		return "<p>%s</p>" % empty_text
	var chunks := PackedStringArray()
	for item in items:
		chunks.append("<li>%s</li>" % _escape_html(str(item)))
	return "<ul>%s</ul>" % "\n".join(chunks)

func _has_weapon_progress_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward == null:
			continue
		if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
			return true
		if reward.item_id.strip_edges() != "":
			return true
	return false

func _weapon_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("weapon", 0)), int(stat.get("options", 0)))

func _module_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("module", 0)), int(stat.get("options", 0)))

func _module_roll_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("module", 0)), int(stat.get("rollable_options", stat.get("options", 0))))

func _normal_economy_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("economy", 0)), int(stat.get("options", 0)))

func _fallback_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("fallback", 0)), int(stat.get("options", 0)))

func _presence_rate(stat: Dictionary) -> float:
	return _safe_rate(int(stat.get("weapon_progress_presence", 0)), SAMPLE_RUNS)

func _safe_rate(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(value) / float(total)

func _escape_html(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
