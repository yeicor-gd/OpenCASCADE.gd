extends Node

const NU := 8
const NV := 4

var _rss_now := 0

func _rss_kb() -> int:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("VmRSS:"):
			return int(line.get_slice(":", 1).strip_edges().get_slice(" ", 0))
	return -1

func _mark(tag: String) -> void:
	var rss := _rss_kb()
	var delta := rss - _rss_now
	_rss_now = rss
	TestRunner.ctx.log_info("%-42s RSS=%d kB  (d=%+d kB)" % [tag, rss, delta])

func _make_points(offset: float) -> OcgNCollectionArray2GpPnt:
	var pts := OcgNCollectionArray2GpPnt.from_v(1, NU, 1, NV)
	for v in NV:
		var y := (float(v) / float(NV - 1) - 0.5)
		for u in NU:
			var x := float(u) / float(NU - 1) * 2.0
			var z := 0.4 * sin(TAU * x - offset) * (1.0 - x * 0.1)
			pts.set_value(u + 1, v + 1, OcgGpPnt.from_6(x, y, z))
	return pts

func _make_surface(offset: float) -> OcgGeomBSplineSurface:
	var pts := _make_points(offset)
	var f := OcgGeomAPIPointsToBSplineSurface.new()
	OcgErrors.clear_last_error()
	f.init_g(pts, 8, 8, OcgEnums.GeomAbs_Shape.GeomAbs_G2, 1e-5)
	if OcgErrors.get_last_error_message() != "":
		return null
	var surface := f.surface()
	if surface == null or OcgErrors.get_last_error_message() != "":
		return null
	return surface

func _make_face(surface: OcgGeomBSplineSurface) -> OcgTopoDSFace:
	var gen := OcgBRepBuilderAPIMakeFace.new()
	OcgErrors.clear_last_error()
	gen.init_W(surface, true, 1e-6)
	OcgErrors.clear_last_error()
	return gen.face()

func _mesh(face: OcgTopoDSFace) -> OcgBRepMeshIncrementalMesh:
	OcgErrors.clear_last_error()
	var m := OcgBRepMeshIncrementalMesh.from_z(face, 0.01, false, 0.5, false)
	if OcgErrors.get_last_error_message() != "":
		TestRunner.ctx.log_error("from_z error: %s" % OcgErrors.get_last_error_message())
	return m

func _mesh_size(m) -> String:
	if m == null:
		return "null"
	var tri := OcgBRepTool.triangulation(m.shape(), OcgTopLocLocation.new(), 0)
	if tri == null:
		return "no tri"
	return "%d nodes / %d tris" % [tri.nb_nodes(), tri.nb_triangles()]

func test_baseline_fresh_bspline_face() -> String:
	_rss_now = _rss_kb()
	_mark("start")
	for i in 100:
		var s := _make_surface(float(i) * 0.017)
		if s == null:
			return "surface failed at %d" % i
		var face := _make_face(s)
		if face == null:
			return "face failed at %d" % i
		if i == 0 or i == 99:
			_mark("face built iter %d" % i)
	return "OK"

func test_fresh_face_mesh() -> String:
	_rss_now = _rss_kb()
	_mark("start")
	for i in 100:
		var s := _make_surface(float(i) * 0.017)
		if s == null:
			return "surface failed at %d" % i
		var face := _make_face(s)
		if face == null:
			return "face failed at %d" % i
		var m := _mesh(face)
		if i == 0:
			TestRunner.ctx.log_info("mesh[0] = %s" % _mesh_size(m))
		if i == 25 or i == 50 or i == 75 or i == 99:
			_mark("mesh iter %d" % i)
	return "OK"

func test_reuse_face_mesh() -> String:
	var s := _make_surface(0.0)
	if s == null:
		return "surface failed"
	var face := _make_face(s)
	if face == null:
		return "face failed"
	_rss_now = _rss_kb()
	_mark("start (reused face)")
	for i in 100:
		var m := _mesh(face)
		if i == 0:
			TestRunner.ctx.log_info("mesh[0] = %s" % _mesh_size(m))
		if i == 25 or i == 50 or i == 75 or i == 99:
			_mark("reuse mesh iter %d" % i)
	return "OK"

func test_plane_face_mesh() -> String:
	_rss_now = _rss_kb()
	_mark("start (plane)")
	for i in 100:
		OcgErrors.clear_last_error()
		var pln := OcgGpPln.from_n(OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpDir.from_6(0.0, 0.0, 1.0))
		var gen := OcgBRepBuilderAPIMakeFace.from_A(pln, 0.0, 2.0, -0.5, 0.5)
		if gen == null:
			return "builder failed at %d" % i
		OcgErrors.clear_last_error()
		var face := gen.face()
		if face == null:
			return "face failed at %d" % i
		var m := _mesh(face)
		if i == 0:
			TestRunner.ctx.log_info("plane mesh[0] = %s" % _mesh_size(m))
		if i == 25 or i == 50 or i == 75 or i == 99:
			_mark("plane mesh iter %d" % i)
	return "OK"

func test_fresh_face_mesh_fine() -> String:
	_rss_now = _rss_kb()
	_mark("start fine")
	for i in 200:
		var s := _make_surface(float(i) * 0.017)
		if s == null:
			return "surface failed at %d" % i
		var face := _make_face(s)
		if face == null:
			return "face failed at %d" % i
		_mesh(face)
		if i % 10 == 9 or i == 199:
			_mark("fine iter %d" % (i + 1))
	return "OK"

func test_worker_threads_mesh() -> String:
	var nthreads := 8
	var iters := 100
	var done: Array = []
	done.resize(nthreads)
	var threads: Array[Thread] = []
	for t in nthreads:
		threads.append(Thread.new())
	for t in nthreads:
		threads[t].start(_worker_build.bind(t, iters, done))
	_rss_now = _rss_kb()
	_mark("workers started")
	for s in 60:
		OS.delay_msec(1000)
		_mark("worker sample %d" % (s + 1))
		var all_done := true
		for t in nthreads:
			if not done[t]:
				all_done = false
				break
		if all_done:
			break
	for t in nthreads:
		threads[t].wait_to_finish()
	_mark("workers finished")
	return "OK"

func test_worker_threads_no_mesh() -> String:
	var nthreads := 8
	var iters := 100
	var done: Array = []
	done.resize(nthreads)
	var threads: Array[Thread] = []
	for t in nthreads:
		threads.append(Thread.new())
	for t in nthreads:
		threads[t].start(_worker_build_no_mesh.bind(t, iters, done))
	_rss_now = _rss_kb()
	_mark("workers (no mesh) started")
	for s in 60:
		OS.delay_msec(1000)
		_mark("worker-nm sample %d" % (s + 1))
		var all_done := true
		for t in nthreads:
			if not done[t]:
				all_done = false
				break
		if all_done:
			break
	for t in nthreads:
		threads[t].wait_to_finish()
	_mark("workers (no mesh) finished")
	return "OK"

func _worker_build(tid: int, iters: int, done: Array) -> void:
	for i in iters:
		var s := _make_surface(float(i) * 0.017 + float(tid))
		if s == null:
			done[tid] = true
			return
		var face := _make_face(s)
		if face == null:
			done[tid] = true
			return
		_mesh(face)
	done[tid] = true

func _worker_build_no_mesh(tid: int, iters: int, done: Array) -> void:
	for i in iters:
		var s := _make_surface(float(i) * 0.017 + float(tid))
		if s == null:
			done[tid] = true
			return
		var face := _make_face(s)
		if face == null:
			done[tid] = true
			return
	done[tid] = true

func test_worker_threads_mesh_long() -> String:
	var nthreads := 8
	var iters := 1500
	var done: Array = []
	done.resize(nthreads)
	var threads: Array[Thread] = []
	for t in nthreads:
		threads.append(Thread.new())
	for t in nthreads:
		threads[t].start(_worker_build.bind(t, iters, done))
	_rss_now = _rss_kb()
	_mark("long workers started")
	for s in 120:
		OS.delay_msec(5000)
		_mark("long sample %d" % (s + 1))
		var all_done := true
		for t in nthreads:
			if not done[t]:
				all_done = false
				break
		if all_done:
			break
	for t in nthreads:
		threads[t].wait_to_finish()
	_mark("long workers finished")
	return "OK"

func test_keep_results_alive() -> String:
	var kept: Array[OcgBRepMeshIncrementalMesh] = []
	_rss_now = _rss_kb()
	_mark("start (keep alive)")
	for i in 100:
		var s := _make_surface(float(i) * 0.017)
		if s == null:
			return "surface failed at %d" % i
		var face := _make_face(s)
		if face == null:
			return "face failed at %d" % i
		kept.append(_mesh(face))
		if i == 25 or i == 50 or i == 75 or i == 99:
			_mark("keep iter %d" % i)
	return "OK"
