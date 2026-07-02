extends SceneTree

const MatrixScript := preload("res://data/test/build_validation_matrix.gd")
const MATRIX_PATH := "res://data/test/build_validation_matrix_default.tres"
const OUTPUT_PATH := "res://docs/reports/build_validation_matrix.html"

var _data_handler: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var matrix := load(MATRIX_PATH)
	if matrix == null or not (matrix is MatrixScript):
		push_error("Cannot load build validation matrix: %s" % MATRIX_PATH)
		quit(1)
		return
	_data_handler = root.get_node_or_null("/root/DataHandler")
	if _data_handler == null:
		push_error("Missing DataHandler autoload")
		quit(1)
		return
	_data_handler.call("load_weapon_data")
	_data_handler.call("load_weapon_branch_data")
	_ensure_report_dir(OUTPUT_PATH.get_base_dir())
	var html := _build_html(matrix)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open report output: %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(html)
	file.close()
	print("PASS: generated %s (%d builds, %d encounters)" % [
		OUTPUT_PATH,
		matrix.build_cases.size(),
		matrix.encounter_types.size(),
	])
	quit(0)

func _build_html(matrix: Resource) -> String:
	var encounter_headers := PackedStringArray()
	for encounter_variant in matrix.encounter_types:
		var encounter: Dictionary = encounter_variant
		encounter_headers.append("<th>%s</th>" % _html_escape(str(encounter.get("label", encounter.get("id", "")))))
	var rows := PackedStringArray()
	for build_variant in matrix.build_cases:
		var build_case: Dictionary = build_variant
		rows.append(_build_case_row(build_case, matrix.encounter_types))
	var detail_cards := PackedStringArray()
	for build_variant in matrix.build_cases:
		var build_case: Dictionary = build_variant
		detail_cards.append(_build_detail_card(build_case))
	var encounter_cards := PackedStringArray()
	for encounter_variant in matrix.encounter_types:
		var encounter: Dictionary = encounter_variant
		encounter_cards.append(_build_encounter_card(encounter))
	return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Build Validation Matrix</title>
  <style>
    body { margin: 0; padding: 28px; background: #f5f7fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    h2 { margin: 28px 0 12px; font-size: 20px; }
    h3 { margin: 0 0 8px; font-size: 16px; }
    .meta, .note { color: #64748b; line-height: 1.45; margin: 0 0 16px; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; }
    th, td { border-bottom: 1px solid #e5eaf1; padding: 8px 9px; text-align: left; vertical-align: top; font-size: 12px; }
    th { background: #eef2f7; position: sticky; top: 0; z-index: 1; }
    td.status { font-weight: 700; text-align: center; white-space: nowrap; }
    .strong { background: #dcfce7; color: #166534; }
    .neutral { background: #f8fafc; color: #475569; }
    .weak { background: #fee2e2; color: #991b1b; }
    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px; }
    .card { background: #fff; border: 1px solid #d8dee9; padding: 12px; }
    .list { margin: 6px 0 0; padding-left: 18px; }
    .small { color: #64748b; font-size: 12px; line-height: 1.45; }
    code { background: #eef2f7; padding: 1px 4px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Build Validation Matrix</h1>
  <p class="meta">Source: %s | Version: %s | Builds: %d | Encounter types: %d</p>
  <p class="note">This is a Phase 6 validation matrix report. It records expected strengths and weaknesses for multi-weapon builds using current repo resources. It is not a measured combat DPS or survival report yet.</p>

  <h2>Build x Encounter Matrix</h2>
  <table>
    <thead><tr><th>Build</th><th>Weapons</th>%s</tr></thead>
    <tbody>%s</tbody>
  </table>

  <h2>Build Details</h2>
  <div class="cards">%s</div>

  <h2>Encounter Questions</h2>
  <div class="cards">%s</div>
</body>
</html>
""" % [
		_html_escape(MATRIX_PATH),
		_html_escape(str(matrix.version)),
		matrix.build_cases.size(),
		matrix.encounter_types.size(),
		"".join(encounter_headers),
		"\n".join(rows),
		"\n".join(detail_cards),
		"\n".join(encounter_cards),
	]

func _build_case_row(build_case: Dictionary, encounters: Array) -> String:
	var strengths := _to_string_array(build_case.get("expected_strengths", PackedStringArray()))
	var weaknesses := _to_string_array(build_case.get("expected_weaknesses", PackedStringArray()))
	var cells := PackedStringArray()
	for encounter_variant in encounters:
		var encounter: Dictionary = encounter_variant
		var encounter_id := str(encounter.get("id", ""))
		var label := "Neutral"
		var css_class := "neutral"
		if strengths.has(encounter_id):
			label = "Strong"
			css_class = "strong"
		elif weaknesses.has(encounter_id):
			label = "Weak"
			css_class = "weak"
		cells.append("<td class=\"status %s\">%s</td>" % [css_class, label])
	return "<tr><td><strong>%s</strong><br><span class=\"small\"><code>%s</code></span></td><td>%s</td>%s</tr>" % [
		_html_escape(str(build_case.get("label", build_case.get("id", "")))),
		_html_escape(str(build_case.get("id", ""))),
		_html_escape(", ".join(_resolve_weapon_names(_to_string_array(build_case.get("weapons", PackedStringArray()))))),
		"".join(cells),
	]

func _build_detail_card(build_case: Dictionary) -> String:
	var weapons := _to_string_array(build_case.get("weapons", PackedStringArray()))
	var modules := _to_string_array(build_case.get("modules", PackedStringArray()))
	var weapon_items := PackedStringArray()
	for weapon_id in weapons:
		weapon_items.append("<li>%s</li>" % _html_escape(_format_weapon_with_branch(weapon_id, build_case.get("branches", {}))))
	var module_items := PackedStringArray()
	for module_path in modules:
		module_items.append("<li>%s <span class=\"small\"><code>%s</code></span></li>" % [
			_html_escape(_resolve_module_name(module_path)),
			_html_escape(module_path),
		])
	return """<section class="card">
  <h3>%s</h3>
  <div class="small"><code>%s</code></div>
  <p class="small">%s</p>
  <strong>Weapons / branches</strong>
  <ul class="list">%s</ul>
  <strong>Modules</strong>
  <ul class="list">%s</ul>
</section>""" % [
		_html_escape(str(build_case.get("label", build_case.get("id", "")))),
		_html_escape(str(build_case.get("id", ""))),
		_html_escape(str(build_case.get("notes", ""))),
		"".join(weapon_items),
		"".join(module_items),
	]

func _build_encounter_card(encounter: Dictionary) -> String:
	var tags := _to_string_array(encounter.get("pressure_tags", PackedStringArray()))
	var tag_text := PackedStringArray()
	for tag in tags:
		tag_text.append("<code>%s</code>" % _html_escape(tag))
	return """<section class="card">
  <h3>%s</h3>
  <div class="small"><code>%s</code></div>
  <p class="small">%s</p>
  <p class="small">%s</p>
</section>""" % [
		_html_escape(str(encounter.get("label", encounter.get("id", "")))),
		_html_escape(str(encounter.get("id", ""))),
		_html_escape(str(encounter.get("primary_question", ""))),
		" ".join(tag_text),
	]

func _resolve_weapon_names(weapon_ids: PackedStringArray) -> PackedStringArray:
	var names := PackedStringArray()
	for weapon_id in weapon_ids:
		var weapon_def: Variant = _data_handler.call("read_weapon_data", weapon_id)
		if weapon_def == null:
			names.append("weapon_%s" % weapon_id)
			continue
		names.append(_resource_string(weapon_def, "display_name", "weapon_%s" % weapon_id))
	return names

func _format_weapon_with_branch(weapon_id: String, branches_variant: Variant) -> String:
	var weapon_def: Variant = _data_handler.call("read_weapon_data", weapon_id)
	var weapon_name := "weapon_%s" % weapon_id
	var scene_path := ""
	if weapon_def != null:
		weapon_name = _resource_string(weapon_def, "display_name", weapon_name)
		scene_path = _resource_string(weapon_def, "scene_path", "")
	var branch_label := "base"
	if branches_variant is Dictionary:
		var branches: Dictionary = branches_variant
		var branch_id := str(branches.get(weapon_id, "")).strip_edges()
		if branch_id != "":
			var branch_def: Variant = _data_handler.call("read_weapon_branch_definition", scene_path, branch_id)
			if branch_def != null:
				branch_label = "%s (%s)" % [
					_resource_string(branch_def, "display_name", branch_id),
					branch_id,
				]
			else:
				branch_label = branch_id
	return "%s / %s" % [weapon_name, branch_label]

func _resolve_module_name(module_path: String) -> String:
	var scene := load(module_path) as PackedScene
	if scene == null:
		return module_path.get_file().get_basename()
	var instance := scene.instantiate()
	if instance == null:
		return module_path.get_file().get_basename()
	var output := module_path.get_file().get_basename()
	if instance.has_method("get_module_display_name"):
		output = str(instance.call("get_module_display_name"))
	instance.free()
	return output

func _to_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var output := PackedStringArray()
	if value is Array:
		for item in value:
			output.append(str(item))
	return output

func _ensure_report_dir(dir_path: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

func _html_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

func _resource_string(resource: Variant, property_name: String, fallback: String = "") -> String:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null or str(value) == "":
		return fallback
	return str(value)
