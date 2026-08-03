@tool
extends EditorPlugin

const MENU_ITEM_NAME := "Manage OpenCASCADE.gd Libraries..."
const MENU_ITEM_ID := 0x0CA5E

var _manager: ConfirmationDialog
var _export_plugin: EditorExportPlugin
var _menu_index := -1


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/OpenCASCADE.gd/editor/export_plugin.gd").new()
	add_export_plugin(_export_plugin)

	_manager = preload("res://addons/OpenCASCADE.gd/editor/library_manager.gd").new()
	_manager.hide()
	EditorInterface.get_base_control().add_child(_manager)
	_install_settings_menu_item()


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	if _menu_index >= 0:
		var menu := _find_settings_menu()
		if menu != null:
			menu.id_pressed.disconnect(_on_settings_menu_id_pressed)
			if _menu_index < menu.item_count:
				menu.remove_item(_menu_index)
		_menu_index = -1
	if _manager != null:
		_manager.shutdown()
		_manager.queue_free()
		_manager = null


## Inserts our item into the Editor menu, right after "Manage Export Templates...".
func _install_settings_menu_item() -> void:
	var menu := _find_settings_menu()
	if menu == null:
		push_warning("OpenCASCADE.gd: could not locate the Editor menu; the library manager is not available.")
		return
	var insert_at := menu.item_count
	for i in menu.item_count:
		if menu.get_item_text(i) == "Manage Export Templates...":
			insert_at = i + 1
			break
	_menu_index = menu.item_count
	menu.add_item(MENU_ITEM_NAME, MENU_ITEM_ID)
	if insert_at != menu.item_count:
		menu.move_item(_menu_index, insert_at)
		_menu_index = insert_at
	menu.id_pressed.connect(_on_settings_menu_id_pressed)


func _find_settings_menu() -> PopupMenu:
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	for child in base.find_children("*", "PopupMenu", true, false):
		if child is PopupMenu and child.name == "Editor" and child.get_parent() is MenuBar:
			return child
	return null


func _on_settings_menu_id_pressed(id: int) -> void:
	if id == MENU_ITEM_ID and _manager != null:
		_manager.popup_centered()
