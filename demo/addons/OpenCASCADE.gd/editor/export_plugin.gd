@tool
extends EditorExportPlugin
## Auto-downloads and attaches the OpenCASCADE.gd GDExtension library for the platform being
## exported, but only when it is missing locally (a warning is emitted if the download fails).
##
## The download happens in _export_begin(), before the .gdextension file is processed by Godot's
## built-in GDExtension export plugin. If the file were still missing at that point, the built-in
## plugin would silently skip it.

const Downloader := preload("res://addons/OpenCASCADE.gd/editor/github_downloader.gd")

var _handled_key := ""


func _get_name() -> String:
	return "OpenCASCADE.gd"


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	var key := Downloader.best_key_for_features(features)
	if key.is_empty():
		# No [libraries] entry matches this export; leave it to Godot's own plugin to report.
		return
	_handled_key = key
	var lib_path := Downloader.library_abs_path(key)
	if lib_path.is_empty():
		return
	if FileAccess.file_exists(lib_path):
		return
	var result := Downloader.ensure_library(key)
	if result.get("ok", false) and result.get("downloaded", false):
		print("[OpenCASCADE.gd] Downloaded missing library '%s' (%s) for this export." % [Downloader.library_filename(key), Downloader.format_bytes(result.get("bytes", 0))])
	else:
		_warn("The library '%s' needed for this export is missing and could not be downloaded: %s" % [Downloader.library_filename(key), result.get("error", "unknown error")])
		_warn("Download it from the OpenCASCADE.gd library manager (Editor > Manage OpenCASCADE.gd Libraries...) and export again.")


func _warn(message: String) -> void:
	printerr("[OpenCASCADE.gd] Warning: " + message)
	var platform := get_export_platform()
	if platform != null:
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_WARNING, "OpenCASCADE.gd", message)
