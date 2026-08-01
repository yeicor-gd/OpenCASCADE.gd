extends Node


func test_bnd_range_optional() -> String:
	var rng := OcgBndRange.new()
	if rng == null:
		return "Failed to create Bnd_Range"
	# A void range has no bounds: optional returns must be null.
	if rng.Center() != null:
		return "Void range Center() should be null, got %s" % rng.Center()
	if rng.Min() != null or rng.Max() != null:
		return "Void range Min/Max should be null"
	rng.Add_ju0(10.0)
	rng.Add_ju0(20.0)
	if rng.Min() != 10.0:
		return "Min() expected 10.0 got %s" % rng.Min()
	if rng.Max() != 20.0:
		return "Max() expected 20.0 got %s" % rng.Max()
	if rng.Center() != 15.0:
		return "Center() expected 15.0 got %s" % rng.Center()
	return "OK"


func test_bnd_box_optional_point() -> String:
	var p_min := OcgGpPnt.from_668(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_668(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_Wm7(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	var c: Variant = box.Center()
	if c == null:
		return "Bnd_Box::Center() should not be null"
	var center := c as OcgGpPnt
	if center == null:
		return "Bnd_Box::Center() should wrap a gp_Pnt"
	if center.X() != 3.0 or center.Y() != 4.0 or center.Z() != 5.0:
		return "Center() wrong: %s,%s,%s" % [center.X(), center.Y(), center.Z()]
	box.SetVoid()
	if box.Center() != null:
		return "Void Bnd_Box::Center() should be null"
	return "OK"


func test_graphic3d_text_string() -> String:
	var text := OcgGraphic3dText.from_rYr(0.01)
	if text == null:
		return "Failed to create Graphic3d_Text"
	text.SetText_mJu("Hello, OCC!")
	if text.Text() != "Hello, OCC!":
		return "Text roundtrip failed: %s" % text.Text()
	text.SetText_mJu("ÄÖÜ ❤ 日本語")
	if text.Text() != "ÄÖÜ ❤ 日本語":
		return "Text UTF-8 roundtrip failed: %s" % text.Text()
	return "OK"


func test_xscontrol_utils_utf16() -> String:
	var utils := OcgXscontrolUtils.new()
	var s := utils.AsciiToExtended("Hello")
	if s != "Hello":
		return "AsciiToExtended failed: %s" % s
	var back := utils.ToEString_BVX(s)
	if back != "Hello":
		return "ToEString roundtrip failed: %s" % back
	return "OK"


func test_list_enum_append() -> String:
	var lst := OcgNcollectionListBrepcheckStatus.new()
	if lst == null:
		return "Failed to create List<BRepCheck_Status>"
	lst.Append_wrR(OcgEnums.BRepCheck_Status.BRepCheck_NoError)
	lst.Append_wrR(OcgEnums.BRepCheck_Status.BRepCheck_Invalid3DCurve)
	lst.Prepend_wrR(OcgEnums.BRepCheck_Status.BRepCheck_No3DCurve)
	if lst.Extent() != 3:
		return "List Extent wrong: %s" % lst.Extent()
	if lst.First() != OcgEnums.BRepCheck_Status.BRepCheck_No3DCurve:
		return "List First wrong after Prepend"
	if lst.Last() != OcgEnums.BRepCheck_Status.BRepCheck_Invalid3DCurve:
		return "List Last wrong after Append"
	return "OK"


func test_list_byte_append() -> String:
	var lst := OcgNcollectionListUnsignedChar.new()
	if lst == null:
		return "Failed to create List<unsigned char>"
	lst.Append_sad(1)
	lst.Append_sad(200)
	lst.Prepend_sad(7)
	if lst.Extent() != 3:
		return "List Extent wrong: %s" % lst.Extent()
	if lst.First() != 7 or lst.Last() != 200:
		return "List First/Last wrong"
	return "OK"


func test_splitter_pair_returns() -> String:
	var splitter := OcgBrepmeshDefaultrangesplitter.new()
	if splitter == null:
		return "Failed to create BRepMesh_DefaultRangeSplitter"
	var ru: Variant = splitter.GetRangeU()
	if not ru is PackedFloat64Array:
		return "GetRangeU should return PackedFloat64Array, got %s" % ru
	if (ru as PackedFloat64Array).size() != 2:
		return "GetRangeU should have 2 elements"
	return "OK"
