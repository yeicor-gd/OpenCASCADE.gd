extends Node


func test_neutralwindow_opaque_handles() -> String:
	var w := OcgAspectNeutralwindow.new()
	var initial := w.NativeHandle()
	var set := w.SetNativeHandles(0x1A2B, 0, 0)
	if not set:
		return "SetNativeHandles returned false"
	var got := w.NativeHandle()
	if got != 0x1A2B:
		return "NativeHandle expected %s got %s" % [0x1A2B, got]
	if initial == 0x1A2B:
		return "unexpected initial handle %s" % initial
	return "OK"

