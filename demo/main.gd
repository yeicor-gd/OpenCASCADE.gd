extends BoxContainer

@export var demo_scene: PackedScene
@export var tests_scene: PackedScene

func _ready():
	_show_web_hint()
	_show_license_hint()

	var env_test_runner := OS.get_environment("GODOT_TEST_RUNNER") == "true"
	var is_headless_mode := DisplayServer.get_name() == "headless"
	var should_auto_test := env_test_runner or is_headless_mode

	if OS.get_environment("GDEXT_AUTO_TESTS") == "true" or should_auto_test:
		_on_tests_button_pressed()


func _show_license_hint() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_END

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "This addon statically links Open CASCADE Technology 6.7.0+, "
	label.text += "which is governed by the GNU Lesser General Public License (LGPL) version 2.1 "
	label.text += "with additional exception. You can rebuild it from the sources at "
	label.text += "https://github.com/yeicor-gd/OpenCASCADE.gd."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)

	add_child(panel)


func _show_web_hint() -> void:
	if not OS.has_feature("web"):
		return

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_END

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var info := Label.new()
	info.text = "For better performance, download the native version for your platform:"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)

	var link := LinkButton.new()
	link.text = "https://github.com/yeicor-gd/OpenCASCADE.gd/actions"
	link.uri = "https://github.com/yeicor-gd/OpenCASCADE.gd/actions"
	vb.add_child(link)

	add_child(panel)


func _on_demo_button_pressed() -> void:
	if demo_scene != null:
		get_tree().change_scene_to_packed.call_deferred(demo_scene)
	else:
		push_error("Demo scene not set")


func _on_tests_button_pressed() -> void:
	if tests_scene != null:
		get_tree().change_scene_to_packed.call_deferred(tests_scene)
	else:
		push_error("Tests scene not set")
