extends Node

# Tests for OCCT public struct fields being exposed as real Godot properties.


func test_polygon_offset_properties() -> String:
	var po := OcgGraphic3dPolygonOffset.new()
	if po == null:
		return "Failed to create Graphic3d_PolygonOffset"
	# Defaults from the OCCT struct: Mode=Aspect_POM_Fill, Factor=1.0, Units=1.0.
	if po.mode != OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Fill:
		return "PolygonOffset.Mode default wrong: %s" % po.mode
	if po.factor != 1.0 or po.units != 1.0:
		return "PolygonOffset.Factor/Units defaults wrong: %s/%s" % [po.factor, po.units]
	# Enum property roundtrip.
	po.mode = OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Line
	if po.mode != OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Line:
		return "PolygonOffset.Mode roundtrip failed: %s" % po.mode
	# Float properties.
	po.factor = 2.5
	po.units = 3.0
	if po.factor != 2.5:
		return "PolygonOffset.Factor roundtrip failed: %s" % po.factor
	if po.units != 3.0:
		return "PolygonOffset.Units roundtrip failed: %s" % po.units
	return "OK"


func test_brepmesh_triangle_enum_property() -> String:
	var tri := OcgBRepMeshTriangle.new()
	if tri == null:
		return "Failed to create BRepMesh_Triangle"
	if tri.my_movability != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Free:
		return "Triangle.myMovability default wrong: %s" % tri.my_movability
	tri.my_movability = OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed
	if tri.my_movability != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed:
		return "Triangle.myMovability roundtrip failed: %s" % tri.my_movability
	return "OK"


func test_scroll_delta_object_property() -> String:
	var sd := OcgAspectScrollDelta.new()
	if sd == null:
		return "Failed to create Aspect_ScrollDelta"
	# 'Point' is an OBJECT-typed property wrapping NCollection_Vec2<int>.
	# OCCT default is an unset position (-1, -1).
	var p: Variant = sd.point
	if not p is OcgNCollectionVec2Int:
		return "ScrollDelta.Point should be an OcgNCollectionVec2Int, got %s" % p
	if p.x_k() != -1 or p.y_k() != -1:
		return "ScrollDelta.Point default should be (-1,-1), got (%s,%s)" % [p.x_k(), p.y_k()]
	# Roundtrip: set a new vector and read it back.
	var q := OcgNCollectionVec2Int.new()
	sd.point = q
	var p3: Variant = sd.point
	if p3.x_k() != q.x_k() or p3.y_k() != q.y_k():
		return "ScrollDelta.Point roundtrip failed"
	# Numeric properties on the same struct.
	sd.delta = 1.5
	sd.flags = 7
	if sd.delta != 1.5:
		return "ScrollDelta.Delta roundtrip failed: %s" % sd.delta
	if sd.flags != 7:
		return "ScrollDelta.Flags roundtrip failed: %s" % sd.flags
	return "OK"


func test_property_list_contains_fields() -> String:
	var po := OcgGraphic3dPolygonOffset.new()
	var found := {}
	for prop in po.get_property_list():
		found[prop.name] = true
	if not found.has("mode") or not found.has("factor") or not found.has("units"):
		return "PolygonOffset property list should contain mode/factor/units"
	return "OK"
