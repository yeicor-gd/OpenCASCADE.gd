extends Node


func test_array1_gp_pnt() -> String:
	var arr := OcgNCollectionArray1GpPnt.from_k(1, 3)
	if arr == null:
		return "Failed to create Array1<gp_Pnt>"
	if arr.lower() != 1 or arr.upper() != 3 or arr.length() != 3:
		return "Array1 bounds wrong: lower=%s upper=%s length=%s" % [arr.lower(), arr.upper(), arr.length()]
	if arr.is_empty():
		return "Array1 should not be empty"
	var p1 := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var p2 := OcgGpPnt.from_6(4.0, 5.0, 6.0)
	var p3 := OcgGpPnt.from_6(7.0, 8.0, 9.0)
	arr.set_value(1, p1)
	arr.set_value(2, p2)
	arr.set_value(3, p3)
	if arr.value(1).x() != 1.0 or arr.value(2).y() != 5.0 or arr.value(3).z() != 9.0:
		return "Array1 SetValue/Value roundtrip failed"
	if arr.change_value(2).x() != 4.0:
		return "Array1 ChangeValue read-back failed"
	var p4 := OcgGpPnt.from_6(55.0, 0.0, 0.0)
	arr.set_value(2, p4)
	if arr.value(2).x() != 55.0:
		return "Array1 SetValue mutation failed"
	arr.init(p1)
	if arr.value(1).x() != 1.0 or arr.value(3).z() != 3.0:
		return "Array1 Init fill failed"
	return "OK"


func test_array2_gp_pnt() -> String:
	var arr := OcgNCollectionArray2GpPnt.from_v(1, 2, 3, 4)
	if arr == null:
		return "Failed to create Array2<gp_Pnt>"
	if arr.lower_row() != 1 or arr.upper_row() != 2 or arr.lower_col() != 3 or arr.upper_col() != 4:
		return "Array2 bounds wrong"
	if arr.row_length() != 2 or arr.col_length() != 2:
		return "Array2 lengths wrong"
	var p := OcgGpPnt.from_6(10.0, 20.0, 30.0)
	arr.set_value(1, 3, p)
	if arr.value(1, 3).x() != 10.0 or arr.value(1, 3).z() != 30.0:
		return "Array2 SetValue/Value roundtrip failed"
	return "OK"


func test_list_double() -> String:
	var lst := OcgNCollectionListDouble.new()
	if not lst.is_empty():
		return "List should start empty"
	lst.append_y(1.5)
	lst.append_y(2.5)
	if lst.extent() != 2:
		return "List Extent wrong: %s" % lst.extent()
	if lst.first() != 1.5 or lst.last() != 2.5:
		return "List First/Last wrong"
	if not lst.contains(1.5) or not lst.contains(2.5):
		return "List Contains failed"
	if lst.contains(9.9):
		return "List Contains false positive"
	lst.remove_first()
	if lst.first() != 2.5:
		return "List RemoveFirst failed"
	lst.clear()
	if not lst.is_empty():
		return "List Clear failed"
	return "OK"


func test_sequence_gp_pnt() -> String:
	var seq := OcgNCollectionSequenceGpPnt.new()
	var p1 := OcgGpPnt.from_6(1.0, 0.0, 0.0)
	var p2 := OcgGpPnt.from_6(0.0, 2.0, 0.0)
	seq.append_N(p1)
	seq.append_N(p2)
	if seq.length() != 2:
		return "Sequence length wrong"
	if seq.first().x() != 1.0 or seq.last().y() != 2.0:
		return "Sequence First/Last wrong"
	var p0 := OcgGpPnt.from_6(0.0, 0.0, 3.0)
	seq.prepend_N(p0)
	if seq.length() != 3 or seq.first().z() != 3.0:
		return "Sequence Prepend failed"
	if seq.value(3).y() != 2.0:
		return "Sequence Value wrong"
	seq.insert_before(2, OcgGpPnt.from_6(5.0, 5.0, 5.0))
	if seq.length() != 4 or seq.value(2).x() != 5.0:
		return "Sequence InsertBefore failed"
	seq.set_value(2, OcgGpPnt.from_6(6.0, 6.0, 6.0))
	if seq.value(2).y() != 6.0:
		return "Sequence SetValue failed"
	seq.remove(2)
	if seq.length() != 3 or seq.value(2).x() != 1.0:
		return "Sequence Remove failed"
	seq.clear()
	if not seq.is_empty():
		return "Sequence Clear failed"
	return "OK"


func test_shape_keyed_containers() -> String:
	var shape := OcgTopoDSShape.new()
	if shape == null:
		return "Failed to create TopoDS_Shape"
	var lst := OcgNCollectionListTopoDSShape.new()
	lst.append_4(shape)
	if lst.extent() != 1:
		return "List<Shape> Extent wrong"
	if not lst.contains(shape):
		return "List<Shape> Contains failed"
	if lst.first() == null:
		return "List<Shape> First() returned null"

	var mp := OcgNCollectionMapTopoDSShapeTopToolsShapeMapHasher.new()
	if not mp.add(shape):
		return "Map<Shape> Add failed"
	if not mp.contains(shape) or mp.extent() != 1:
		return "Map<Shape> Contains/Extent wrong"
	if not mp.remove(shape) or not mp.is_empty():
		return "Map<Shape> Remove failed"

	var im := OcgNCollectionIndexedMapTopoDSShapeTopToolsShapeMapHasher.new()
	if im.add(shape) != 1:
		return "IndexedMap<Shape> Add failed"
	if im.find_index(shape) != 1:
		return "IndexedMap<Shape> FindIndex wrong"
	if im.find_key(1) == null:
		return "IndexedMap<Shape> FindKey returned null"

	var dm := OcgNCollectionIndexedDataMapTopoDSShapeDoubleTopToolsShapeMapHasher.new()
	if dm.add(shape, 3.5) != 1:
		return "IndexedDataMap<Shape, double> Add failed"
	if dm.find_from_key(shape) != 3.5 or dm.find_from_index(1) != 3.5:
		return "IndexedDataMap<Shape, double> Find failed"
	return "OK"


func test_vec3_double() -> String:
	var v := OcgNCollectionVec3Double.new()
	v.set_values(3.0, 4.0, 0.0)
	if v.x() != 3.0 or v.y() != 4.0 or v.z() != 0.0:
		return "Vec3 component access failed"
	if v.modulus() != 5.0:
		return "Vec3 Modulus failed: %s" % v.modulus()
	if v.square_modulus() != 25.0:
		return "Vec3 SquareModulus failed"
	var w := OcgNCollectionVec3Double.new()
	w.set_values(1.0, 0.0, 0.0)
	if v.dot(w) != 3.0:
		return "Vec3 Dot failed"
	var c := OcgNCollectionVec3Double.cross(v, w)
	if c == null or c.x() != 0.0 or c.y() != 0.0 or c.z() != -4.0:
		return "Vec3 Cross failed"
	return "OK"
