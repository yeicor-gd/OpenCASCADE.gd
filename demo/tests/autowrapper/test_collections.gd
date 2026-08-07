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
	arr.set_value_v(1, p1)
	arr.set_value_v(2, p2)
	arr.set_value_v(3, p3)
	if arr.value(1).x() != 1.0 or arr.value(2).y() != 5.0 or arr.value(3).z() != 9.0:
		return "Array1 SetValue/Value roundtrip failed"
	if arr.change_value(2).x() != 4.0:
		return "Array1 ChangeValue read-back failed"
	var p4 := OcgGpPnt.from_6(55.0, 0.0, 0.0)
	arr.set_value_v(2, p4)
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
	arr.set_value_m(1, 3, p)
	if arr.value(1, 3).x() != 10.0 or arr.value(1, 3).z() != 30.0:
		return "Array2 SetValue/Value roundtrip failed"
	return "OK"


func test_list_double() -> String:
	var lst := OcgNCollectionListDouble.new()
	lst.append_y(1.5)
	lst.append_y(2.5)
	if lst.first_k() != 1.5 or lst.last_k() != 2.5:
		return "List First/Last wrong"
	lst.remove_first()
	if lst.first_k() != 2.5:
		return "List RemoveFirst failed"
	lst.clear(OcgNCollectionBaseAllocator.common_base_allocator())
	return "OK"


func test_sequence_gp_pnt() -> String:
	var seq := OcgNCollectionSequenceGpPnt.new()
	var p1 := OcgGpPnt.from_6(1.0, 0.0, 0.0)
	var p2 := OcgGpPnt.from_6(0.0, 2.0, 0.0)
	seq.append_N(p1)
	seq.append_N(p2)
	if seq.upper() != 2:
		return "Sequence length wrong"
	if seq.first().x() != 1.0 or seq.last().y() != 2.0:
		return "Sequence First/Last wrong"
	var p0 := OcgGpPnt.from_6(0.0, 0.0, 3.0)
	seq.prepend_N(p0)
	if seq.upper() != 3 or seq.first().z() != 3.0:
		return "Sequence Prepend failed"
	if seq.value_T(3).y() != 2.0:
		return "Sequence Value wrong"
	seq.insert_before_v(2, OcgGpPnt.from_6(5.0, 5.0, 5.0))
	if seq.upper() != 4 or seq.value_T(2).x() != 5.0:
		return "Sequence InsertBefore failed"
	seq.set_value_v(2, OcgGpPnt.from_6(6.0, 6.0, 6.0))
	if seq.value_T(2).y() != 6.0:
		return "Sequence SetValue failed"
	seq.remove_2(2)
	if seq.upper() != 3 or seq.value_T(2).x() != 1.0:
		return "Sequence Remove failed"
	seq.clear(OcgNCollectionBaseAllocator.common_base_allocator())
	if seq.upper() != 0:
		return "Sequence Clear failed"
	return "OK"


func test_sequence_iterator_operations() -> String:
	var seq := OcgNCollectionSequenceGpPnt.new()
	seq.append_N(OcgGpPnt.from_6(1.0, 0.0, 0.0))
	seq.append_N(OcgGpPnt.from_6(2.0, 0.0, 0.0))
	seq.append_N(OcgGpPnt.from_6(3.0, 0.0, 0.0))
	# insert_after_n uses the C++ InsertAfter(Iterator&, item): position is
	# 0-based, so inserting after position 0 puts the new element second.
	seq.insert_after_n(0, OcgGpPnt.from_6(4.0, 0.0, 0.0))
	if seq.upper() != 4:
		return "insert_after_n did not grow the sequence"
	if seq.value_T(2).x() != 4.0:
		return "insert_after_n(0, item) did not insert second: %s" % seq.value_T(2).x()
	# remove_Z uses the C++ Remove(Iterator&): 0-based position, so removing
	# position 1 drops the element inserted above.
	seq.remove_Z(1)
	if seq.upper() != 3:
		return "remove_Z did not shrink the sequence"
	if seq.value_T(1).x() != 1.0 or seq.value_T(2).x() != 2.0 or seq.value_T(3).x() != 3.0:
		return "remove_Z(1) removed the wrong element"
	# The iterator-based overloads coexist with the index-based ones
	# (remove_2/remove_9 are 1-based OCCT indices).
	seq.remove_2(2)
	if seq.upper() != 2 or seq.value_T(1).x() != 1.0 or seq.value_T(2).x() != 3.0:
		return "index-based remove_2(2) wrong: upper=%s" % seq.upper()
	seq.clear(OcgNCollectionBaseAllocator.common_base_allocator())
	return "OK"


func test_list_iterator_operations() -> String:
	var lst := OcgNCollectionListDouble.new()
	lst.append_y(1.5)
	lst.append_y(2.5)
	lst.append_y(3.5)
	# insert_after_b(item, position): List::InsertAfter(Iterator&, item) with a
	# 0-based position, so inserting after position 0 lands second.
	lst.insert_after_b(9.5, 0)
	lst.remove_first()
	if lst.first_k() != 9.5:
		return "insert_after_b(0) did not insert second: %s" % lst.first_k()
	lst.remove_first()
	if lst.first_k() != 2.5:
		return "List order wrong after inserts"
	# remove(position): List::Remove(Iterator&), 0-based. Remove the first
	# element and verify the 2.5 already consumed is gone.
	lst.append_y(7.5)
	lst.remove(0)
	if lst.first_k() != 3.5:
		return "remove(0) did not drop the first element: %s" % lst.first_k()
	lst.clear(OcgNCollectionBaseAllocator.common_base_allocator())
	return "OK"


func test_data_map_ascii_operations() -> String:
	var m := OcgNCollectionDataMapTCollectionAsciiStringTCollectionAsciiString.new()
	var key_a := OcgTCollectionAsciiString.from_f("alpha")
	var key_b := OcgTCollectionAsciiString.from_f("beta")
	var val_x := OcgTCollectionAsciiString.from_f("x")
	var val_y := OcgTCollectionAsciiString.from_f("y")
	if not m.bind_b(key_a, val_x):
		return "bind_b failed"
	if not m.bind_b(key_b, val_y):
		return "bind_b (2nd) failed"
	if m.find_m(key_a) != "x" or m.find_m(key_b) != "y":
		return "find_m: %s, %s" % [m.find_m(key_a), m.find_m(key_b)]
	if m.seek(key_a) != "x":
		return "seek: %s" % m.seek(key_a)
	# bound_b inserts and returns the bound value (V* return -> String).
	if m.bound_b(key_a, val_x) != "x":
		return "bound_b did not return the bound value"
	if not m.is_bound(key_a) or not m.is_bound(key_b):
		return "is_bound failed"
	if not m.un_bind(key_a) or m.is_bound(key_a):
		return "un_bind failed"
	# assign copies the other map's contents into this one.
	var other := OcgNCollectionDataMapTCollectionAsciiStringTCollectionAsciiString.new()
	other.bind_b(key_a, val_x)
	m.assign(other)
	if not m.is_bound(key_a) or m.find_m(key_a) != "x":
		return "assign did not copy key_a: %s" % m.find_m(key_a)
	# exchange swaps the two maps' contents.
	var m2 := OcgNCollectionDataMapTCollectionAsciiStringTCollectionAsciiString.new()
	m2.bind_b(key_b, val_y)
	m.exchange(m2)
	if m.is_bound(key_a) or not m.is_bound(key_b):
		return "exchange did not swap contents"
	m.clear_c(false)
	return "OK"


func test_shape_keyed_containers() -> String:
	var shape := OcgTopoDSShape.new()
	if shape == null:
		return "Failed to create TopoDS_Shape"
	var lst := OcgNCollectionListTopoDSShape.new()
	lst.append_4(shape)
	if lst.first_k() == null:
		return "List<Shape> First() returned null"

	var mp := OcgNCollectionMapTopoDSShapeTopToolsShapeMapHasher.new()
	if not mp.add_4(shape):
		return "Map<Shape> Add failed"
	if not mp.contains_i(shape):
		return "Map<Shape> Contains failed"
	if not mp.remove(shape) or mp.contains_i(shape):
		return "Map<Shape> Remove failed"

	var im := OcgNCollectionIndexedMapTopoDSShapeTopToolsShapeMapHasher.new()
	if im.add_4(shape) != 1:
		return "IndexedMap<Shape> Add failed"
	if im.find_index(shape) != 1:
		return "IndexedMap<Shape> FindIndex wrong"
	if im.find_key_T(1) == null:
		return "IndexedMap<Shape> FindKey returned null"

	var dm := OcgNCollectionIndexedDataMapTopoDSShapeDoubleTopToolsShapeMapHasher.new()
	if dm.add_c(shape, 3.5) != 1:
		return "IndexedDataMap<Shape, double> Add failed"
	if dm.find_from_key_i(shape) != 3.5 or dm.find_from_index_T(1) != 3.5:
		return "IndexedDataMap<Shape, double> Find failed"
	return "OK"


func test_vec3_double() -> String:
	var v := OcgNCollectionVec3Double.new()
	v.set_values_6(3.0, 4.0, 0.0)
	if v.x_k() != 3.0 or v.y_k() != 4.0 or v.z_k() != 0.0:
		return "Vec3 component access failed"
	if v.modulus() != 5.0:
		return "Vec3 Modulus failed: %s" % v.modulus()
	if v.square_modulus() != 25.0:
		return "Vec3 SquareModulus failed"
	var w := OcgNCollectionVec3Double.new()
	w.set_values_6(1.0, 0.0, 0.0)
	if v.dot(w) != 3.0:
		return "Vec3 Dot failed"
	var c := OcgNCollectionVec3Double.cross(v, w)
	if c == null or c.x_k() != 0.0 or c.y_k() != 0.0 or c.z_k() != -4.0:
		return "Vec3 Cross failed"
	return "OK"
