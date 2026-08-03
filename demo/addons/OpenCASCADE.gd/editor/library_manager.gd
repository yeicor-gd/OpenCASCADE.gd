@tool
extends ConfirmationDialog
## Manager dialog (a neighbor of "Editor > Manage Export Templates...") for the prebuilt
## OpenCASCADE.gd GDExtension libraries.
##
## Libraries are served by the nightly.link mirror of the GitHub Actions artifacts, so no GitHub
## token is needed. Downloads run on a worker thread (the export path still uses synchronous
## downloads) and report progress back through the dialog.

const Downloader := preload("res://addons/OpenCASCADE.gd/editor/github_downloader.gd")

const COLOR_NO_ARTIFACT := Color(0.6, 0.6, 0.6)
const COLOR_MISSING := Color(0.9, 0.5, 0.2)
const COLOR_UPDATE := Color(0.9, 0.7, 0.2)
const COLOR_OK := Color(0.4, 0.8, 0.4)

var _tree: Tree
var _status_label: Label
var _progress_bar: ProgressBar
var _refresh_button: Button
var _download_selected_button: Button
var _download_missing_button: Button

var _rows := {}
var _queue: Array[String] = []
var _downloading := false
var _thread: Thread = null
var _job := {"active": false, "key": "", "progress": 0, "total": 0, "result": {}, "done": false}


func _ready() -> void:
	title = "Manage OpenCASCADE.gd Libraries"
	ok_button_text = "Close"
	min_size = Vector2(760, 420)
	_build_ui()
	_status_label.text = "Press \"Refresh\" to check GitHub for available builds."
	_clamp_to_available_size()


## Caps the dialog to the available editor area so it never overflows the screen,
## regardless of how many rows the tree contains.
func _clamp_to_available_size() -> void:
	var screen := DisplayServer.SCREEN_OF_MAIN_WINDOW
	var rect := DisplayServer.screen_get_usable_rect(screen)
	var limit := Vector2i(maxi(rect.size.x - 40, 480), maxi(rect.size.y - 40, 360))
	max_size = limit
	min_size = min_size.min(Vector2(limit))


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	var header := Label.new()
	header.text = "Prebuilt OpenCASCADE.gd libraries are built by the %s/%s GitHub Actions workflow and downloaded through nightly.link (no GitHub token required). After installing a library, restart the editor to load it." % [Downloader.REPO_OWNER, Downloader.REPO_NAME]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 12)
	box.add_child(header)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 6
	_tree.set_column_titles_visible(true)
	_tree.set_column_title(0, "Status")
	_tree.set_column_title(1, "Library")
	_tree.set_column_title(2, "Filename")
	_tree.set_column_title(3, "Artifact")
	_tree.set_column_title(4, "Built")
	_tree.set_column_title(5, "Local")
	_tree.set_column_expand(1, true)
	_tree.set_column_expand(2, true)
	_tree.allow_reselect = true
	_tree.select_mode = Tree.SELECT_MULTI
	box.add_child(_tree)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = true
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.visible = false
	box.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh"
	_refresh_button.pressed.connect(refresh)
	buttons.add_child(_refresh_button)
	_download_selected_button = Button.new()
	_download_selected_button.text = "Download Selected"
	_download_selected_button.tooltip_text = "Download the library for the selected row(s)."
	_download_selected_button.pressed.connect(_on_download_selected)
	buttons.add_child(_download_selected_button)
	_download_missing_button = Button.new()
	_download_missing_button.text = "Download Missing"
	_download_missing_button.tooltip_text = "Download every library that is not installed (or is outdated) and has a CI artifact."
	_download_missing_button.pressed.connect(_on_download_missing)
	buttons.add_child(_download_missing_button)
	var ci_button := Button.new()
	ci_button.text = "GitHub Actions"
	ci_button.tooltip_text = "Open the CI build page in a browser"
	ci_button.pressed.connect(func() -> void: OS.shell_open("https://github.com/%s/%s/actions" % [Downloader.REPO_OWNER, Downloader.REPO_NAME]))
	buttons.add_child(ci_button)


func _all_keys() -> Array[String]:
	var config := Downloader._load_config()
	var keys: Array[String] = []
	if config != null and config.has_section("libraries"):
		for key in config.get_section_keys("libraries"):
			keys.append(String(key))
	return keys


func refresh() -> void:
	_set_busy(true)
	_status_label.text = "Checking available builds..."
	var keys := _all_keys()
	var names := PackedStringArray()
	for key in keys:
		var name := Downloader.artifact_name_for_key(key)
		if not name.is_empty() and not names.has(name):
			names.append(name)
	var result := Downloader.list_artifacts(names)
	var artifacts: Dictionary = result.get("artifacts", {}) if result.get("ok", false) else {}
	_populate_tree(keys, artifacts)
	if not result.get("ok", false):
		_status_label.text = "Could not reach GitHub: %s" % result.get("error", "unknown error")
	else:
		_status_label.text = _summary(keys, artifacts)
	_set_busy(false)


func _populate_tree(keys: Array[String], artifacts: Dictionary) -> void:
	_tree.clear()
	_rows.clear()
	var current_key := Downloader.best_key_for_os()
	for key in keys:
		var parts := String(key).split(".")
		var item := _tree.create_item()
		item.set_metadata(0, key)
		var artifact: Dictionary = artifacts.get(Downloader.artifact_name_for_key(key), {})
		_fill_row(item, key, parts, artifact, key == current_key)
		_rows[key] = item


func _fill_row(item: TreeItem, key: String, parts: PackedStringArray, artifact: Dictionary, is_current: bool) -> void:
	var build := "debug" if parts.has("debug") else "release"
	var precision := String(parts[parts.size() - 1])
	var threads := " threads" if parts.has("threads") else ""
	var label := "%s · %s%s · %s · %s" % [String(parts[0]), String(parts[1]), threads, precision, build]
	if is_current:
		label = "* " + label
	item.set_text(1, label)

	var lib_abs := Downloader.library_abs_path(key)
	var installed := not lib_abs.is_empty() and FileAccess.file_exists(lib_abs)
	var status_text := "No artifact"
	var color := COLOR_NO_ARTIFACT
	if not artifact.is_empty():
		var artifact_time := Downloader.github_time_to_msec(artifact.get("created_at", ""))
		if not installed:
			status_text = "Missing"
			color = COLOR_MISSING
		elif artifact_time > Downloader.library_modified_time(key) * 1000:
			status_text = "Update available"
			color = COLOR_UPDATE
		else:
			status_text = "Up to date"
			color = COLOR_OK
	item.set_text(0, status_text)
	item.set_custom_color(0, color)

	item.set_text(2, Downloader.library_filename(key))
	if artifact.is_empty():
		item.set_text(3, "-")
		item.set_text(4, "-")
	else:
		item.set_text(3, Downloader.format_bytes(int(artifact.get("size_in_bytes", 0))))
		item.set_text(4, String(artifact.get("created_at", "")).replace("T", " ").replace("Z", ""))
	item.set_text(5, "Installed" if installed else "Not installed")


func _summary(keys: Array[String], artifacts: Dictionary) -> String:
	var ok := 0
	var missing := 0
	var update := 0
	var none := 0
	for key in keys:
		var artifact: Dictionary = artifacts.get(Downloader.artifact_name_for_key(key), {})
		var lib_abs := Downloader.library_abs_path(key)
		var installed := not lib_abs.is_empty() and FileAccess.file_exists(lib_abs)
		if artifact.is_empty():
			none += 1
		elif not installed:
			missing += 1
		elif Downloader.github_time_to_msec(artifact.get("created_at", "")) > Downloader.library_modified_time(key) * 1000:
			update += 1
		else:
			ok += 1
	return "%d up to date, %d missing, %d update available, %d no CI artifact." % [ok, missing, update, none]


func _on_download_selected() -> void:
	var keys: Array[String] = []
	for item in _tree.get_selected_items():
		var key := String(item.get_metadata(0))
		if not key.is_empty():
			keys.append(key)
	_enqueue_all(keys)


func _on_download_missing() -> void:
	var keys: Array[String] = []
	for key in _rows:
		var item: TreeItem = _rows[key]
		var status := item.get_text(0)
		if status == "Missing" or status == "Update available":
			keys.append(String(key))
	_enqueue_all(keys)
	if keys.is_empty():
		_status_label.text = "Everything is up to date (or has no CI artifact)."


func _enqueue_all(keys: Array[String]) -> void:
	var started := false
	for key in keys:
		if not _queue.has(key):
			_queue.append(key)
			started = true
	if started:
		_start_next()


func _start_next() -> void:
	if _downloading or _queue.is_empty():
		return
	var key := _queue[0]
	_queue.remove_at(0)
	_downloading = true
	_status_label.text = "Downloading %s..." % Downloader.library_filename(key)
	_set_busy(true)
	_progress_bar.max_value = 1
	_progress_bar.value = 0
	_progress_bar.visible = true
	_job = {"active": true, "key": key, "progress": 0, "total": 0, "result": {}, "done": false}
	_thread = Thread.new()
	_thread.start(_worker.bind(_job))


func _worker(job: Dictionary) -> void:
	var result := Downloader.install_library_for_key(job.key, func(written: int, total: int) -> void:
		job.progress = written
		job.total = total
	)
	job.result = result
	job.done = true


func _process(_delta: float) -> void:
	if not _job.active:
		return
	if _job.total > 0:
		_progress_bar.max_value = _job.total
		_progress_bar.value = _job.progress
	if _job.done:
		_finish_job()


func _finish_job() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_job.active = false
	_progress_bar.visible = false
	var result: Dictionary = _job.result
	if result.get("ok", false):
		_status_label.text = "Installed %s (%s). Restart the editor to load it." % [result.get("filename", ""), Downloader.format_bytes(result.get("bytes", 0))]
	else:
		_status_label.text = "Download failed: %s" % result.get("error", "unknown error")
		printerr("[OpenCASCADE.gd] %s" % result.get("error", "unknown error"))
	_downloading = false
	refresh()
	_start_next()


func _set_busy(busy: bool) -> void:
	_refresh_button.disabled = busy
	_download_selected_button.disabled = busy
	_download_missing_button.disabled = busy


func shutdown() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
		_job.active = false
