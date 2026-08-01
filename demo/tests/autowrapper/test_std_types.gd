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


func test_packed_map_of_integer() -> String:
	var pmap := OcgTcolstdPackedmapofinteger.new()
	if pmap == null:
		return "Failed to create TColStd_PackedMapOfInteger"
	if not pmap.IsEmpty():
		return "Fresh map should be empty"
	if pmap.Add(42) != true:
		return "Add(42) should return true"
	if pmap.Add(42) != false:
		return "Add(42) twice should return false"
	if pmap.Add(-7) != true:
		return "Add(-7) should return true"
	if pmap.Extent() != 2 or pmap.Length() != 2:
		return "Extent/Length should be 2, got %d/%d" % [pmap.Extent(), pmap.Length()]
	if not pmap.Contains(42) or not pmap.Contains(-7) or pmap.Contains(3):
		return "Contains checks wrong"
	if pmap.Remove(42) != true:
		return "Remove(42) should return true"
	if pmap.Remove(42) != false:
		return "Remove(42) twice should return false"
	if pmap.Extent() != 1:
		return "Extent should be 1 after removal"
	pmap.Clear()
	if not pmap.IsEmpty():
		return "Map should be empty after Clear"
	return "OK"


func test_hpacked_map_of_integer_map() -> String:
	var pmap := OcgTcolstdPackedmapofinteger.new()
	pmap.Add(10)
	pmap.Add(20)
	var hmap := OcgTcolstdHpackedmapofinteger.from__3s(pmap)
	if hmap == null:
		return "Failed to create TColStd_HPackedMapOfInteger"
	var out := hmap.Map()
	if out == null:
		return "Map() should return a map"
	if out.Extent() != 2 or not out.Contains(20):
		return "Map() contents wrong: Extent=%d" % out.Extent()
	out.Add(30)
	if out.Extent() != 3:
		return "Map() should share storage (Extent=3), got %d" % out.Extent()
	return "OK"


func test_bnd_box_get_limits() -> String:
	var p_min := OcgGpPnt.from_668(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_668(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_Wm7(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	var lim: Variant = box.Get_kuK()
	if not lim is PackedFloat64Array:
		return "Bnd_Box::Get() should return PackedFloat64Array, got %s" % lim
	var arr := lim as PackedFloat64Array
	if arr.size() != 6:
		return "Bnd_Box::Get() should have 6 elements, got %d" % arr.size()
	if arr[0] != 1.0 or arr[1] != 5.0 or arr[2] != 2.0 or arr[3] != 6.0 or arr[4] != 3.0 or arr[5] != 7.0:
		return "Bnd_Box::Get() wrong limits: %s" % arr
	return "OK"


func test_bnd_box2d_get_limits() -> String:
	var box := OcgBndBox2d.new()
	if box == null:
		return "Failed to create Bnd_Box2d"
	box.Update_rh2(1.0, 2.0, 5.0, 6.0)
	var lim: Variant = box.Get_kuK()
	if not lim is PackedFloat64Array:
		return "Bnd_Box2d::Get() should return PackedFloat64Array, got %s" % lim
	var arr := lim as PackedFloat64Array
	if arr.size() != 4:
		return "Bnd_Box2d::Get() should have 4 elements, got %d" % arr.size()
	if arr[0] != 1.0 or arr[1] != 5.0 or arr[2] != 2.0 or arr[3] != 6.0:
		return "Bnd_Box2d::Get() wrong limits: %s" % arr
	return "OK"
