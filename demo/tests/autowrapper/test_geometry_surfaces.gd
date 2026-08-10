extends Node

const TOL := 1e-6


func _near(a: float, b: float) -> bool:
	return abs(a - b) < TOL


func _circle() -> OcgGeomCircle:
	var ax2 := OcgGpAx2.from_K(OcgGpDir.D.Z)
	var circ := OcgGpCirc.from_L(ax2, 5.0)
	return OcgGeomCircle.from_F(circ)


func test_geom_circle_basics() -> String:
	var c := _circle()
	if c == null:
		return "Geom_Circle from_F returned null"
	if not _near(c.radius(), 5.0):
		return "Geom_Circle radius expected 5 got %s" % c.radius()
	if not c.is_closed():
		return "Circle should report closed"
	if not c.is_periodic():
		return "Circle should report periodic"
	if not _near(c.first_parameter(), 0.0) or not _near(c.last_parameter(), 2.0 * PI):
		return "Circle parameter range wrong: %s..%s" % [c.first_parameter(), c.last_parameter()]
	if c.continuity() != OcgEnums.GeomAbs_Shape.GeomAbs_CN:
		return "Circle continuity expected CN got %s" % c.continuity()
	var p0 := c.value(0.0)
	if not _near(p0.x(), 5.0) or not _near(p0.y(), 0.0) or not _near(p0.z(), 0.0):
		return "Circle value(0) expected (5,0,0) got (%s,%s,%s)" % [p0.x(), p0.y(), p0.z()]
	var p1 := c.value(PI / 2.0)
	if not _near(p1.x(), 0.0) or not _near(p1.y(), 5.0):
		return "Circle value(PI/2) expected (0,5,0) got (%s,%s,%s)" % [p1.x(), p1.y(), p1.z()]
	return "OK"


func test_geom_plane() -> String:
	var pnt := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var dir := OcgGpDir.from_6(0.0, 0.0, 1.0)
	var pl := OcgGeomPlane.from_n(pnt, dir)
	if pl == null:
		return "Geom_Plane from_n returned null"
	if pl.is_u_closed() or pl.is_v_closed():
		return "Infinite plane should not be closed in u or v"
	var v := pl.value(0.0, 0.0)
	if v == null or not _near(v.x(), 1.0) or not _near(v.y(), 2.0) or not _near(v.z(), 3.0):
		return "Plane value(0,0) expected (1,2,3) got (%s,%s,%s)" % [v.x(), v.y(), v.z()]
	var gp := pl.pln()
	if gp == null:
		return "Geom_Plane pln() returned null"
	var u1 := OcgStandardReal.new()
	var u2 := OcgStandardReal.new()
	var v1 := OcgStandardReal.new()
	var v2 := OcgStandardReal.new()
	pl.bounds(u1, u2, v1, v2)
	if not u1.get_value() <= u2.get_value() or not v1.get_value() <= v2.get_value():
		return "Plane bounds not ordered"
	var pl2 := OcgGeomPlane.from_r(0.0, 0.0, 1.0, -5.0)
	if pl2 == null:
		return "Geom_Plane from_r returned null"
	var w := pl2.value(1.0, 2.0)
	if not _near(w.z(), 5.0):
		return "Plane z=5 value(1,2) z expected 5 got %s" % w.z()
	return "OK"


func test_geom_adaptor_curve() -> String:
	var c := _circle()
	var ad := OcgGeomAdaptorCurve.from_5(c)
	if ad == null:
		return "GeomAdaptor_Curve from_5 returned null"
	if not _near(ad.first_parameter(), 0.0) or not _near(ad.last_parameter(), 2.0 * PI):
		return "Adaptor parameter range wrong"
	if ad.continuity() != OcgEnums.GeomAbs_Shape.GeomAbs_CN:
		return "Adaptor continuity expected CN got %s" % ad.continuity()
	var v := ad.value(PI)
	if not _near(v.x(), -5.0) or not _near(v.y(), 0.0):
		return "Adaptor value(PI) expected (-5,0,0) got (%s,%s,%s)" % [v.x(), v.y(), v.z()]
	var crv := ad.curve()
	if crv == null:
		return "Adaptor curve() returned null"
	var trimmed := OcgGeomAdaptorCurve.from_A(c, 0.0, PI / 2.0)
	if trimmed == null:
		return "GeomAdaptor_Curve from_A returned null"
	if not _near(trimmed.last_parameter(), PI / 2.0):
		return "Trimmed adaptor last parameter wrong"
	return "OK"


func test_gcpnts_abscissa() -> String:
	var ad := OcgGeomAdaptorCurve.from_5(_circle())
	if ad == null:
		return "Adaptor returned null"
	var total := OcgGCPntsAbscissaPoint.length_t(ad)
	if not _near(total, 10.0 * PI):
		return "Circle length expected 10*PI got %s" % total
	var quarter := OcgGCPntsAbscissaPoint.from_P(ad, total / 4.0, 0.0)
	if quarter == null:
		return "GCPnts_AbscissaPoint from_P returned null"
	var u := quarter.parameter()
	if not _near(u, PI / 2.0):
		return "Quarter-arc parameter expected PI/2 got %s" % u
	return "OK"


func test_geom_api_project_point() -> String:
	var proj := OcgGeomAPIProjectPointOnCurve.from_U(OcgGpPnt.from_6(0.0, 10.0, 0.0), _circle())
	if proj == null:
		return "ProjectPointOnCurve from_U returned null"
	if proj.nb_points() < 1:
		return "Expected at least one projected point"
	var np := proj.nearest_point()
	if not _near(np.x(), 0.0) or not _near(np.y(), 5.0) or not _near(np.z(), 0.0):
		return "Nearest point expected (0,5,0) got (%s,%s,%s)" % [np.x(), np.y(), np.z()]
	if not _near(proj.distance(1), 5.0):
		return "Projection distance expected 5 got %s" % proj.distance(1)
	if not _near(proj.lower_distance_parameter(), PI / 2.0):
		return "Lower distance parameter expected PI/2 got %s" % proj.lower_distance_parameter()
	return "OK"


func test_geom_bspline_constructor() -> String:
	var poles := OcgNCollectionArray1GpPnt.from_k(1, 4)
	poles.set_value_v(1, OcgGpPnt.from_6(0.0, 0.0, 0.0))
	poles.set_value_v(2, OcgGpPnt.from_6(1.0, 2.0, 0.0))
	poles.set_value_v(3, OcgGpPnt.from_6(2.0, 1.0, 0.0))
	poles.set_value_v(4, OcgGpPnt.from_6(3.0, 3.0, 0.0))
	var knots := OcgNCollectionArray1Double.from_k(1, 2)
	knots.set_value_N(1, 0.0)
	knots.set_value_N(2, 1.0)
	var mults := OcgNCollectionArray1Int.from_k(1, 2)
	mults.set_value_Z(1, 4)
	mults.set_value_Z(2, 4)
	var bs := OcgGeomBSplineCurve.from_2(poles, knots, mults, 3, false)
	if bs == null:
		return "Geom_BSplineCurve from_2 returned null"
	if bs.degree() != 3:
		return "BSpline degree expected 3 got %s" % bs.degree()
	if bs.nb_poles() != 4 or bs.nb_knots() != 2:
		return "BSpline pole/knot counts wrong"
	var s := bs.value(0.0)
	if not _near(s.x(), 0.0) or not _near(s.y(), 0.0):
		return "BSpline value(0) expected first pole got (%s,%s,%s)" % [s.x(), s.y(), s.z()]
	var e := bs.value(1.0)
	if not _near(e.x(), 3.0) or not _near(e.y(), 3.0):
		return "BSpline value(1) expected last pole got (%s,%s,%s)" % [e.x(), e.y(), e.z()]
	return "OK"


func test_geom_api_points_to_bspline() -> String:
	var pts := OcgNCollectionArray1GpPnt.from_k(1, 4)
	pts.set_value_v(1, OcgGpPnt.from_6(0.0, 0.0, 0.0))
	pts.set_value_v(2, OcgGpPnt.from_6(1.0, 1.0, 0.0))
	pts.set_value_v(3, OcgGpPnt.from_6(2.0, 0.0, 0.0))
	pts.set_value_v(4, OcgGpPnt.from_6(3.0, 1.0, 0.0))
	var app := OcgGeomAPIPointsToBSpline.from_F(pts, 2, 3, OcgEnums.GeomAbs_Shape.GeomAbs_C1, 1e-6)
	if app == null:
		return "PointsToBSpline from_F returned null"
	if not app.is_done():
		return "PointsToBSpline not done"
	var bs := app.curve()
	if bs == null:
		return "PointsToBSpline curve() returned null"
	var s := bs.value(0.0)
	if not _near(s.x(), 0.0) or not _near(s.y(), 0.0):
		return "Approx value(0) expected (0,0,0) got (%s,%s,%s)" % [s.x(), s.y(), s.z()]
	var e := bs.value(1.0)
	if not _near(e.x(), 3.0) or not _near(e.y(), 1.0):
		return "Approx value(1) expected (3,1,0) got (%s,%s,%s)" % [e.x(), e.y(), e.z()]
	return "OK"
