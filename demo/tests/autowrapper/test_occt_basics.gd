extends Node


func test_occt_loads() -> String:
	var pnt := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	if pnt == null:
		return "Failed to create gp_Pnt"
	if pnt.x() != 1.0:
		return "X() expected 1.0 got %s" % pnt.x()
	if pnt.y() != 2.0:
		return "Y() expected 2.0 got %s" % pnt.y()
	if pnt.z() != 3.0:
		return "Z() expected 3.0 got %s" % pnt.z()
	return "OK"


func test_vec_operations() -> String:
	var vec := OcgGpVec.from_6(1.0, 0.0, 0.0)
	if vec == null:
		return "Failed to create gp_Vec"
	if vec.x() != 1.0:
		return "Vec.X() expected 1.0 got %s" % vec.x()
	return "OK"


func test_null_check() -> String:
	var pnt := OcgGpPnt.new()
	# Default-constructed wrapper has empty _native; accessing it should not crash.
	pnt.set_x(5.0)
	if pnt.x() != 5.0:
		return "SetX/X roundtrip failed"
	return "OK"
