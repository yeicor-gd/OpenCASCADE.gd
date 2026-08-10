extends Node

const TOL := 1e-6


func _near(a: float, b: float) -> bool:
	return abs(a - b) < TOL


func test_quaternion_axis_angle() -> String:
	# from_w(axis, angle) and from_r(x, y, z, w) constructors.
	var axis := OcgGpVec.from_6(0.0, 0.0, 1.0)
	var q := OcgGpQuaternion.from_w(axis, PI / 2.0)
	if q == null:
		return "Failed to create gp_Quaternion from axis/angle"
	if not _near(q.norm(), 1.0):
		return "Unit quaternion norm expected 1 got %s" % q.norm()
	if not _near(q.w(), cos(PI / 4.0)) or not _near(q.z(), sin(PI / 4.0)):
		return "Quaternion components wrong: x=%s y=%s z=%s w=%s" % [q.x(), q.y(), q.z(), q.w()]
	var r := OcgGpQuaternion.from_r(q.x(), q.y(), q.z(), q.w())
	if not r.is_equal(q):
		return "from_r(x,y,z,w) should reproduce the quaternion"
	# Rotating (1,0,0) about +Z by 90 deg should give (0,1,0).
	var v := q.multiply_H(OcgGpVec.from_6(1.0, 0.0, 0.0))
	if not _near(v.x(), 0.0) or not _near(v.y(), 1.0) or not _near(v.z(), 0.0):
		return "Quaternion rotate (1,0,0) expected (0,1,0) got (%s,%s,%s)" % [v.x(), v.y(), v.z()]
	return "OK"


func test_quaternion_vector_and_angle_out_params() -> String:
	var q := OcgGpQuaternion.from_r(0.0, 0.0, sin(PI / 4.0), cos(PI / 4.0))
	var axis := OcgGpVec.new()
	var angle := OcgStandardReal.new()
	q.get_vector_and_angle(axis, angle)
	if not _near(angle.get_value(), PI / 2.0):
		return "Extracted angle expected PI/2 got %s" % angle.get_value()
	if not _near(axis.z(), 1.0) or not _near(axis.x(), 0.0) or not _near(axis.y(), 0.0):
		return "Extracted axis wrong: (%s,%s,%s)" % [axis.x(), axis.y(), axis.z()]
	return "OK"


func test_quaternion_inverse_roundtrip() -> String:
	var q := OcgGpQuaternion.from_w(OcgGpVec.from_6(1.0, 0.0, 0.0), PI / 3.0)
	var inv := q.inverted()
	var prod := q.multiplied(inv)
	# q * q^-1 should be the identity quaternion (1,0,0,0).
	if not _near(prod.w(), 1.0) or not _near(prod.norm(), 1.0):
		return "q*q^-1 expected identity got w=%s norm=%s" % [prod.w(), prod.norm()]
	if not _near(prod.x(), 0.0) or not _near(prod.y(), 0.0) or not _near(prod.z(), 0.0):
		return "q*q^-1 vector part not zero"
	var v := q.multiply_H(OcgGpVec.from_6(0.0, 1.0, 0.0))
	v = inv.multiply_H(v)
	if not _near(v.x(), 0.0) or not _near(v.y(), 1.0) or not _near(v.z(), 0.0):
		return "Inverse rotation roundtrip failed: (%s,%s,%s)" % [v.x(), v.y(), v.z()]
	return "OK"


func test_quaternion_matrix_bridge() -> String:
	var q := OcgGpQuaternion.from_w(OcgGpVec.from_6(0.0, 0.0, 1.0), PI / 2.0)
	var m := q.get_matrix()
	if m == null:
		return "get_matrix() returned null"
	# Rotation about Z by 90 deg: M(1,2) = -1, M(2,1) = 1.
	if not _near(m.value(1, 2), -1.0) or not _near(m.value(2, 1), 1.0):
		return "Quaternion rotation matrix wrong: value(1,2)=%s value(2,1)=%s" % [m.value(1, 2), m.value(2, 1)]
	var back := OcgGpQuaternion.from__(m)
	if not _near(back.norm(), 1.0):
		return "Quaternion from matrix should be unit: %s" % back.norm()
	if not _near(back.z(), sin(PI / 4.0)) or not _near(back.w(), cos(PI / 4.0)):
		return "Quaternion from matrix components wrong"
	return "OK"


func test_quaternion_arithmetic() -> String:
	var q1 := OcgGpQuaternion.from_w(OcgGpVec.from_6(0.0, 0.0, 1.0), PI / 4.0)
	var q2 := OcgGpQuaternion.from_w(OcgGpVec.from_6(0.0, 0.0, 1.0), PI / 4.0)
	var sum := q1.added(q2)
	if not _near(sum.w(), 2.0 * q1.w()) or not _near(sum.z(), 2.0 * q1.z()):
		return "Quaternion add wrong"
	var scaled := q1.scaled(2.0)
	if not _near(scaled.z(), 2.0 * q1.z()):
		return "Quaternion scale wrong"
	var diff := sum.subtracted(scaled)
	if diff.norm() > TOL:
		return "Quaternion subtract wrong: norm=%s" % diff.norm()
	var dot := q1.dot(q2)
	if not _near(dot, 1.0):
		return "Dot of equal unit quaternions expected 1 got %s" % dot
	return "OK"


func test_quaternion_euler_angles() -> String:
	var q := OcgGpQuaternion.new()
	q.set_euler_angles(OcgEnums.gp_EulerSequence.gp_EulerAngles, 0.1, 0.2, 0.3)
	var alpha := OcgStandardReal.new()
	var beta := OcgStandardReal.new()
	var gamma := OcgStandardReal.new()
	q.get_euler_angles(OcgEnums.gp_EulerSequence.gp_EulerAngles, alpha, beta, gamma)
	if not _near(alpha.get_value(), 0.1) or not _near(beta.get_value(), 0.2) or not _near(gamma.get_value(), 0.3):
		return "Euler roundtrip wrong: %s,%s,%s" % [alpha.get_value(), beta.get_value(), gamma.get_value()]
	if not _near(q.norm(), 1.0):
		return "Quaternion from Euler angles should be unit: %s" % q.norm()
	return "OK"


func test_mat_identity_ops() -> String:
	var m := OcgGpMat.from_z(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
	if not _near(m.determinant(), 1.0):
		return "Identity determinant expected 1 got %s" % m.determinant()
	if m.is_singular():
		return "Identity should not be singular"
	if not _near(m.value(2, 2), 1.0) or not _near(m.value(1, 3), 0.0):
		return "Identity value() wrong"
	var inv := m.inverted()
	if not _near(inv.value(1, 1), 1.0):
		return "Inverted identity wrong"
	var tr := m.transposed()
	if not _near(tr.value(3, 3), 1.0):
		return "Transposed identity wrong"
	return "OK"


func test_mat_rotation_arithmetic() -> String:
	var m := OcgGpMat.from_z(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
	m.set_rotation(OcgGpXYZ.from_6(0.0, 0.0, 1.0), PI / 2.0)
	if not _near(m.determinant(), 1.0):
		return "Rotation determinant expected 1 got %s" % m.determinant()
	if not _near(m.value(1, 2), -1.0) or not _near(m.value(2, 1), 1.0):
		return "Rotation matrix entries wrong"
	var prod := m.multiplied_b(m.inverted())
	if not _near(prod.value(1, 1), 1.0) or not _near(prod.value(2, 2), 1.0):
		return "M*M^-1 should be identity"
	var sq := m.powered(4)
	if not _near(sq.value(1, 1), 1.0):
		return "M^4 should be identity for 90-deg rotation"
	return "OK"


func test_trsf_rotation() -> String:
	var t := OcgGpTrsf.new()
	var axis := OcgGpAx1.from_O(OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpDir.D.Z)
	t.set_rotation_6(axis, PI / 2.0)
	if not _near(t.value(1, 1), 0.0) or not _near(t.value(1, 2), -1.0):
		return "Rotation Trsf value(1,1)=%s value(1,2)=%s" % [t.value(1, 1), t.value(1, 2)]
	if not _near(t.value(2, 1), 1.0):
		return "Rotation Trsf value(2,1)=%s" % t.value(2, 1)
	if not _near(t.scale_factor(), 1.0):
		return "Rotation scale factor expected 1 got %s" % t.scale_factor()
	var p := OcgGpPnt.from_6(1.0, 0.0, 0.0).transformed(t)
	if not _near(p.x(), 0.0) or not _near(p.y(), 1.0) or not _near(p.z(), 0.0):
		return "Rotated point wrong: (%s,%s,%s)" % [p.x(), p.y(), p.z()]
	return "OK"


func test_trsf_translation() -> String:
	var t := OcgGpTrsf.new()
	t.set_translation_Z(OcgGpVec.from_6(1.0, 2.0, 3.0))
	# Translation components live in column 4 of the 3x4 matrix; rows are [1,3].
	if not _near(t.value(1, 4), 1.0) or not _near(t.value(2, 4), 2.0) or not _near(t.value(3, 4), 3.0):
		return "Translation Trsf column 4 wrong"
	if not _near(t.value(1, 1), 1.0) or not _near(t.value(2, 2), 1.0) or not _near(t.value(3, 3), 1.0):
		return "Translation Trsf rotation part should be identity"
	var part := t.translation_part()
	if part == null:
		return "translation_part() returned null"
	if not _near(part.x(), 1.0) or not _near(part.y(), 2.0) or not _near(part.z(), 3.0):
		return "translation_part wrong: (%s,%s,%s)" % [part.x(), part.y(), part.z()]
	var p := OcgGpPnt.from_6(10.0, 0.0, 0.0).transformed(t)
	if not _near(p.x(), 11.0) or not _near(p.z(), 3.0):
		return "Translated point wrong: (%s,%s,%s)" % [p.x(), p.y(), p.z()]
	return "OK"


func test_trsf_scale() -> String:
	var t := OcgGpTrsf.new()
	t.set_scale(OcgGpPnt.from_6(0.0, 0.0, 0.0), 2.0)
	if not _near(t.scale_factor(), 2.0):
		return "Scale factor expected 2 got %s" % t.scale_factor()
	var p := OcgGpPnt.from_6(1.0, 2.0, 3.0).transformed(t)
	if not _near(p.x(), 2.0) or not _near(p.y(), 4.0) or not _near(p.z(), 6.0):
		return "Scaled point wrong: (%s,%s,%s)" % [p.x(), p.y(), p.z()]
	return "OK"


func test_trsf_compose_invert() -> String:
	var rot := OcgGpTrsf.new()
	rot.set_rotation_6(OcgGpAx1.from_O(OcgGpPnt.from_6(0.0, 0.0, 0.0), OcgGpDir.D.Z), PI / 2.0)
	var trans := OcgGpTrsf.new()
	trans.set_translation_Z(OcgGpVec.from_6(5.0, 0.0, 0.0))
	# trans.Multiplied(rot) applies rot first, then trans (see gp_Trsf docs).
	var combined := trans.multiplied(rot)
	var p := OcgGpPnt.from_6(1.0, 0.0, 0.0)
	var q := p.transformed(combined)
	# rotate first, then translate: (0,1,0) + (5,0,0) = (5,1,0)
	if not _near(q.x(), 5.0) or not _near(q.y(), 1.0):
		return "Composed transform wrong: (%s,%s,%s)" % [q.x(), q.y(), q.z()]
	var back := q.transformed(combined.inverted())
	if not _near(back.x(), 1.0) or not _near(back.y(), 0.0):
		return "Inverse composed transform wrong: (%s,%s,%s)" % [back.x(), back.y(), back.z()]
	# rot.Multiplied(trans) applies trans first, then rot: (1,0,0) -> (6,0,0) -> (0,6,0).
	var combined2 := rot.multiplied(trans)
	var q2 := p.transformed(combined2)
	if not _near(q2.x(), 0.0) or not _near(q2.y(), 6.0):
		return "Opposite composition wrong: (%s,%s,%s)" % [q2.x(), q2.y(), q2.z()]
	return "OK"
