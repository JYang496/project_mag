extends SceneTree

const MatrixScript := preload("res://data/test/build_validation_matrix.gd")
const MATRIX_PATH := "res://data/test/build_validation_matrix_default.tres"
const REPORT_PATH := "res://docs/reports/build_validation_matrix.html"
const BALANCE_REPORT_PATH := "res://docs/reports/build_balance_regression_smoke_report.html"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var matrix := load(MATRIX_PATH)
	if matrix == null or not (matrix is MatrixScript):
		failures.append("cannot load matrix: %s" % MATRIX_PATH)
	var html := FileAccess.get_file_as_string(REPORT_PATH)
	if html.strip_edges() == "":
		failures.append("report is missing or empty: %s" % REPORT_PATH)
	if not html.contains("This is a Phase 6 validation matrix report"):
		failures.append("report is missing Phase 6 scope note")
	var balance_html := FileAccess.get_file_as_string(BALANCE_REPORT_PATH)
	if balance_html.strip_edges() == "":
		failures.append("balance smoke report is missing or empty: %s" % BALANCE_REPORT_PATH)
	if not balance_html.contains("Build Balance Regression Smoke Report"):
		failures.append("balance smoke report is missing title")
	if not balance_html.contains("not measured combat DPS"):
		failures.append("balance smoke report is missing non-measured scope note")
	if matrix != null:
		for build_variant in matrix.build_cases:
			var build_case: Dictionary = build_variant
			var label := str(build_case.get("label", build_case.get("id", "")))
			if label != "" and not html.contains(label):
				failures.append("report missing build label: %s" % label)
			if label != "" and not balance_html.contains(label):
				failures.append("balance smoke report missing build label: %s" % label)
		for encounter_variant in matrix.encounter_types:
			var encounter: Dictionary = encounter_variant
			var label := str(encounter.get("label", encounter.get("id", "")))
			if label != "" and not html.contains(label):
				failures.append("report missing encounter label: %s" % label)
			if label != "" and not balance_html.contains(label):
				failures.append("balance smoke report missing encounter label: %s" % label)
	if failures.is_empty():
		print("PASS: build validation matrix report artifact")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: build validation matrix report: %s" % failure)
	quit(1)
