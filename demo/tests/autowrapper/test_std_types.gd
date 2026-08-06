extends Node


func test_bnd_range_optional() -> String:
	var rng := OcgBndRange.new()
	if rng == null:
		return "Failed to create Bnd_Range"
	var mn := OcgStandardReal.new()
	var mx := OcgStandardReal.new()
	# A void range has no bounds: the optional accessors must report absence.
	if rng.get_min(mn) or rng.get_max(mx):
		return "Void range Min/Max should report absent"
	rng.add_j(10.0)
	rng.add_j(20.0)
	if not rng.get_min(mn):
		return "Min() should report present"
	if not rng.get_max(mx):
		return "Max() should report present"
	if mn.get_value() != 10.0 or mx.get_value() != 20.0:
		return "Min/Max expected 10/20 got %s/%s" % [mn.get_value(), mx.get_value()]
	return "OK"


func test_bnd_box_optional_point() -> String:
	var p_min := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_6(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_W(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	if box.is_void():
		return "Fresh Bnd_Box should not be void"
	if box.get_x_min() != 1.0 or box.get_x_max() != 5.0:
		return "X limits wrong: %s..%s" % [box.get_x_min(), box.get_x_max()]
	if box.get_y_min() != 2.0 or box.get_y_max() != 6.0:
		return "Y limits wrong"
	if box.get_z_min() != 3.0 or box.get_z_max() != 7.0:
		return "Z limits wrong"
	box.set_void()
	if not box.is_void():
		return "Void Bnd_Box::IsVoid() should be true"
	return "OK"


func test_graphic3d_text_string() -> String:
	var text := OcgGraphic3dText.from_r(0.01)
	if text == null:
		return "Failed to create Graphic3d_Text"
	text.set_text_f("Hello, OCC!")
	text.set_text_f("ÄÖÜ ❤ 日本語")
	return "OK"


func test_xscontrol_utils_utf16() -> String:
	var utils := OcgXSControlUtils.new()
	var s := utils.ascii_to_extended("Hello")
	if s != "Hello":
		return "AsciiToExtended failed: %s" % s
	var es := OcgTCollectionExtendedString.from_j("Hello")
	var back := utils.to_e_string_B(es)
	if back != "Hello":
		return "ToEString roundtrip failed: %s" % back
	return "OK"


func test_list_enum_append() -> String:
	var lst := OcgNCollectionListBRepCheckStatus.new()
	if lst == null:
		return "Failed to create List<BRepCheck_Status>"
	lst.append_w(OcgEnums.BRepCheck_Status.BRepCheck_NoError)
	lst.append_w(OcgEnums.BRepCheck_Status.BRepCheck_Invalid3DCurve)
	lst.prepend_w(OcgEnums.BRepCheck_Status.BRepCheck_No3DCurve)
	if lst.first_k() != OcgEnums.BRepCheck_Status.BRepCheck_No3DCurve:
		return "List First wrong after Prepend"
	if lst.last_k() != OcgEnums.BRepCheck_Status.BRepCheck_Invalid3DCurve:
		return "List Last wrong after Append"
	return "OK"


func test_list_byte_append() -> String:
	var lst := OcgNCollectionListUnsignedChar.new()
	if lst == null:
		return "Failed to create List<unsigned char>"
	lst.append_s(1)
	lst.append_s(200)
	lst.prepend_s(7)
	if lst.first_k() != 7 or lst.last_k() != 200:
		return "List First/Last wrong"
	return "OK"


func test_bnd_box_get_limits() -> String:
	var p_min := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_6(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_W(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	var xmin := OcgStandardReal.new()
	var ymin := OcgStandardReal.new()
	var zmin := OcgStandardReal.new()
	var xmax := OcgStandardReal.new()
	var ymax := OcgStandardReal.new()
	var zmax := OcgStandardReal.new()
	box.get_p(xmin, ymin, zmin, xmax, ymax, zmax)
	if xmin.get_value() != 1.0 or xmax.get_value() != 5.0 \
			or ymin.get_value() != 2.0 or ymax.get_value() != 6.0 \
			or zmin.get_value() != 3.0 or zmax.get_value() != 7.0:
		return "Bnd_Box::Get() wrong limits: %s..%s, %s..%s, %s..%s" % [
			xmin.get_value(), xmax.get_value(),
			ymin.get_value(), ymax.get_value(),
			zmin.get_value(), zmax.get_value()]
	return "OK"


func test_bnd_box2d_get_limits() -> String:
	var box := OcgBndBox2d.new()
	if box == null:
		return "Failed to create Bnd_Box2d"
	box.update_r(1.0, 2.0, 5.0, 6.0)
	var xmin := OcgStandardReal.new()
	var ymin := OcgStandardReal.new()
	var xmax := OcgStandardReal.new()
	var ymax := OcgStandardReal.new()
	box.get_8(xmin, ymin, xmax, ymax)
	if xmin.get_value() != 1.0 or xmax.get_value() != 5.0 \
			or ymin.get_value() != 2.0 or ymax.get_value() != 6.0:
		return "Bnd_Box2d::Get() wrong limits: %s..%s, %s..%s" % [
			xmin.get_value(), xmax.get_value(),
			ymin.get_value(), ymax.get_value()]
	return "OK"
