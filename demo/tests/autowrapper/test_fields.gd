extends Node

# Tests for OCCT public struct fields being exposed as real Godot properties.


func test_polygon_offset_properties() -> String:
	var po := OcgGraphic3dPolygonOffset.new()
	if po == null:
		return "Failed to create Graphic3d_PolygonOffset"
	# Defaults from the OCCT struct: Mode=Aspect_POM_Fill, Factor=1.0, Units=1.0.
	if po.Mode != OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Fill:
		return "PolygonOffset.Mode default wrong: %s" % po.Mode
	if po.Factor != 1.0 or po.Units != 1.0:
		return "PolygonOffset.Factor/Units defaults wrong: %s/%s" % [po.Factor, po.Units]
	# Enum property roundtrip.
	po.Mode = OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Line
	if po.Mode != OcgEnums.Aspect_PolygonOffsetMode.Aspect_POM_Line:
		return "PolygonOffset.Mode roundtrip failed: %s" % po.Mode
	# Float properties.
	po.Factor = 2.5
	po.Units = 3.0
	if po.Factor != 2.5:
		return "PolygonOffset.Factor roundtrip failed: %s" % po.Factor
	if po.Units != 3.0:
		return "PolygonOffset.Units roundtrip failed: %s" % po.Units
	return "OK"


func test_brepmesh_triangle_enum_property() -> String:
	var tri := OcgBRepMeshTriangle.new()
	if tri == null:
		return "Failed to create BRepMesh_Triangle"
	if tri.myMovability != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Free:
		return "Triangle.myMovability default wrong: %s" % tri.myMovability
	tri.myMovability = OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed
	if tri.myMovability != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed:
		return "Triangle.myMovability roundtrip failed: %s" % tri.myMovability
	return "OK"


func test_scroll_delta_object_property() -> String:
	var sd := OcgAspectScrollDelta.new()
	if sd == null:
		return "Failed to create Aspect_ScrollDelta"
	# 'Point' is an OBJECT-typed property wrapping NCollection_Vec2<int>.
	# OCCT default is an unset position (-1, -1).
	var p: Variant = sd.Point
	if not p is OcgNCollectionVec2Int:
		return "ScrollDelta.Point should be an OcgNCollectionVec2Int, got %s" % p
	if p.x() != -1 or p.y() != -1:
		return "ScrollDelta.Point default should be (-1,-1), got (%s,%s)" % [p.x(), p.y()]
	# Roundtrip: set a new vector and read it back.
	var q := OcgNCollectionVec2Int.new()
	sd.Point = q
	var p3: Variant = sd.Point
	if p3.x() != q.x() or p3.y() != q.y():
		return "ScrollDelta.Point roundtrip failed"
	# Numeric properties on the same struct.
	sd.Delta = 1.5
	sd.Flags = 7
	if sd.Delta != 1.5:
		return "ScrollDelta.Delta roundtrip failed: %s" % sd.Delta
	if sd.Flags != 7:
		return "ScrollDelta.Flags roundtrip failed: %s" % sd.Flags
	return "OK"


func test_property_list_contains_fields() -> String:
	var po := OcgGraphic3dPolygonOffset.new()
	var found := {}
	for prop in po.get_property_list():
		found[prop.name] = true
	if not found.has("Mode") or not found.has("Factor") or not found.has("Units"):
		return "PolygonOffset property list should contain Mode/Factor/Units"
	return "OK"
