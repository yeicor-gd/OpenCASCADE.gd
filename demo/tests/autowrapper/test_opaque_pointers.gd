extends Node


func test_neutralwindow_opaque_handles() -> String:
	var w := OcgAspectNeutralWindow.new()
	var initial := w.native_handle()
	var mset := w.set_native_handles(0x1A2B, 0, 0)
	if not mset:
		return "SetNativeHandles returned false"
	var got := w.native_handle()
	if got != 0x1A2B:
		return "NativeHandle expected %s got %s" % [0x1A2B, got]
	if initial == 0x1A2B:
		return "unexpected initial handle %s" % initial
	return "OK"
