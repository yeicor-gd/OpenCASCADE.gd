extends Node


func test_neutralwindow_opaque_handles() -> String:
	var w := OcgAspectNeutralWindow.new()
	if w == null:
		return "Failed to create Aspect_NeutralWindow"
	var initial := w.native_handle()
	if not w.set_native_handle(0x1A2B):
		return "SetNativeHandle returned false"
	var got := w.native_handle()
	if got != 0x1A2B:
		return "NativeHandle expected %s got %s" % [0x1A2B, got]
	if initial == 0x1A2B:
		return "unexpected initial handle %s" % initial
	return "OK"
