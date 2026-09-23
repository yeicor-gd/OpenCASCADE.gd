extends Node


func test_neutralwindow_basic_operations() -> String:
	# Aspect_NeutralWindow is a cross-platform Godot-suitable window wrapper.
	# Verify it can be instantiated and that basic methods work.
	var w := OcgAspectNeutralWindow.new()
	if w == null:
		return "Failed to create Aspect_NeutralWindow"

	# Type name should match
	var type_name := OcgAspectNeutralWindow.get_type_name()
	if not (type_name as String).contains("NeutralWindow"):
		return "get_type_name() should mention NeutralWindow, got: '%s'" % type_name

	# A freshly constructed window should not report null handle
	if w.is_null():
		return "NeutralWindow.is_null() returned true for a valid window"

	# is_mapped() must return a bool without crashing (value is platform-dependent)
	var _mapped: bool = w.is_mapped()

	# set_size and set_position should return a bool without crashing
	var _ok_size: bool = w.set_size(800, 600)
	var _ok_pos: bool = w.set_position_k(0, 0)

	return "OK"
