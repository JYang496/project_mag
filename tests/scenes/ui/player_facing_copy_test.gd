extends Node

const SEARCH_ROOTS: PackedStringArray = [
	"res://World",
	"res://Player",
	"res://Combat",
	"res://Board",
	"res://Objects",
	"res://UI",
]
const FORBIDDEN_SCENE_SNIPPETS: PackedStringArray = [
	"text = \"Item name\"",
	"text = \"Desription\"",
	"text = \"Cost\"",
	"text = \"=====\"",
	"text = \"Select Panel\"",
	"text = \"ui.",
	" : value\"",
]
const FORBIDDEN_COPY_SNIPPETS: PackedStringArray = [
	"Project Mag Title",
	"Project Mag 标题",
]

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var scene_files: PackedStringArray = []
	for root in SEARCH_ROOTS:
		_collect_scene_files(root, scene_files)
	_assert_true(not scene_files.is_empty(), "Player-facing scene scan should discover runtime scenes.")
	for path in scene_files:
		_scan_file(path, FORBIDDEN_SCENE_SNIPPETS)
	_scan_file("res://data/localization/ui_texts.csv", FORBIDDEN_COPY_SNIPPETS)
	_test_localized_title()
	_finish()

func _collect_scene_files(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_fail("Unable to scan runtime directory: %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_scene_files(path, output)
			elif entry.ends_with(".tscn"):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _scan_file(path: String, forbidden_snippets: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Unable to read copy source: %s" % path)
		return
	var content := file.get_as_text()
	for snippet in forbidden_snippets:
		if content.contains(snippet):
			_fail("Player-facing placeholder '%s' remains in %s" % [snippet, path])

func _test_localized_title() -> void:
	var original_locale := LocalizationManager.get_locale()
	LocalizationManager.set_locale("en")
	_assert_equal("Protocol: Mag Arena", LocalizationManager.tr_key("ui.start.title", "Protocol: Mag Arena"), "English title should use the release name.")
	LocalizationManager.set_locale("zh_CN")
	_assert_equal("协议：磁核竞技场", LocalizationManager.tr_key("ui.start.title", "Protocol: Mag Arena"), "Chinese title should use the release name.")
	LocalizationManager.set_locale(original_locale)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)

func _finish() -> void:
	if _failed:
		print("FAIL: player-facing copy")
	else:
		print("PASS: player-facing copy")
	get_tree().quit(1 if _failed else 0)
