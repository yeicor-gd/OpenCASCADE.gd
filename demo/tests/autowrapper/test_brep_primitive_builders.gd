extends Node

const TOL := 1e-6


func _near(a: float, b: float) -> bool:
	return abs(a - b) < TOL


func test_make_box() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 20.0, 30.0)
	if box == null:
		return "MakeBox from_6 returned null"
	var solid := box.solid()
	if solid == null or solid.is_null():
		return "MakeBox solid() returned a null shape"
	if solid.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_SOLID:
		return "Expected TopAbs_SOLID got %s" % solid.shape_type()
	if box.shell() == null or box.shell().is_null():
		return "MakeBox shell() returned a null shape"
	if box.top_face() == null or box.bottom_face() == null:
		return "MakeBox face accessors returned null"
	if box.front_face() == null or box.back_face() == null:
		return "MakeBox face accessors returned null"
	if box.left_face() == null or box.right_face() == null:
		return "MakeBox face accessors returned null"
	var props := OcgGPropGProps.from_N(OcgGpPnt.from_6(0.0, 0.0, 0.0))
	OcgBRepGProp.volume_properties_J(solid, props, true, false, false)
	if not _near(props.mass(), 6000.0):
		return "Box volume expected 6000 got %s" % props.mass()
	var com := props.centre_of_mass()
	if com == null or not _near(com.x(), 5.0) or not _near(com.y(), 10.0) or not _near(com.z(), 15.0):
		return "Box centre of mass expected (5,10,15) got (%s,%s,%s)" % [com.x(), com.y(), com.z()]
	return "OK"


func test_make_vertex() -> String:
	var mk := OcgBRepBuilderAPIMakeVertex.from_N(OcgGpPnt.from_6(1.0, 2.0, 3.0))
	if mk == null:
		return "MakeVertex from_N returned null"
	var v := mk.vertex()
	if v == null or v.is_null():
		return "MakeVertex vertex() returned a null shape"
	if v.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_VERTEX:
		return "Expected TopAbs_VERTEX got %s" % v.shape_type()
	return "OK"


func test_make_polygon_closed() -> String:
	var p1 := OcgGpPnt.from_6(0.0, 0.0, 0.0)
	var p2 := OcgGpPnt.from_6(10.0, 0.0, 0.0)
	var p3 := OcgGpPnt.from_6(10.0, 10.0, 0.0)
	var p4 := OcgGpPnt.from_6(0.0, 10.0, 0.0)
	var poly := OcgBRepBuilderAPIMakePolygon.from_y(p1, p2, p3, p4, true)
	if poly == null:
		return "MakePolygon from_y returned null"
	if not poly.is_done():
		return "Closed polygon not done"
	var w := poly.wire()
	if w == null or w.is_null():
		return "MakePolygon wire() returned null"
	if w.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_WIRE:
		return "Expected TopAbs_WIRE got %s" % w.shape_type()
	if poly.first_vertex() == null or poly.last_vertex() == null:
		return "MakePolygon vertex accessors returned null"
	var e := poly.edge()
	if e == null or e.is_null():
		return "MakePolygon edge() returned null"
	return "OK"


func test_make_polygon_add_close() -> String:
	var poly := OcgBRepBuilderAPIMakePolygon.from_W(OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpPnt.from_6(5.0, 0.0, 0.0))
	if poly == null:
		return "MakePolygon from_W returned null"
	if not poly.added():
		return "A segment should have been added by the 2-point constructor"
	poly.add_N(OcgGpPnt.from_6(5.0, 5.0, 0.0))
	poly.close()
	var w := poly.wire()
	if w == null or w.is_null():
		return "Triangle wire returned null"
	if not w.closed_k():
		return "Closed polygon wire should report closed"
	return "OK"


func test_transform() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(4.0, 4.0, 4.0)
	var solid := box.solid()
	var trsf := OcgGpTrsf.new()
	trsf.set_translation_Z(OcgGpVec.from_6(100.0, 0.0, 0.0))
	var tf := OcgBRepBuilderAPITransform.from_l(solid, trsf, true, true)
	if tf == null:
		return "MakeTransform from_l returned null"
	var out := tf.modified_shape(solid)
	if out == null or out.is_null():
		return "ModifiedShape returned a null shape"
	if out.is_equal(solid):
		return "Transformed shape should differ from the original"
	var props := OcgGPropGProps.from_N(OcgGpPnt.from_6(0.0, 0.0, 0.0))
	OcgBRepGProp.volume_properties_J(out, props, true, false, false)
	if not _near(props.mass(), 64.0):
		return "Transformed box volume expected 64 got %s" % props.mass()
	var com := props.centre_of_mass()
	if not _near(com.x(), 102.0) or not _near(com.y(), 2.0) or not _near(com.z(), 2.0):
		return "Transformed box centre of mass expected (102,2,2) got (%s,%s,%s)" % [com.x(), com.y(), com.z()]
	return "OK"


func test_brep_check_analyzer() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(4.0, 4.0, 4.0)
	var solid := box.solid()
	var analyzer := OcgBRepCheckAnalyzer.from_L(solid, true, false, true)
	if analyzer == null:
		return "BRepCheck_Analyzer from_L returned null"
	if not analyzer.is_valid_k():
		return "Box solid should be valid"
	if not analyzer.is_valid_i(solid):
		return "Box solid should be valid (explicit shape)"
	return "OK"
