extends Node


func test_nested_enum_constants() -> String:
	if OcgGpDir.D.X != 0:
		return "gp_Dir::D.X expected 0 got %s" % OcgGpDir.D.X
	if OcgGpDir.D.Y != 1:
		return "gp_Dir::D.Y expected 1 got %s" % OcgGpDir.D.Y
	if OcgGpDir.D.NZ != 5:
		return "gp_Dir::D.NZ expected 5 got %s" % OcgGpDir.D.NZ
	if OcgGpDir2d.D.X != 0:
		return "gp_Dir2d::D.X expected 0 got %s" % OcgGpDir2d.D.X
	return "OK"


func test_standalone_enum_constants() -> String:
	if OcgEnums.GeomAbs_Shape.GeomAbs_C0 != 0:
		return "GeomAbs_Shape.GeomAbs_C0 expected 0 got %s" % OcgEnums.GeomAbs_Shape.GeomAbs_C0
	if OcgEnums.GeomAbs_Shape.GeomAbs_CN != 6:
		return "GeomAbs_Shape.GeomAbs_CN expected 6 got %s" % OcgEnums.GeomAbs_Shape.GeomAbs_CN
	if OcgEnums.Quantity_TypeOfColor.Quantity_TOC_RGB != 0:
		return "Quantity_TOC_RGB expected 0 got %s" % OcgEnums.Quantity_TypeOfColor.Quantity_TOC_RGB
	return "OK"


func test_enum_as_method_argument() -> String:
	var col := OcgQuantityColor.from_i(OcgEnums.Quantity_NameOfColor.Quantity_NOC_RED)
	if col == null:
		return "from_iQM(Quantity_NOC_RED) failed"
	var mname := col.name_k()
	if mname != OcgEnums.Quantity_NameOfColor.Quantity_NOC_RED:
		return "Name_kuK expected Quantity_NOC_RED got %s" % mname
	var name_str := OcgQuantityColor.string_name(OcgEnums.Quantity_NameOfColor.Quantity_NOC_BLUE)
	if name_str != "BLUE":
		return "StringName(Quantity_NOC_BLUE) expected BLUE got %s" % name_str
	return "OK"


func test_nested_enum_cross_class() -> String:
	var ax := OcgGpAx1.from_K(OcgGpDir.D.X)
	if ax == null:
		return "gp_Ax1(gp_Dir::D::X) failed"
	return "OK"
