extends Node


func test_brepmesh_triangle_default() -> String:
	var tri := OcgBRepMeshTriangle.new()
	if tri == null:
		return "Failed to create BRepMesh_Triangle"
	if tri.movability() != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Free:
		return "Movability expected Free got %s" % tri.movability()
	tri.set_movability(OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed)
	if tri.movability() != OcgEnums.BRepMesh_DegreeOfFreedom.BRepMesh_Fixed:
		return "Movability expected Fixed got %s" % tri.movability()
	return "OK"


func test_brepmesh_triangle_equal() -> String:
	var a := OcgBRepMeshTriangle.new()
	var b := OcgBRepMeshTriangle.new()
	if not a.is_equal(b):
		return "Two fresh BRepMesh_Triangle should be equal"
	return "OK"


func test_poly_mergenodes_addtriangulation() -> String:
	var tool := OcgPolyMergeNodesTool.from_N(30.0, 1e-6, 100)
	if tool == null:
		return "from_N failed"
	var tris := OcgPolyTriangulation.from_L(4, 2, false, false)
	if tris == null:
		return "Failed to create Poly_Triangulation"
	tris.set_node(1, OcgGpPnt.from_6(0.0, 0.0, 0.0))
	tris.set_node(2, OcgGpPnt.from_6(1.0, 0.0, 0.0))
	tris.set_node(3, OcgGpPnt.from_6(0.0, 1.0, 0.0))
	tris.set_node(4, OcgGpPnt.from_6(1.0, 1.0, 0.0))
	tris.set_triangle(1, OcgPolyTriangle.from_X(1, 2, 3))
	tris.set_triangle(2, OcgPolyTriangle.from_X(2, 4, 3))
	tool.add_triangulation(tris, OcgGpTrsf.new(), false)
	tool.push_last_triangle()
	if tool.nb_nodes() != 4:
		return "NbNodes expected 4 got %s" % tool.nb_nodes()
	if tool.nb_elements() < 1:
		return "NbElements expected >= 1 got %s" % tool.nb_elements()
	return "OK"


func test_color_from_name() -> String:
	var out := OcgQuantityColor.new()
	if out == null:
		return "Failed to create Quantity_Color"
	if not OcgQuantityColor.color_from_name_D("RED", out):
		return "ColorFromName(RED) returned false"
	if absf(out.red() - 1.0) > 1e-3 or absf(out.green()) > 1e-3 or absf(out.blue()) > 1e-3:
		return "ColorFromName(RED) expected (1,0,0) got (%s,%s,%s)" % [out.red(), out.green(), out.blue()]
	return "OK"


func test_material_from_name() -> String:
	var m := OcgGraphic3dMaterialAspect.material_from_name_f("brass")
	if m != OcgEnums.Graphic3d_NameOfMaterial.Graphic3d_NOM_BRASS:
		return "MaterialFromName(brass) expected %s got %s" % [OcgEnums.Graphic3d_NameOfMaterial.Graphic3d_NOM_BRASS, m]
	return "OK"
