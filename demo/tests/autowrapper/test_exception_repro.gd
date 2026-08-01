extends Node


func test_exception_guard_construction() -> String:
	OcgErrors.clear_last_error()
	var bad := OcgGpDir.from_668(0.0, 0.0, 0.0)
	if bad != null:
		return "from_668(0,0,0) expected null (caught exception) but got an object"
	var msg := OcgErrors.get_last_error_message()
	if msg == "":
		return "expected a recorded last-error message"
	return "OK"


func test_exception_guard_method() -> String:
	var dir := OcgGpDir.from_668(1.0, 0.0, 0.0)
	if dir == null:
		return "failed to create valid gp_Dir"
	OcgErrors.clear_last_error()
	dir.SetCoord_ncK(5, 0.0)
	var msg := OcgErrors.get_last_error_message()
	if msg == "":
		return "expected last-error message after SetCoord_ncK(5, ...)"
	# The object state survives the caught exception.
	if dir.X() != 1.0:
		return "gp_Dir state corrupted after caught exception"
	return "OK"


func test_exception_guard_survives() -> String:
	OcgErrors.clear_last_error()
	var bad := OcgGpDir.from_668(0.0, 0.0, 0.0)
	if bad != null:
		return "expected null from bad construction"
	var good := OcgGpDir.from_668(0.0, 0.0, 1.0)
	if good == null:
		return "expected valid gp_Dir after a guarded failure"
	return "OK"


func test_signal_conversion() -> String:
	# Dereferencing a null Ref arg segfaults during arg extraction; OSD::SetSignal
	# + OCC_CATCH_SIGNALS must convert that SIGSEGV into a catchable error.
	OcgErrors.clear_last_error()
	var pnt := OcgGpPnt.new()
	pnt.SetXYZ(null)
	var msg := OcgErrors.get_last_error_message()
	if msg == "":
		return "expected recorded last-error after null-Ref SIGSEGV"
	var good := OcgGpPnt.from_668(1.0, 2.0, 3.0)
	if good == null:
		return "extension must survive a converted signal"
	return "OK"
