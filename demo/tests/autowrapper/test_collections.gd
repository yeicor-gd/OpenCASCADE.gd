extends Node


func test_array1_gp_pnt() -> String:
	var arr := OcgNcollectionArray1GpPnt.from_kPA(1, 3)
	if arr == null:
		return "Failed to create Array1<gp_Pnt>"
	if arr.Lower() != 1 or arr.Upper() != 3 or arr.Length() != 3:
		return "Array1 bounds wrong: lower=%s upper=%s length=%s" % [arr.Lower(), arr.Upper(), arr.Length()]
	if arr.IsEmpty():
		return "Array1 should not be empty"
	var p1 := OcgGpPnt.from_668(1.0, 2.0, 3.0)
	var p2 := OcgGpPnt.from_668(4.0, 5.0, 6.0)
	var p3 := OcgGpPnt.from_668(7.0, 8.0, 9.0)
	arr.SetValue(1, p1)
	arr.SetValue(2, p2)
	arr.SetValue(3, p3)
	if arr.Value(1).X() != 1.0 or arr.Value(2).Y() != 5.0 or arr.Value(3).Z() != 9.0:
		return "Array1 SetValue/Value roundtrip failed"
	if arr.ChangeValue(2).X() != 4.0:
		return "Array1 ChangeValue read-back failed"
	var p4 := OcgGpPnt.from_668(55.0, 0.0, 0.0)
	arr.SetValue(2, p4)
	if arr.Value(2).X() != 55.0:
		return "Array1 SetValue mutation failed"
	arr.Init(p1)
	if arr.Value(1).X() != 1.0 or arr.Value(3).Z() != 3.0:
		return "Array1 Init fill failed"
	return "OK"


func test_array2_gp_pnt() -> String:
	var arr := OcgNcollectionArray2GpPnt.from_vA4(1, 2, 3, 4)
	if arr == null:
		return "Failed to create Array2<gp_Pnt>"
	if arr.LowerRow() != 1 or arr.UpperRow() != 2 or arr.LowerCol() != 3 or arr.UpperCol() != 4:
		return "Array2 bounds wrong"
	if arr.RowLength() != 2 or arr.ColLength() != 2:
		return "Array2 lengths wrong"
	var p := OcgGpPnt.from_668(10.0, 20.0, 30.0)
	arr.SetValue(1, 3, p)
	if arr.Value(1, 3).X() != 10.0 or arr.Value(1, 3).Z() != 30.0:
		return "Array2 SetValue/Value roundtrip failed"
	return "OK"


func test_list_double() -> String:
	var lst := OcgNcollectionListDouble.new()
	if not lst.IsEmpty():
		return "List should start empty"
	lst.Append_yTv(1.5)
	lst.Append_yTv(2.5)
	if lst.Extent() != 2:
		return "List Extent wrong: %s" % lst.Extent()
	if lst.First() != 1.5 or lst.Last() != 2.5:
		return "List First/Last wrong"
	if not lst.Contains(1.5) or not lst.Contains(2.5):
		return "List Contains failed"
	if lst.Contains(9.9):
		return "List Contains false positive"
	lst.RemoveFirst()
	if lst.First() != 2.5:
		return "List RemoveFirst failed"
	lst.Clear()
	if not lst.IsEmpty():
		return "List Clear failed"
	return "OK"


func test_sequence_gp_pnt() -> String:
	var seq := OcgNcollectionSequenceGpPnt.new()
	var p1 := OcgGpPnt.from_668(1.0, 0.0, 0.0)
	var p2 := OcgGpPnt.from_668(0.0, 2.0, 0.0)
	seq.Append_ND3(p1)
	seq.Append_ND3(p2)
	if seq.Length() != 2:
		return "Sequence length wrong"
	if seq.First().X() != 1.0 or seq.Last().Y() != 2.0:
		return "Sequence First/Last wrong"
	var p0 := OcgGpPnt.from_668(0.0, 0.0, 3.0)
	seq.Prepend_ND3(p0)
	if seq.Length() != 3 or seq.First().Z() != 3.0:
		return "Sequence Prepend failed"
	if seq.Value(3).Y() != 2.0:
		return "Sequence Value wrong"
	seq.InsertBefore(2, OcgGpPnt.from_668(5.0, 5.0, 5.0))
	if seq.Length() != 4 or seq.Value(2).X() != 5.0:
		return "Sequence InsertBefore failed"
	seq.SetValue(2, OcgGpPnt.from_668(6.0, 6.0, 6.0))
	if seq.Value(2).Y() != 6.0:
		return "Sequence SetValue failed"
	seq.Remove(2)
	if seq.Length() != 3 or seq.Value(2).X() != 1.0:
		return "Sequence Remove failed"
	seq.Clear()
	if not seq.IsEmpty():
		return "Sequence Clear failed"
	return "OK"


func test_shape_keyed_containers() -> String:
	var shape := OcgTopodsShape.new()
	if shape == null:
		return "Failed to create TopoDS_Shape"
	var lst := OcgNcollectionListTopodsShape.new()
	lst.Append_48R(shape)
	if lst.Extent() != 1:
		return "List<Shape> Extent wrong"
	if not lst.Contains(shape):
		return "List<Shape> Contains failed"
	if lst.First() == null:
		return "List<Shape> First() returned null"

	var mp := OcgNcollectionMapTopodsShapeToptoolsShapemaphasher.new()
	if not mp.Add(shape):
		return "Map<Shape> Add failed"
	if not mp.Contains(shape) or mp.Extent() != 1:
		return "Map<Shape> Contains/Extent wrong"
	if not mp.Remove(shape) or not mp.IsEmpty():
		return "Map<Shape> Remove failed"

	var im := OcgNcollectionIndexedmapTopodsShapeToptoolsShapemaphasher.new()
	if im.Add(shape) != 1:
		return "IndexedMap<Shape> Add failed"
	if im.FindIndex(shape) != 1:
		return "IndexedMap<Shape> FindIndex wrong"
	if im.FindKey(1) == null:
		return "IndexedMap<Shape> FindKey returned null"

	var dm := OcgNcollectionIndexeddatamapTopodsShapeDoubleToptoolsShapemaphasher.new()
	if dm.Add(shape, 3.5) != 1:
		return "IndexedDataMap<Shape, double> Add failed"
	if dm.FindFromKey(shape) != 3.5 or dm.FindFromIndex(1) != 3.5:
		return "IndexedDataMap<Shape, double> Find failed"
	return "OK"


func test_vec3_double() -> String:
	var v := OcgNcollectionVec3Double.new()
	v.SetValues(3.0, 4.0, 0.0)
	if v.x() != 3.0 or v.y() != 4.0 or v.z() != 0.0:
		return "Vec3 component access failed"
	if v.Modulus() != 5.0:
		return "Vec3 Modulus failed: %s" % v.Modulus()
	if v.SquareModulus() != 25.0:
		return "Vec3 SquareModulus failed"
	var w := OcgNcollectionVec3Double.new()
	w.SetValues(1.0, 0.0, 0.0)
	if v.Dot(w) != 3.0:
		return "Vec3 Dot failed"
	var c := OcgNcollectionVec3Double.Cross(v, w)
	if c == null or c.x() != 0.0 or c.y() != 0.0 or c.z() != -4.0:
		return "Vec3 Cross failed"
	return "OK"
