@tool
class_name Flag
extends MeshInstance3D

## Animated flag built with OpenCASCADE on a background thread.
##
## The flag is a grid of control points approximated by a B-spline surface,
## meshed by OCCT and uploaded to the GPU. A double-buffered pipeline keeps the
## main thread rendering while a worker thread already builds the next flag, and
## every build is measured into a hierarchical stats tree (see `last_stats`).
##
## Stability rules (keep these intact when editing):
## - The worker thread does *all* OCCT work. OCCT wrapper objects are created and
##   destroyed only on that thread; nothing OCCT crosses the mutex. `_pending_result`
##   only ever carries Godot-native data (PackedArrays, ints, stats dicts).
## - Param dicts are snapshots; the worker never mutates them, so the main thread
##   can compare "unchanged" safely and skip redundant builds.
## - Every OCCT stage is guarded: a failed stage aborts the build and the last
##   good mesh stays on screen instead of crashing the process.

# ---------------------------------------------------------------------------
# Parameters -- the whole flag is controllable from the inspector
# ---------------------------------------------------------------------------

@export_group("Geometry")

## Flag width along X (pole at x = 0, free end at x = flag_width).
@export var flag_width := 2.0
## Flag height along Y.
@export var flag_height := 1.0

@export_group("Surface")

## Control points along the flag. More = smoother, slower.
@export var u_detail := 24
## Control points across the flag.
@export var v_detail := 12

@export_group("Meshing")

## Maximum distance between a mesh triangle and the exact surface.
@export var linear_deflection := 0.001
## Maximum angle (deg) between normals of neighbouring triangles.
@export var angular_deflection := 0.5

@export_group("Wind")

## Average wind intensity (0 = calm, 1 = normal, 2 = strong).
@export var wind_base := 1.0
## Gust intensity oscillated over time; varies waves, flutter and sag.
@export var wind_gust := 0.4
## Gust oscillation frequency in Hz.
@export var gust_speed := 0.15
## How fast wave crests travel along the flag.
@export var wind_speed := 2.8

@export_group("Waves")

## Number of full folds along the flag.
@export var wavelength := 2.0
## Fold steepness; scales the traveling waves (wind also scales them).
@export var amplitude := 1.0
## High-frequency ripple as a fraction of the fold steepness.
@export var flutter := 0.2

@export_group("Deformation")

## How much the free end droops toward -Y at zero wind (world units).
## Stronger wind flattens the sag.
@export var sag := 0.4
## Sideways sway of the free end along X (world units).
@export var bend := 0.08
## Sway oscillation frequency in Hz.
@export var bend_speed := 0.12
## Average cross-sectional curvature near the free end.
@export var camber := 0.12
## How much the curvature changes with the wind.
@export var camber_dynamic := 0.08
## Number of cups/ridges travelling down the flag.
@export var camber_wavelength := 1.8
## Speed of the travelling camber pattern.
@export var camber_speed := 2.4

@export_group("Runtime")

## Animation clock. Scrubbing it rebuilds the flag.
@export var time := 0.0
@export var time_scale := 0.01
## Automatically advance the animation clock.
@export var animated := false
## Print the hierarchical build timings to the console.
@export var print_timings := true

@export_tool_button("Rebuild") var _rebuild_btn := request_build

@export_tool_button("Step") var _step_btn := step_once

signal stats_changed(stats: Dictionary)

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Statistics of the latest build as a hierarchy: "Frame" at the root, then
## "Flag build" (worker thread) and "Apply (main thread)", each split further
## into sections. Ready to be displayed in a UI.
var last_stats: Dictionary = {}

# ---------------------------------------------------------------------------
# Double-buffered pipeline: worker builds the next flag while we render this one
# ---------------------------------------------------------------------------

var _thread: Thread
var _mutex := Mutex.new()
var _work_sem := Semaphore.new()
var _done_sem := Semaphore.new()
var _exit := false
var _params := {}
var _params_sent := {}
var _work_pending := false
var _pending_result := {}
# Time (usec) when the previous mesh was applied on the main thread.
# Used to measure the frame-to-frame interval between visible mesh updates.
var _last_mesh_update_us := 0


func _ready() -> void:
	# Editor reloads can re-enter _ready; never spawn a second worker.
	if _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_worker_main)
	if not Engine.is_editor_hint():
		print_timings = false
		animated = true


func _exit_tree() -> void:
	_stop_worker()


func _stop_worker() -> void:
	var t := _thread
	if t == null:
		return
	_mutex.lock()
	_exit = true
	_mutex.unlock()
	_work_sem.post()
	if t.is_started():
		t.wait_to_finish()
	_thread = null


func _process(_delta: float) -> void:
	if animated:
		time += _delta * time_scale
	_drain_results()
	if _thread == null:
		return
	var p := _snapshot_params()
	_mutex.lock()
	var changed := p != _params_sent
	var busy := _work_pending
	_mutex.unlock()
	if changed and not busy:
		_request_build(p)


func _snapshot_params() -> Dictionary:
	return {
		"flag_width": flag_width, "flag_height": flag_height,
		"u_detail": u_detail, "v_detail": v_detail,
		"linear_deflection": linear_deflection, "angular_deflection": angular_deflection,
		"time": time, "wind_base": wind_base, "wind_gust": wind_gust,
		"gust_speed": gust_speed, "wind_speed": wind_speed,
		"wavelength": wavelength, "amplitude": amplitude, "flutter": flutter,
		"sag": sag, "camber": camber, "camber_dynamic": camber_dynamic,
		"camber_wavelength": camber_wavelength, "camber_speed": camber_speed,
		"bend": bend, "bend_speed": bend_speed,
	}


func request_build() -> void:
	if _thread == null:
		return
	_mutex.lock()
	var busy := _work_pending
	_mutex.unlock()
	if not busy:
		_request_build(_snapshot_params())


## Stops the animation and advances the clock by one frame.
func step_once() -> void:
	animated = false
	time += time_scale * (1.0 / 60.0)


func _request_build(p: Dictionary) -> void:
	_mutex.lock()
	# Duplicate so the worker owns a private copy it can never mutate behind
	# the main thread's back (this also guarantees the "changed" compare stays sane).
	_params = p.duplicate()
	_params_sent = _params
	_work_pending = true
	_mutex.unlock()
	_work_sem.post()


func get_stats() -> Dictionary:
	return last_stats


func _worker_main() -> void:
	while true:
		_work_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			break
		var p := _params
		_mutex.unlock()
		# A failed build returns {}; _apply_result ignores it and the previous
		# mesh stays on screen. A GDScript error inside the build only aborts
		# this function frame, so the worker thread itself never dies here.
		var result := _build_flag(p)
		_mutex.lock()
		_pending_result = result
		_mutex.unlock()
		_done_sem.post()


func _drain_results() -> void:
	while _done_sem.try_wait():
		_mutex.lock()
		var result := _pending_result
		# The request stays pending until its result is consumed here, so the
		# worker never has more than one build in flight and results are always
		# applied in request order (no stale-frame jumps or lost frames).
		_work_pending = false
		_mutex.unlock()
		_apply_result(result)


func _apply_result(result: Dictionary) -> void:
	if result.is_empty() or not result.has("arrays"):
		return
	var t0 := Time.get_ticks_usec()
	var arrays: Dictionary = result["arrays"]
	if arrays.is_empty():
		return
	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = arrays["verts"]
	mesh_arrays[Mesh.ARRAY_NORMAL] = arrays["normals"]
	mesh_arrays[Mesh.ARRAY_INDEX] = arrays["indices"]
	mesh_arrays[Mesh.ARRAY_TEX_UV] = arrays["uvs"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	mesh = m
	var apply_us := Time.get_ticks_usec() - t0

	# Time between visible mesh updates (main thread).
	var now_us := Time.get_ticks_usec()
	var frame_to_frame_us := 0
	if _last_mesh_update_us != 0:
		frame_to_frame_us = now_us - _last_mesh_update_us
	_last_mesh_update_us = now_us

	var build_stats: Dictionary = result["stats"]
	last_stats = {
		"name": "Frame",
		"us": apply_us + int(build_stats["us"]),
		"nodes": result["nodes"],
		"triangles": result["triangles"],
		"children": [
			build_stats.duplicate(true),
			{"name": "Apply (main thread)", "us": apply_us},
			{"name": "Mesh-to-mesh", "us": frame_to_frame_us}
		],
	}
	if print_timings:
		_print_stats(last_stats)
	stats_changed.emit(last_stats)


func _print_stats(s: Dictionary, indent := "") -> void:
	print("%s%-28s %9.3f ms" % [indent, s["name"], s["us"] / 1000.0])
	for c in s.get("children", []):
		_print_stats(c, indent + "  ")


# ---------------------------------------------------------------------------
# Worker thread: all OCCT + meshing work happens here
# ---------------------------------------------------------------------------

## True if the last OCCT call recorded no error. Wrappers record the caught
## exception in thread-local state, so this is only meaningful on the worker
## thread right after an OCCT call.
func _occt_ok() -> bool:
	return OcgErrors.get_last_error_message() == ""


func _build_flag(p: Dictionary) -> Dictionary:
	var stat := _Stat.new()
	stat.name = "Flag build"
	stat.begin()

	var surface: OcgGeomBSplineSurface = _measure(stat, "Surface", func(s: _Stat): return _make_surface(p, s))
	if surface == null:
		stat.end()
		return {}

	var mesh: Dictionary = _measure(stat, "Triangulation", func(s: _Stat): return _triangulate(p, surface, s))
	if mesh.is_empty():
		stat.end()
		return {}

	var arrays: Dictionary = _measure(stat, "To Godot arrays", func(s: _Stat): return _tri_to_arrays(mesh["triangulation"], mesh, s))
	if arrays.is_empty():
		stat.end()
		return {}

	stat.end()
	return {
		"arrays": arrays,
		"stats": stat.to_dict(),
		"nodes": mesh["triangulation"].nb_nodes(),
		"triangles": mesh["triangulation"].nb_triangles(),
	}


func _measure(parent: _Stat, name: String, fn: Callable) -> Variant:
	var s := _Stat.new()
	s.name = name
	s.begin()
	var result = fn.call(s)
	s.end()
	parent.children.append(s)
	return result


func _make_surface(p: Dictionary, sec: _Stat) -> OcgGeomBSplineSurface:
	var pts: OcgNCollectionArray2GpPnt = _measure(sec, "Control points", func(_s: _Stat): return _make_points(p))
	if pts == null:
		return null
	var fit: OcgGeomAPIPointsToBSplineSurface = _measure(sec, "B-spline fit", func(_s: _Stat):
		var f := OcgGeomAPIPointsToBSplineSurface.new()
		if f == null:
			return null
		# Drop any error a constructor may have recorded, so only init_g's
		# outcome decides whether this stage succeeded.
		OcgErrors.clear_last_error()
		f.init_g(pts, 8, 8, OcgEnums.GeomAbs_Shape.GeomAbs_G2, 1e-5)
		return f
	)
	if fit == null or not _occt_ok():
		return null
	OcgErrors.clear_last_error()
	var surface: OcgGeomBSplineSurface = fit.surface()
	if surface == null or not _occt_ok():
		return null
	return surface


## Lay out control points as a chain of constant-length segments (rope/spring):
## each point sits a fixed distance from the previous one, so the flag's arc
## length never changes no matter how much it waves or sags. The segment
## direction blends a forward step, a downward sag and a traveling fold slope,
## then rotates around Y for the sway -- a cheap, stable fake cloth.
func _make_points(p: Dictionary) -> OcgNCollectionArray2GpPnt:
	var nu: int = maxi(p["u_detail"], 2)
	var nv: int = maxi(p["v_detail"], 2)
	var pts := OcgNCollectionArray2GpPnt.from_v(1, nu, 1, nv)

	var t: float = p["time"]
	var wind := _wind(p)
	var seg_len: float = p["flag_width"] / float(nu)
	var height: float = p["flag_height"]
	var sway: float = p["bend"] * sin(TAU * t * p["bend_speed"])
	# Sag flattens as wind picks up (see also `_wind`): strong gusts carry the flag.
	var sag_slope: float = maxf(p["sag"] * (1.0 - 0.75 * wind), 0.0)
	# Fold steepness scales with wind and amplitude.
	var fold: float = p["amplitude"] * wind
	# Keep the phase divisors away from zero so degenerate params can't produce
	# NaN/inf geometry that OCCT would struggle to fit and mesh.
	var wavelength := maxf(p["wavelength"], 0.05)
	var camber_wavelength := maxf(p["camber_wavelength"], 0.05)

	for v in nv:
		var v_norm := float(v) / float(nv - 1)
		var y_off := (v_norm - 0.5) * height
		var start := Vector3(0.0, y_off, 0.0)
		# Diagonal ripple across the width so folds travel like cloth, not a board.
		var twist := (v_norm - 0.5) * 0.8
		var pos := start
		var s := seg_len
		pts.set_value(1, v + 1, OcgGpPnt.from_6(pos.x, pos.y, pos.z))
		for i in range(1, nu):
			var x_norm := float(i) / float(nu)

			# Base wave envelope.
			var env := (1.0 - exp(-x_norm * 4.0)) * (1.0 - 0.12 * pow(x_norm, 8.0))

			# Flutter only exists near the free end.
			var flutter_env := smoothstep(0.75, 1.0, x_norm)

			var phase: float = TAU * (s / wavelength - t * p["wind_speed"]) + twist

			var slope := env * (
				fold * sin(phase)
				+ 0.25 * fold * sin(2.0 * phase + 0.7)
			)

			slope += flutter_env * p["flutter"] * fold * \
				sin(TAU * 6.0 * s / wavelength - TAU * 8.0 * t)

			var dir := Vector3(
				1.0,
				-sag_slope * x_norm * x_norm,
				slope
			).normalized()

			# Existing sway.
			var a := sway * x_norm
			var c := cos(a)
			var sn := sin(a)

			pos += Vector3(
				dir.x * c - dir.z * sn,
				dir.y,
				dir.x * sn + dir.z * c
			) * seg_len

			# Cross-sectional curvature.
			var tip := smoothstep(0.45, 1.0, x_norm)

			# Travelling phase, offset across the flag so neighbouring strips
			# aren't perfectly synchronized.
			var camber_phase = TAU * (
					s / camber_wavelength
					- t * p["camber_speed"]
				) + (v_norm - 0.5) * 0.8

			# Curvature magnitude changes over time.
			var k = p["camber"] + p["camber_dynamic"] * sin(camber_phase)

			# Cross-section shape.
			# -1..1 across the height.
			var yy := 2.0 * v_norm - 1.0

			# Parabolic profile (zero at edges, maximum at centre).
			var profile := 1.0 - yy * yy

			# Occasionally flip curvature as cloth twists.
			profile *= sign(sin(camber_phase * 0.4))

			pos.z += tip * k * profile

			pts.set_value(i + 1, v + 1, OcgGpPnt.from_6(pos.x, pos.y, pos.z))
			s += seg_len
	return pts


func _wind(p: Dictionary) -> float:
	return maxf(p["wind_base"] + p["wind_gust"] * sin(TAU * p["time"] * p["gust_speed"]), 0.0)


func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Meshes the given surface and returns a dict with the triangulation and the
## parametric UV bounds (used to normalize texture coordinates). Returns {}
## if any stage fails; the caller keeps the previous mesh in that case.
func _triangulate(p: Dictionary, surface: OcgGeomBSplineSurface, sec: _Stat) -> Dictionary:
	var face: OcgTopoDSFace = _measure(sec, "Build face", func(_s: _Stat):
		OcgErrors.clear_last_error()
		var gen := OcgBRepBuilderAPIMakeFace.new()
		if gen == null:
			return null
		gen.init_W(surface, true, 1e-6)
		# The builder's default ctor records a benign "not done" error; drop it
		# so only Face()'s own outcome decides whether this stage succeeded.
		OcgErrors.clear_last_error()
		return gen.face()
	)
	if face == null or not _occt_ok():
		return {}
	_measure(sec, "Incremental mesh", func(_s: _Stat):
		OcgErrors.clear_last_error()
		return OcgBRepMeshIncrementalMesh.from_z(
			face, maxf(p["linear_deflection"], 1e-4), false, maxf(p["angular_deflection"], 0.05), false
		)
	)
	if not _occt_ok():
		return {}
	var bounds: Dictionary = _measure(sec, "Grab UV bounds", func(_s: _Stat):
		OcgErrors.clear_last_error()
		var umin := OcgStandardReal.new()
		var umax := OcgStandardReal.new()
		var vmin := OcgStandardReal.new()
		var vmax := OcgStandardReal.new()
		surface.bounds(umin, umax, vmin, vmax)
		return {
			"umin": umin.get_value(), "umax": umax.get_value(),
			"vmin": vmin.get_value(), "vmax": vmax.get_value(),
		}
	)
	if not _occt_ok():
		return {}
	var tri: OcgPolyTriangulation = _measure(sec, "Extract triangulation", func(_s: _Stat):
		OcgErrors.clear_last_error()
		return OcgBRepTool.triangulation(face, OcgTopLocLocation.new(), 0)
	)
	if tri == null or not _occt_ok():
		return {}
	bounds["triangulation"] = tri
	return bounds


func _tri_to_arrays(tri: OcgPolyTriangulation, mesh: Dictionary, sec: _Stat) -> Dictionary:
	_measure(sec, "Compute normals", func(_s: _Stat):
		OcgErrors.clear_last_error()
		tri.compute_normals()
		return null
	)
	if not _occt_ok():
		return {}
	var node_count: int = tri.nb_nodes()
	var triangle_count: int = tri.nb_triangles()
	if node_count == 0 or triangle_count == 0:
		return {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var umin: float = mesh["umin"]
	var umax: float = mesh["umax"]
	var vmin: float = mesh["vmin"]
	var vmax: float = mesh["vmax"]
	var du := umax - umin
	var dv := vmax - vmin
	var u_scale := 0.0 if du <= 0.0 else 1.0 / du
	var v_scale := 0.0 if dv <= 0.0 else 1.0 / dv
	_measure(sec, "Copy vertices", func(_s: _Stat):
		var n := OcgNCollectionVec3Float.new()
		for i in node_count:
			var pnt := tri.node(i + 1)
			verts.push_back(Vector3(pnt.x(), pnt.y(), pnt.z()))
			tri.normal(i + 1, n)
			normals.push_back(-Vector3(n.x(), n.y(), n.z()))
			var uv := tri.uv_node(i + 1)
			uvs.push_back(Vector2(
				(uv.x() - umin) * u_scale,
				1.0 - (uv.y() - vmin) * v_scale
			))
		return null
	)
	_measure(sec, "Copy indices", func(_s: _Stat):
		var a := OcgStandardInteger.new()
		var b := OcgStandardInteger.new()
		var c := OcgStandardInteger.new()
		for i in triangle_count:
			var t := tri.triangle(i + 1)
			t.get(a, b, c)
			indices.push_back(a.get_value() - 1)
			indices.push_back(b.get_value() - 1)
			indices.push_back(c.get_value() - 1)
		return null
	)
	return {"verts": verts, "normals": normals, "indices": indices, "uvs": uvs}


# ---------------------------------------------------------------------------
# Hierarchical timing stats
# ---------------------------------------------------------------------------

class _Stat:
	var name := ""
	var elapsed := 0
	var children: Array[_Stat] = []

	func begin() -> void:
		elapsed = -Time.get_ticks_usec()

	func end() -> void:
		elapsed += Time.get_ticks_usec()

	func to_dict() -> Dictionary:
		var d := {"name": name, "us": elapsed}
		if not children.is_empty():
			var c := []
			for child in children:
				c.append(child.to_dict())
			d["children"] = c
		return d
