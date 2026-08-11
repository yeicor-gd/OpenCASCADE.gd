extends Node


func test_property_getter_setter_pairs() -> String:
	# Getter/setter method pairs (x()/set_x()) are exposed as a read-write Godot
	# property `x`; the underlying methods stay callable too.
	var pnt := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	if pnt == null:
		return "Failed to create gp_Pnt"
	if pnt.x != 1.0:
		return "Property x expected 1.0 got %s" % pnt.x
	if pnt.y != 2.0 or pnt.z != 3.0:
		return "Property y/z wrong"
	pnt.x = 7.5
	if pnt.x() != 7.5:
		return "set_x via property failed, x()=%s" % pnt.x()
	if pnt.xyz == null:
		return "Property xyz should yield a Ref"
	var other := OcgGpXYZ.from_6(9.0, 8.0, 7.0)
	pnt.xyz = other
	if pnt.xyz().x() != 9.0:
		return "set_xyz via property failed"
	return "OK"


func test_readonly_properties() -> String:
	var st := OcgMessageExecStatus.from_s(OcgEnums.Message_Status.Message_Done1)
	if st == null:
		return "Failed to create Message_ExecStatus"
	if not st.is_done:
		return "Read-only property is_done should be true"
	var box := OcgBndBox.from_W(
		OcgGpPnt.from_6(0.0, 0.0, 0.0),
		OcgGpPnt.from_6(2.0, 3.0, 4.0))
	if box == null:
		return "Failed to create Bnd_Box"
	if box.get_gap != 0.0:
		return "Property get_gap expected 0 got %s" % box.get_gap
	if abs(box.get_x_min - 0.0) > 1e-6 or abs(box.get_x_max - 2.0) > 1e-6:
		return "Read-only get_x_min/get_x_max properties wrong"
	box.get_gap = 0.5
	if box.get_gap() != 0.5:
		return "Property get_gap setter failed: %s" % box.get_gap()
	if box.is_void:
		return "Property is_void should be false for a filled box"
	return "OK"


func test_make_box_solid() -> String:
	var mk := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0)
	if mk == null:
		return "Failed to create BRepPrimAPI_MakeBox"
	var solid: OcgTopoDSShape = mk.solid()
	if solid == null or solid.is_null():
		return "MakeBox.solid() returned a null shape"
	return "OK"


func test_make_edge_wire() -> String:
	var e := OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(0.0, 0.0, 0.0),
		OcgGpPnt.from_6(10.0, 0.0, 0.0))
	if e == null:
		return "Failed to create BRepBuilderAPI_MakeEdge"
	if not e.is_done():
		return "MakeEdge is_done() false"
	if e.error() != 0:
		return "MakeEdge error() expected 0 got %s" % e.error()
	if e.edge() == null or e.edge().is_null():
		return "MakeEdge.edge() returned a null shape"
	return "OK"


func _square_wire() -> OcgTopoDSShape:
	var e1: OcgTopoDSShape = OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpPnt.from_6(10.0, 0.0, 0.0)).edge()
	var e2: OcgTopoDSShape = OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(10.0, 0.0, 0.0), OcgGpPnt.from_6(10.0, 10.0, 0.0)).edge()
	var e3: OcgTopoDSShape = OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(10.0, 10.0, 0.0), OcgGpPnt.from_6(0.0, 10.0, 0.0)).edge()
	var e4: OcgTopoDSShape = OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(0.0, 10.0, 0.0), OcgGpPnt.from_6(0.0, 0.0, 0.0)).edge()
	var w := OcgBRepBuilderAPIMakeWire.from_gc(e1, e2, e3, e4)
	if w == null or not w.is_done():
		return null
	return w.wire()


func test_make_wire_face() -> String:
	var wire := _square_wire()
	if wire == null or wire.is_null():
		return "Failed to build closed square wire"
	var pln := OcgGpPln.from_r(0.0, 0.0, 1.0, 0.0)
	var f := OcgBRepBuilderAPIMakeFace.from_v(pln, wire, true)
	if f == null:
		return "Failed to create BRepBuilderAPI_MakeFace"
	if not f.is_done():
		return "MakeFace is_done() false"
	if f.face() == null or f.face().is_null():
		return "MakeFace.face() returned a null shape"
	return "OK"


func test_top_exp_explorer_faces() -> String:
	var solid := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0).solid()
	var exp := OcgTopExpExplorer.from_4(
		solid,
		OcgEnums.TopAbs_ShapeEnum.TopAbs_FACE,
		OcgEnums.TopAbs_ShapeEnum.TopAbs_SHAPE)
	if exp == null:
		return "Failed to create TopExp_Explorer"
	var count := 0
	while exp.more():
		if exp.current() == null or exp.current().is_null():
			return "Explorer returned a null face"
		count += 1
		exp.next()
	if count != 6:
		return "Box face count expected 6 got %d" % count
	return "OK"


func test_extrema_dist_shape_shape() -> String:
	var b1 := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0).solid()
	var b2 := OcgBRepPrimAPIMakeBox.from_X(
		OcgGpPnt.from_6(100.0, 0.0, 0.0), 10.0, 10.0, 10.0).solid()
	var ext := OcgBRepExtremaDistShapeShape.from_q(
		b1, b2,
		OcgEnums.Extrema_ExtFlag.Extrema_ExtFlag_MINMAX,
		OcgEnums.Extrema_ExtAlgo.Extrema_ExtAlgo_Grad,
		OcgMessageProgressRange.new())
	if ext == null:
		return "Failed to create BRepExtrema_DistShapeShape"
	if not ext.is_done():
		return "DistShapeShape is_done() false"
	if abs(ext.value() - 90.0) > 1e-6:
		return "Distance expected 90 got %s" % ext.value()
	if ext.nb_solution() < 1:
		return "Expected at least one extremum solution"
	return "OK"


func test_brep_bnd_lib() -> String:
	var solid := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0).solid()
	var box := OcgBndBox.new()
	OcgBRepBndLib.add(solid, box, true)
	if box.is_void():
		return "Bnd_Box should not be void after BndLib::Add"
	if abs(box.get_x_min - 0.0) > 1e-6 or abs(box.get_x_max - 10.0) > 1e-6:
		return "Bnd_Box X limits wrong: %s..%s" % [box.get_x_min, box.get_x_max]
	return "OK"


func test_brep_gprop_volume() -> String:
	var solid := OcgBRepPrimAPIMakeBox.from_6(2.0, 3.0, 4.0).solid()
	var props := OcgGPropGProps.from_N(OcgGpPnt.new())
	OcgBRepGProp.volume_properties_J(solid, props, true, false, false)
	if abs(props.mass - 24.0) > 1e-6:
		return "Box volume expected 24 got %s" % props.mass
	var cm := props.centre_of_mass
	if cm == null:
		return "centre_of_mass property should yield a Ref"
	if abs(cm.x - 1.0) > 1e-6 or abs(cm.y - 1.5) > 1e-6 or abs(cm.z - 2.0) > 1e-6:
		return "centre_of_mass wrong: %s, %s, %s" % [cm.x, cm.y, cm.z]
	return "OK"


func _shape_volume(shape: OcgTopoDSShape) -> float:
	var props := OcgGPropGProps.from_N(OcgGpPnt.new())
	OcgBRepGProp.volume_properties_J(shape, props, true, false, false)
	return props.mass


func test_boolean_operations() -> String:
	# BRepAlgoAPI_* constructors accept an optional Message_ProgressRange; the
	# default-constructed range is an inert no-op scope.
	var b1 := OcgBRepPrimAPIMakeBox.from_6(10.0, 10.0, 10.0).solid()
	var b2 := OcgBRepPrimAPIMakeBox.from_X(
		OcgGpPnt.from_6(5.0, 0.0, 0.0), 10.0, 10.0, 10.0).solid()
	var rng := OcgMessageProgressRange.new()
	if rng == null:
		return "Failed to create Message_ProgressRange"
	var fuse := OcgBRepAlgoAPIFuse.from_b(b1, b2, rng)
	if fuse == null:
		return "Failed to create BRepAlgoAPI_Fuse"
	if not fuse.is_done():
		return "Fuse is_done() false"
	var fuse_shape: OcgTopoDSShape = fuse.shape()
	if fuse_shape == null or fuse_shape.is_null():
		return "Fuse.shape() returned a null shape"
	if not is_equal_approx(_shape_volume(fuse_shape), 1500.0):
		return "Fuse volume expected 1500 got %s" % _shape_volume(fuse_shape)
	var cut := OcgBRepAlgoAPICut.from_b(b1, b2, rng)
	if cut == null:
		return "Failed to create BRepAlgoAPI_Cut"
	var cut_shape: OcgTopoDSShape = cut.shape()
	if cut_shape == null or cut_shape.is_null():
		return "Cut.shape() returned a null shape"
	if not is_equal_approx(_shape_volume(cut_shape), 500.0):
		return "Cut volume expected 500 got %s" % _shape_volume(cut_shape)
	var common := OcgBRepAlgoAPICommon.from_b(b1, b2, rng)
	if common == null:
		return "Failed to create BRepAlgoAPI_Common"
	var common_shape: OcgTopoDSShape = common.shape()
	if common_shape == null or common_shape.is_null():
		return "Common.shape() returned a null shape"
	if not is_equal_approx(_shape_volume(common_shape), 500.0):
		return "Common volume expected 500 got %s" % _shape_volume(common_shape)
	# Section exposes plain-shape overloads that need no progress range.
	var sec := OcgBRepAlgoAPISection.from_s(b1, b2, true)
	if sec == null:
		return "Failed to create BRepAlgoAPI_Section"
	if not sec.is_done():
		return "Section is_done() false"
	var sec_shape: OcgTopoDSShape = sec.shape()
	if sec_shape == null or sec_shape.is_null():
		return "Section.shape() returned a null shape"
	if not OcgBRepCheckAnalyzer.from_L(sec_shape, true, false, true).is_valid_k():
		return "Section shape should be valid"
	return "OK"


func test_transform_shape() -> String:
	# BRepBuilderAPI_Transform inherits Shape() (flattened): the result of the
	# transform is available directly, not just via modified_shape(S).
	var mk := OcgBRepPrimAPIMakeBox.from_6(1.0, 2.0, 3.0)
	var trsf := OcgGpTrsf.new()
	trsf.set_translation_Z(OcgGpVec.from_6(10.0, 0.0, 0.0))
	var t := OcgBRepBuilderAPITransform.from_l(mk.solid(), trsf, true, false)
	if t == null:
		return "Failed to create BRepBuilderAPI_Transform"
	if not t.is_done():
		return "Transform is_done() false"
	var moved: OcgTopoDSShape = t.shape()
	if moved == null or moved.is_null():
		return "Transform.shape() returned a null shape"
	if not is_equal_approx(_shape_volume(moved), 6.0):
		return "Transform volume expected 6 got %s" % _shape_volume(moved)
	var cm := OcgGPropGProps.from_N(OcgGpPnt.new())
	OcgBRepGProp.volume_properties_J(moved, cm, true, false, false)
	if abs(cm.centre_of_mass.x - 10.5) > 1e-6:
		return "Transform centre_of_mass.x expected 10.5 got %s" % cm.centre_of_mass.x
	return "OK"


func test_adaptor_curve_inherited() -> String:
	# BRepAdaptor_Curve derives through GeomAdaptor_TransformedCurve ->
	# Adaptor3d_Curve; Value/D1/FirstParameter/LastParameter are inherited
	# through the Transient wrapper chain (bound on OcgAdaptor3dCurve).
	var e := OcgBRepBuilderAPIMakeEdge.from_Wm(
		OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpPnt.from_6(10.0, 0.0, 0.0)).edge()
	var ac := OcgBRepAdaptorCurve.from_g(e)
	if ac == null:
		return "Failed to create BRepAdaptor_Curve"
	if not is_equal_approx(ac.first_parameter(), 0.0):
		return "first_parameter expected 0 got %s" % ac.first_parameter()
	if not is_equal_approx(ac.last_parameter(), 10.0):
		return "last_parameter expected 10 got %s" % ac.last_parameter()
	var p: OcgGpPnt = ac.value(5.0)
	if p == null:
		return "value() returned null"
	if not is_equal_approx(p.x, 5.0) or not is_equal_approx(p.y, 0.0):
		return "value(5) expected (5,0,0) got %s" % p
	var p2 := OcgGpPnt.new()
	var v := OcgGpVec.new()
	ac.d1(5.0, p2, v)
	if not is_equal_approx(v.x, 1.0):
		return "d1 tangent x expected 1 got %s" % v.x
	return "OK"


func test_brep_graph_node_id() -> String:
	var n := OcgBRepGraphNodeId.from_s(OcgBRepGraphNodeId.Kind.Vertex, 5)
	if n == null:
		return "Failed to create BRepGraph_NodeId"
	if n.node_kind != OcgBRepGraphNodeId.Kind.Vertex:
		return "node_kind field property wrong"
	if n.index != 5:
		return "index field property wrong"
	n.index = 9
	if n.index != 9:
		return "index field property setter failed"
	var pre := n.increment_g()
	if pre == null or pre.index != 10 or n.index != 10:
		return "prefix increment wrong: pre=%s n=%s" % [pre.index, n.index]
	var post := n.increment_2(0)
	if post == null or post.index != 10 or n.index != 11:
		return "postfix increment wrong: post=%s n=%s" % [post.index, n.index]
	if not OcgBRepGraphNodeId.is_topology_kind(OcgBRepGraphNodeId.Kind.Face):
		return "is_topology_kind(Face) should be true"
	if not OcgBRepGraphNodeId.is_assembly_kind(OcgBRepGraphNodeId.Kind.Product):
		return "is_assembly_kind(Product) should be true"
	return "OK"


func test_message_exec_status() -> String:
	var st := OcgMessageExecStatus.from_s(OcgEnums.Message_Status.Message_Done1)
	if st == null:
		return "Failed to create Message_ExecStatus"
	if not st.is_set(OcgEnums.Message_Status.Message_Done1):
		return "is_set(Done1) false after construction"
	if st.is_set(OcgEnums.Message_Status.Message_Warn1):
		return "is_set(Warn1) should be false"
	var warn := OcgMessageExecStatus.from_s(OcgEnums.Message_Status.Message_Warn1)
	warn.set(OcgEnums.Message_Status.Message_Fail1)
	if not warn.is_fail():
		return "is_fail() false after set(Fail1)"
	var res := st.or_assign(warn)
	if res == null:
		return "or_assign should return a Ref"
	if not st.is_done() or not st.is_fail():
		return "or_assign did not union statuses"
	var both := OcgMessageExecStatus.from_s(OcgEnums.Message_Status.Message_Done1)
	both.set(OcgEnums.Message_Status.Message_Warn1)
	both.and_assign(warn)
	if not both.is_set(OcgEnums.Message_Status.Message_Warn1):
		return "and_assign should keep Warn1"
	if both.is_set(OcgEnums.Message_Status.Message_Done1):
		return "and_assign should drop Done1"
	return "OK"
