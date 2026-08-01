extends Node


func test_occt_loads() -> String:
	var pnt := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	if pnt == null:
		return "Failed to create gp_Pnt"
	if pnt.X() != 1.0:
		return "X() expected 1.0 got %s" % pnt.X()
	if pnt.Y() != 2.0:
		return "Y() expected 2.0 got %s" % pnt.Y()
	if pnt.Z() != 3.0:
		return "Z() expected 3.0 got %s" % pnt.Z()
	return "OK"


func test_vec_operations() -> String:
	var vec := OcgGpVec.from_6(1.0, 0.0, 0.0)
	if vec == null:
		return "Failed to create gp_Vec"
	if vec.X() != 1.0:
		return "Vec.X() expected 1.0 got %s" % vec.X()
	return "OK"


func test_null_check() -> String:
	var pnt := OcgGpPnt.new()
	# Default-constructed wrapper has empty _native; accessing it should not crash.
	pnt.SetX(5.0)
	if pnt.X() != 5.0:
		return "SetX/X roundtrip failed"
	return "OK"
