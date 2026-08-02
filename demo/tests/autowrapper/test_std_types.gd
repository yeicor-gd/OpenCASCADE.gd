extends Node


func test_bnd_range_optional() -> String:
	var rng := OcgBndRange.new()
	if rng == null:
		return "Failed to create Bnd_Range"
	# A void range has no bounds: optional returns must be null.
	if rng.center() != null:
		return "Void range Center() should be null, got %s" % rng.center()
	if rng.min() != null or rng.max() != null:
		return "Void range Min/Max should be null"
	rng.add_j(10.0)
	rng.add_j(20.0)
	if rng.min() != 10.0:
		return "Min() expected 10.0 got %s" % rng.min()
	if rng.max() != 20.0:
		return "Max() expected 20.0 got %s" % rng.max()
	if rng.center() != 15.0:
		return "Center() expected 15.0 got %s" % rng.center()
	return "OK"


func test_bnd_box_optional_point() -> String:
	var p_min := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_6(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_W(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	var c: Variant = box.center()
	if c == null:
		return "Bnd_Box::Center() should not be null"
	var center := c as OcgGpPnt
	if center == null:
		return "Bnd_Box::Center() should wrap a gp_Pnt"
	if center.x() != 3.0 or center.y() != 4.0 or center.z() != 5.0:
		return "Center() wrong: %s,%s,%s" % [center.x(), center.y(), center.z()]
	box.set_void()
	if box.center() != null:
		return "Void Bnd_Box::Center() should be null"
	return "OK"


func test_graphic3d_text_string() -> String:
	var text := OcgGraphic3dText.from_r(0.01)
	if text == null:
		return "Failed to create Graphic3d_Text"
	text.set_text("Hello, OCC!")
	if text.text() != "Hello, OCC!":
		return "Text roundtrip failed: %s" % text.text()
	text.set_text("ÄÖÜ ❤ 日本語")
	if text.text() != "ÄÖÜ ❤ 日本語":
		return "Text UTF-8 roundtrip failed: %s" % text.text()
	return "OK"


func test_xscontrol_utils_utf16() -> String:
	var utils := OcgXSControlUtils.new()
	var s := utils.ascii_to_extended("Hello")
	if s != "Hello":
		return "AsciiToExtended failed: %s" % s
	var back := utils.to_e_string_B(s)
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
	if lst.extent() != 3:
		return "List Extent wrong: %s" % lst.extent()
	if lst.first() != OcgEnums.BRepCheck_Status.BRepCheck_No3DCurve:
		return "List First wrong after Prepend"
	if lst.last() != OcgEnums.BRepCheck_Status.BRepCheck_Invalid3DCurve:
		return "List Last wrong after Append"
	return "OK"


func test_list_byte_append() -> String:
	var lst := OcgNCollectionListUnsignedChar.new()
	if lst == null:
		return "Failed to create List<unsigned char>"
	lst.append_s(1)
	lst.append_s(200)
	lst.prepend_s(7)
	if lst.extent() != 3:
		return "List Extent wrong: %s" % lst.extent()
	if lst.first() != 7 or lst.last() != 200:
		return "List First/Last wrong"
	return "OK"


func test_splitter_pair_returns() -> String:
	var splitter := OcgBRepMeshDefaultRangeSplitter.new()
	if splitter == null:
		return "Failed to create BRepMesh_DefaultRangeSplitter"
	var ru: Variant = splitter.get_range_u()
	if not ru is PackedFloat64Array:
		return "GetRangeU should return PackedFloat64Array, got %s" % ru
	if (ru as PackedFloat64Array).size() != 2:
		return "GetRangeU should have 2 elements"
	return "OK"


func test_packed_map_of_integer() -> String:
	var pmap := OcgTColStdPackedMapOfInteger.new()
	if pmap == null:
		return "Failed to create TColStd_PackedMapOfInteger"
	if not pmap.is_empty():
		return "Fresh map should be empty"
	if pmap.add(42) != true:
		return "Add(42) should return true"
	if pmap.add(42) != false:
		return "Add(42) twice should return false"
	if pmap.add(-7) != true:
		return "Add(-7) should return true"
	if pmap.extent() != 2 or pmap.length() != 2:
		return "Extent/Length should be 2, got %d/%d" % [pmap.extent(), pmap.length()]
	if not pmap.contains(42) or not pmap.contains(-7) or pmap.contains(3):
		return "Contains checks wrong"
	if pmap.remove(42) != true:
		return "Remove(42) should return true"
	if pmap.remove(42) != false:
		return "Remove(42) twice should return false"
	if pmap.extent() != 1:
		return "Extent should be 1 after removal"
	pmap.clear()
	if not pmap.is_empty():
		return "Map should be empty after Clear"
	return "OK"


func test_hpacked_map_of_integer_map() -> String:
	var pmap := OcgTColStdPackedMapOfInteger.new()
	pmap.add(10)
	pmap.add(20)
	var hmap := OcgTColStdHPackedMapOfInteger.from__(pmap)
	if hmap == null:
		return "Failed to create TColStd_HPackedMapOfInteger"
	var out := hmap.map()
	if out == null:
		return "Map() should return a map"
	if out.extent() != 2 or not out.contains(20):
		return "Map() contents wrong: Extent=%d" % out.extent()
	out.add(30)
	if out.extent() != 3:
		return "Map() should share storage (Extent=3), got %d" % out.extent()
	return "OK"


func test_bnd_box_get_limits() -> String:
	var p_min := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var p_max := OcgGpPnt.from_6(5.0, 6.0, 7.0)
	var box := OcgBndBox.from_W(p_min, p_max)
	if box == null:
		return "Failed to create Bnd_Box"
	var lim: Variant = box.get_k()
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
	box.update_r(1.0, 2.0, 5.0, 6.0)
	var lim: Variant = box.get_k()
	if not lim is PackedFloat64Array:
		return "Bnd_Box2d::Get() should return PackedFloat64Array, got %s" % lim
	var arr := lim as PackedFloat64Array
	if arr.size() != 4:
		return "Bnd_Box2d::Get() should have 4 elements, got %d" % arr.size()
	if arr[0] != 1.0 or arr[1] != 5.0 or arr[2] != 2.0 or arr[3] != 6.0:
		return "Bnd_Box2d::Get() wrong limits: %s" % arr
	return "OK"
