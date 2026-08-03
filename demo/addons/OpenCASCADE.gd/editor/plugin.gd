@tool
extends EditorPlugin

const MENU_ITEM_NAME := "Manage OpenCASCADE.gd Libraries..."
const MENU_ITEM_ID := 0x0CA5E
const Downloader := preload("res://addons/OpenCASCADE.gd/editor/github_downloader.gd")

var _manager: ConfirmationDialog
var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/OpenCASCADE.gd/editor/export_plugin.gd").new()
	add_export_plugin(_export_plugin)

	_manager = preload("res://addons/OpenCASCADE.gd/editor/library_manager.gd").new()
	_manager.hide()
	EditorInterface.get_base_control().add_child(_manager)
	_install_settings_menu_item()
	_check_libraries_installed()


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	var menu := _find_settings_menu()
	if menu != null:
		if menu.id_pressed.is_connected(_on_settings_menu_id_pressed):
			menu.id_pressed.disconnect(_on_settings_menu_id_pressed)
		if menu.about_to_popup.is_connected(_ensure_settings_menu_item):
			menu.about_to_popup.disconnect(_ensure_settings_menu_item)
		var index := menu.get_item_index(MENU_ITEM_ID)
		if index >= 0:
			menu.remove_item(index)
	if _manager != null:
		_manager.shutdown()
		_manager.queue_free()
		_manager = null


## Appends our item to the Editor menu. PopupMenu has no insert/move API (unlike
## MenuBar), so the item is placed at the end of the menu.
func _install_settings_menu_item() -> void:
	var menu := _find_settings_menu()
	if menu == null:
		push_warning("OpenCASCADE.gd: could not locate the Editor menu; the library manager is not available.")
		return
	if menu.get_item_index(MENU_ITEM_ID) < 0:
		menu.add_item(MENU_ITEM_NAME, MENU_ITEM_ID)
	if not menu.id_pressed.is_connected(_on_settings_menu_id_pressed):
		menu.id_pressed.connect(_on_settings_menu_id_pressed)
	# The engine rebuilds the Editor menu (clearing external items) when the menu
	# mode changes, so re-add the item right before the menu is shown.
	if not menu.about_to_popup.is_connected(_ensure_settings_menu_item):
		menu.about_to_popup.connect(_ensure_settings_menu_item)


## Re-adds the menu item if the engine rebuilt the Editor menu (e.g. after the
## editor menu mode changed), which would otherwise wipe external entries.
func _ensure_settings_menu_item() -> void:
	var menu := _find_settings_menu()
	if menu == null:
		return
	if menu.get_item_index(MENU_ITEM_ID) < 0:
		menu.add_item(MENU_ITEM_NAME, MENU_ITEM_ID)


## Warns the user when no prebuilt library is installed at all, pointing them to the
## library manager. This runs on plugin load and does not touch the network.
func _check_libraries_installed() -> void:
	var config := Downloader._load_config()
	if config == null or not config.has_section("libraries"):
		return
	for key in config.get_section_keys("libraries"):
		var lib_abs := Downloader.library_abs_path(String(key))
		if not lib_abs.is_empty() and FileAccess.file_exists(lib_abs):
			return
	push_warning(
		"No OpenCASCADE.gd library is installed. Use Editor > %s to download the library for your platform and/or the platform(s) you plan to export your project to." % MENU_ITEM_NAME
	)


func _find_settings_menu() -> PopupMenu:
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	for child in base.find_children("*", "PopupMenu", true, false):
		if child is PopupMenu and child.name == "Editor":
			return child
	return null


func _on_settings_menu_id_pressed(id: int) -> void:
	if id == MENU_ITEM_ID and _manager != null:
		_manager.popup_centered()
