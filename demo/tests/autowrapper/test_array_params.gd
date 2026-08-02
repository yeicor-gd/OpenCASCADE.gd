extends Node


func test_brepmesh_triangle_ctor() -> String:
	var edges := PackedInt32Array([0, 1, 2])
	var orientations := PackedByteArray([1, 0, 1])
	var tri := OcgBRepMeshTriangle.from_p(edges, orientations, OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Free)
	if tri == null:
		return "from_p failed"
	if tri.movability() != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Free:
		return "Movability expected Free got %s" % tri.movability()
	return "OK"


func test_brepmesh_triangle_initialize() -> String:
	var tri := OcgBRepMeshTriangle.new()
	var edges := PackedInt32Array([3, 4, 5])
	var orientations := PackedByteArray([0, 1, 1])
	tri.initialize(edges, orientations, OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed)
	if tri.movability() != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed:
		return "Movability expected Fixed got %s" % tri.movability()
	return "OK"


func test_poly_mergenodes_addtriangle() -> String:
	var tool := OcgPolyMergeNodesTool.from_N(30.0, 1e-6, 100)
	if tool == null:
		return "from_N failed"
	var p0 := OcgGpXYZ.from_6(0.0, 0.0, 0.0)
	var p1 := OcgGpXYZ.from_6(1.0, 0.0, 0.0)
	var p2 := OcgGpXYZ.from_6(0.0, 1.0, 0.0)
	var p3 := OcgGpXYZ.from_6(1.0, 1.0, 0.0)
	tool.add_triangle([p0, p1, p2])
	tool.add_quad([p0, p1, p3, p2])
	tool.push_last_quad()
	return "OK"


func test_enum_out_param_color_from_name() -> String:
	var out := OcgEnumValue.new()
	var ok := OcgQuantityColor.color_from_name_O("RED", out)
	if not ok:
		return "ColorFromName(RED) returned false"
	if out.get_value() != OcgEnums.Quantity_NameOfColor.Quantity_NOC_RED:
		return "ColorFromName(RED) expected %s got %s" % [OcgEnums.Quantity_NameOfColor.Quantity_NOC_RED, out.get_value()]
	return "OK"


func test_enum_out_param_material_from_name() -> String:
	var out := OcgEnumValue.new()
	var ok := OcgGraphic3dMaterialAspect.material_from_name_C("brass", out)
	if not ok:
		return "MaterialFromName(brass) returned false"
	if out.get_value() != OcgEnums.Graphic3d_NameOfMaterial.Graphic3d_NOM_BRASS:
		return "MaterialFromName(brass) expected %s got %s" % [OcgEnums.Graphic3d_NameOfMaterial.Graphic3d_NOM_BRASS, out.get_value()]
	return "OK"
