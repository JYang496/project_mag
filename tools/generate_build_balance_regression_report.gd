extends SceneTree

const MatrixScript := preload("res://data/test/build_validation_matrix.gd")
const MATRIX_PATH := "res://data/test/build_validation_matrix_default.tres"
const OUTPUT_PATH := "res://docs/reports/build_balance_regression_smoke_report.html"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var matrix := load(MATRIX_PATH)
	if matrix == null or not (matrix is MatrixScript):
		push_error("Cannot load build validation matrix: %s" % MATRIX_PATH)
		quit(1)
		return
	_ensure_report_dir(OUTPUT_PATH.get_base_dir())
	var html := _build_html(matrix)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open report output: %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(html)
	file.close()
	print("PASS: generated %s" % OUTPUT_PATH)
	quit(0)

func _build_html(matrix: Resource) -> String:
	var build_rows := PackedStringArray()
	for build_variant in matrix.build_cases:
		var build_case: Dictionary = build_variant
		build_rows.append(_build_build_row(build_case, matrix.encounter_types.size()))
	var encounter_rows := PackedStringArray()
	for encounter_variant in matrix.encounter_types:
		var encounter: Dictionary = encounter_variant
		encounter_rows.append(_build_encounter_row(encounter, matrix.build_cases))
	var risks := _build_risk_items(matrix)
	return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Build Balance Regression Smoke Report</title>
  <style>
    body { margin: 0; padding: 28px; background: #f5f7fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    h2 { margin: 28px 0 12px; font-size: 20px; }
    .meta, .note { color: #64748b; line-height: 1.45; margin: 0 0 16px; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; }
    th, td { border-bottom: 1px solid #e5eaf1; padding: 8px 9px; text-align: left; vertical-align: top; font-size: 12px; }
    th { background: #eef2f7; position: sticky; top: 0; }
    td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
    .ok { color: #166534; font-weight: 700; }
    .warn { color: #92400e; font-weight: 700; }
    .bad { color: #991b1b; font-weight: 700; }
    .panel { background: #fff; border: 1px solid #d8dee9; padding: 14px; }
    code { background: #eef2f7; padding: 1px 4px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Build Balance Regression Smoke Report</h1>
  <p class="meta">Source: %s | Version: %s | Builds: %d | Encounter types: %d</p>
  <p class="note">This report is generated from the Phase 6 validation matrix. It is a balance-regression smoke report: it checks coverage shape and omnibuild risk from declared build expectations. It is not measured combat DPS, survival, or route timing data.</p>

  <h2>Build Coverage</h2>
  <table>
    <thead><tr><th>Build</th><th class="num">Strong</th><th class="num">Neutral</th><th class="num">Weak</th><th class="num">Smoke Score</th><th>Regression Read</th></tr></thead>
    <tbody>%s</tbody>
  </table>

  <h2>Encounter Coverage</h2>
  <table>
    <thead><tr><th>Encounter</th><th class="num">Strong Builds</th><th class="num">Weak Builds</th><th>Coverage Read</th></tr></thead>
    <tbody>%s</tbody>
  </table>

  <h2>Risk Summary</h2>
  <div class="panel"><ul>%s</ul></div>

  <h2>Next Adjustment Direction</h2>
  <div class="panel">
    <p>Do not tune weapon numbers from this smoke report alone. The next Phase 6 pass should run measured combat cases from the same matrix, then decide whether the first adjustment belongs to enemy composition, reward weights, route pressure, text clarity, or weapon values.</p>
  </div>
</body>
</html>
""" % [
		_html_escape(MATRIX_PATH),
		_html_escape(str(matrix.version)),
		matrix.build_cases.size(),
		matrix.encounter_types.size(),
		"\n".join(build_rows),
		"\n".join(encounter_rows),
		"\n".join(risks),
	]

func _build_build_row(build_case: Dictionary, encounter_count: int) -> String:
	var strengths := _to_string_array(build_case.get("expected_strengths", PackedStringArray()))
	var weaknesses := _to_string_array(build_case.get("expected_weaknesses", PackedStringArray()))
	var neutral_count := maxi(encounter_count - strengths.size() - weaknesses.size(), 0)
	var score := strengths.size() * 2 + neutral_count
	var read := "OK: has defined strengths and weaknesses."
	var read_class := "ok"
	if strengths.size() >= encounter_count - 1 or weaknesses.is_empty():
		read = "Risk: this build may be too broadly favored."
		read_class = "bad"
	elif strengths.is_empty():
		read = "Risk: this build has no declared favorable matchup."
		read_class = "warn"
	return "<tr><td><strong>%s</strong><br><code>%s</code></td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"%s\">%s</td></tr>" % [
		_html_escape(str(build_case.get("label", build_case.get("id", "")))),
		_html_escape(str(build_case.get("id", ""))),
		strengths.size(),
		neutral_count,
		weaknesses.size(),
		score,
		read_class,
		_html_escape(read),
	]

func _build_encounter_row(encounter: Dictionary, build_cases: Array) -> String:
	var encounter_id := str(encounter.get("id", ""))
	var strong_count := 0
	var weak_count := 0
	for build_variant in build_cases:
		var build_case: Dictionary = build_variant
		if _to_string_array(build_case.get("expected_strengths", PackedStringArray())).has(encounter_id):
			strong_count += 1
		if _to_string_array(build_case.get("expected_weaknesses", PackedStringArray())).has(encounter_id):
			weak_count += 1
	var read := "OK: at least one build is favored and at least one is pressured."
	var read_class := "ok"
	if strong_count <= 0 and weak_count <= 0:
		read = "Risk: encounter is not represented by the build matrix."
		read_class = "bad"
	elif strong_count <= 0:
		read = "Risk: no build is declared strong into this encounter."
		read_class = "bad"
	elif weak_count <= 0:
		read = "Risk: no build is declared weak into this encounter."
		read_class = "bad"
	return "<tr><td><strong>%s</strong><br><code>%s</code></td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"%s\">%s</td></tr>" % [
		_html_escape(str(encounter.get("label", encounter_id))),
		_html_escape(encounter_id),
		strong_count,
		weak_count,
		read_class,
		_html_escape(read),
	]

func _build_risk_items(matrix: Resource) -> PackedStringArray:
	var items := PackedStringArray()
	var omnibuilds := PackedStringArray()
	for build_variant in matrix.build_cases:
		var build_case: Dictionary = build_variant
		var strengths := _to_string_array(build_case.get("expected_strengths", PackedStringArray()))
		var weaknesses := _to_string_array(build_case.get("expected_weaknesses", PackedStringArray()))
		if strengths.size() >= matrix.encounter_types.size() - 1 or weaknesses.is_empty():
			omnibuilds.append(str(build_case.get("label", build_case.get("id", ""))))
	if omnibuilds.is_empty():
		items.append("<li><span class=\"ok\">No omnibuild risk in the declared matrix.</span></li>")
	else:
		items.append("<li><span class=\"bad\">Potential omnibuilds:</span> %s</li>" % _html_escape(", ".join(omnibuilds)))
	items.append("<li><span class=\"ok\">Every encounter should remain both a reward target and a pressure source before weapon value tuning.</span></li>")
	items.append("<li><span class=\"warn\">Reward-pool and route-timing risk is still unmeasured in this smoke report.</span></li>")
	return items

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
