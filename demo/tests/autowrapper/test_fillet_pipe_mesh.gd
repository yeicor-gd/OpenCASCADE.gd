extends Node

const TOL := 1e-6


func _near(a: float, b: float) -> bool:
	return abs(a - b) < TOL


func _square_edges() -> Array:
	var a := OcgGpPnt.from_6(0.0, 0.0, 0.0)
	var b := OcgGpPnt.from_6(10.0, 0.0, 0.0)
	var c := OcgGpPnt.from_6(10.0, 10.0, 0.0)
	var d := OcgGpPnt.from_6(0.0, 10.0, 0.0)
	var e1 := OcgBRepBuilderAPIMakeEdge.from_Wm(a, b)
	var e2 := OcgBRepBuilderAPIMakeEdge.from_Wm(b, c)
	var e3 := OcgBRepBuilderAPIMakeEdge.from_Wm(c, d)
	var e4 := OcgBRepBuilderAPIMakeEdge.from_Wm(d, a)
	if e1 == null or e2 == null or e3 == null or e4 == null:
		return []
	return [e1.edge(), e2.edge(), e3.edge(), e4.edge()]


func _square_face() -> OcgTopoDSFace:
	var edges := _square_edges()
	if edges.is_empty():
		return null
	var wire := OcgBRepBuilderAPIMakeWire.from_gc(edges[0], edges[1], edges[2], edges[3])
	if wire == null:
		return null
	var face_mk := OcgBRepBuilderAPIMakeFace.from_y(wire.wire(), true)
	if face_mk == null or not face_mk.is_done():
		return null
	return face_mk.face()


func test_make_prism_solid() -> String:
	var face := _square_face()
	if face == null:
		return "Failed to build square face"
	var vec := OcgGpVec.from_6(0.0, 0.0, 15.0)
	var prism := OcgBRepPrimAPIMakePrism.from_i(face, vec, true, true)
	if prism == null:
		return "MakePrism from_i returned null"
	var first := prism.first_shape_g()
	if first == null or first.is_null():
		return "MakePrism first_shape returned null"
	if first.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_FACE:
		return "Prism first_shape expected TopAbs_FACE got %s" % first.shape_type()
	var last := prism.last_shape_g()
	if last == null or last.is_null():
		return "MakePrism last_shape returned null"
	if last.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_FACE:
		return "Prism last_shape expected TopAbs_FACE got %s" % last.shape_type()
	return "OK"


func test_box_edges_explorer() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0)
	var top := box.top_face()
	var outer := OcgBRepTools.outer_wire(top)
	if outer == null or outer.is_null():
		return "BRepTools outer_wire returned null"
	var we := OcgBRepToolsWireExplorer.from_j(outer, top)
	if we == null:
		return "WireExplorer from_j returned null"
	var edges := []
	while we.more():
		var e := we.current()
		if e == null or e.is_null():
			return "WireExplorer current() returned a null edge"
		if e.shape_type() != OcgEnums.TopAbs_ShapeEnum.TopAbs_EDGE:
			return "WireExplorer current() expected TopAbs_EDGE got %s" % e.shape_type()
		edges.append(e)
		we.next()
	if edges.size() != 4:
		return "Box top face should have 4 edges got %s" % edges.size()
	return "OK"


func test_make_fillet() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0)
	var solid := box.solid()
	var outer := OcgBRepTools.outer_wire(box.top_face())
	var we := OcgBRepToolsWireExplorer.from_j(outer, box.top_face())
	var e := we.current()
	if e == null:
		return "WireExplorer current() returned null"
	var fillet := OcgBRepFilletAPIMakeFillet.from_v(solid, OcgEnums.ChFi3d_FilletShape.ChFi3d_Rational)
	if fillet == null:
		return "MakeFillet from_v returned null"
	fillet.add_9(2.0, e)
	fillet.build(OcgMessageProgressRange.new())
	if fillet.nb_contours() != 1:
		return "Fillet nb_contours expected 1 got %s" % fillet.nb_contours()
	if fillet.nb_faulty_contours() != 0:
		return "Fillet should have no faulty contours"
	if fillet.nb_computed_surfaces(1) < 1:
		return "Fillet should have computed fillet surfaces"
	if fillet.stripe_status(1) != 0:
		return "Fillet stripe_status expected no error"
	if not _near(fillet.radius_2(1), 2.0):
		return "Fillet radius_2(1) expected 2 got %s" % fillet.radius_2(1)
	return "OK"


func test_make_chamfer() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0)
	var solid := box.solid()
	var outer := OcgBRepTools.outer_wire(box.top_face())
	var we := OcgBRepToolsWireExplorer.from_j(outer, box.top_face())
	var e := we.current()
	if e == null:
		return "WireExplorer current() returned null"
	var chamfer := OcgBRepFilletAPIMakeChamfer.from_4(solid)
	if chamfer == null:
		return "MakeChamfer from_4 returned null"
	chamfer.add_9(2.0, e)
	chamfer.build(OcgMessageProgressRange.new())
	if chamfer.nb_contours() != 1:
		return "Chamfer nb_contours expected 1 got %s" % chamfer.nb_contours()
	if not chamfer.is_symetric(1):
		return "Chamfer should be symmetric"
	var d := OcgStandardReal.new()
	chamfer.get_dist(1, d)
	if not _near(d.get_value(), 2.0):
		return "Chamfer get_dist expected 2 got %s" % d.get_value()
	return "OK"


func test_make_pipe() -> String:
	# Spine: line from (0,0,0) to (0,0,15).
	var spine_edge := OcgBRepBuilderAPIMakeEdge.from_Wm(OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpPnt.from_6(0.0, 0.0, 15.0))
	var spine_wire := OcgBRepBuilderAPIMakeWire.from_g(spine_edge.edge())
	# Profile: unit circle in the XY plane.
	var ax2 := OcgGpAx2.from_K(OcgGpDir.D.Z)
	var circ := OcgGpCirc.from_L(ax2, 1.0)
	var prof_edge := OcgBRepBuilderAPIMakeEdge.from_F(circ)
	var prof_wire := OcgBRepBuilderAPIMakeWire.from_g(prof_edge.edge())
	var prof_face := OcgBRepBuilderAPIMakeFace.from_y(prof_wire.wire(), true)
	var pipe := OcgBRepOffsetAPIMakePipe.from_H(spine_wire.wire(), prof_face.face())
	if pipe == null:
		return "MakePipe from_H returned null"
	pipe.build(OcgMessageProgressRange.new())
	var result := pipe.first_shape()
	if result == null or result.is_null():
		return "MakePipe first_shape returned null"
	if not _near(pipe.error_on_surface(), 0.0):
		return "Pipe error_on_surface expected 0 got %s" % pipe.error_on_surface()
	var analyzer := OcgBRepCheckAnalyzer.from_L(result, true, false, true)
	if not analyzer.is_valid_k():
		return "Pipe result should be a valid shape"
	return "OK"


func test_incremental_mesh() -> String:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0)
	var solid := box.solid()
	var mesh := OcgBRepMeshIncrementalMesh.from_z(solid, 0.1, false, 0.5, false)
	if mesh == null:
		return "IncrementalMesh from_z returned null"
	mesh.perform_W(OcgMessageProgressRange.new())
	if not OcgBRepTools.triangulation(solid, 0.2, false):
		return "Solid should have triangulation after meshing"
	var exp := OcgTopExpExplorer.from_4(solid, OcgEnums.TopAbs_ShapeEnum.TopAbs_FACE, OcgEnums.TopAbs_ShapeEnum.TopAbs_SHAPE)
	if exp == null:
		return "TopExp_Explorer from_4 returned null"
	var faces := 0
	while exp.more():
		var f := exp.value()
		if not OcgBRepTools.triangulation(f, 0.2, false):
			return "Face should have triangulation after meshing"
		faces += 1
		exp.next()
	if faces != 6:
		return "Box should have 6 faces got %s" % faces
	return "OK"
