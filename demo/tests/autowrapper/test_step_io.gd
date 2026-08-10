extends Node

const TOL := 1e-4


func _box_solid() -> OcgTopoDSShape:
	var box := OcgBRepPrimAPIMakeBox.from_6(10.0, 15.0, 20.0)
	if box == null:
		return null
	return box.solid()


func _make_writer() -> OcgSTEPControlWriter:
	var session_reader := OcgXSControlReader.from_f("STEP")
	if session_reader == null:
		return null
	var ws := session_reader.ws()
	if ws == null:
		return null
	return OcgSTEPControlWriter.from_v(ws, true)


func test_step_write_stream() -> String:
	var solid := _box_solid()
	if solid == null:
		return "Failed to build box solid"
	var writer := _make_writer()
	if writer == null:
		return "Failed to build STEPControlWriter from XSControl session"
	var mode := OcgEnums.STEPControl_StepModelType.STEPControl_ManifoldSolidBrep
	var tstat: int = writer.transfer_z(solid, mode, false, OcgMessageProgressRange.new())
	if tstat != OcgEnums.IFSelect_ReturnStatus.IFSelect_RetDone:
		return "STEP writer transfer expected RetDone got %s" % tstat
	var chunks: Array[String] = []
	var sink := func(text: String) -> void:
		chunks.append(text)
	var wstat: int = writer.write_stream(sink)
	if wstat != OcgEnums.IFSelect_ReturnStatus.IFSelect_RetDone:
		return "STEP writer write_stream expected RetDone got %s" % wstat
	if chunks.is_empty():
		return "write_stream produced no chunks"
	var content := "".join(chunks)
	if content.length() < 1000:
		return "STEP stream output too small (%s bytes)" % content.length()
	if not content.contains("ISO-10303-21"):
		return "STEP output missing ISO-10303-21 header"
	if not content.contains("PRODUCT"):
		return "STEP output missing PRODUCT entity"
	return "OK"


func test_step_transfer_asis_mode() -> String:
	var solid := _box_solid()
	if solid == null:
		return "Failed to build box solid"
	var writer := _make_writer()
	if writer == null:
		return "Failed to build STEPControlWriter from XSControl session"
	var mode := OcgEnums.STEPControl_StepModelType.STEPControl_AsIs
	var tstat: int = writer.transfer_z(solid, mode, false, OcgMessageProgressRange.new())
	if tstat != OcgEnums.IFSelect_ReturnStatus.IFSelect_RetDone:
		return "STEP writer AsIs transfer expected RetDone got %s" % tstat
	var chunks: Array[String] = []
	var sink := func(text: String) -> void:
		chunks.append(text)
	if writer.write_stream(sink) != OcgEnums.IFSelect_ReturnStatus.IFSelect_RetDone:
		return "STEP writer AsIs write_stream failed"
	if "".join(chunks).length() < 500:
		return "STEP AsIs stream output too small"
	return "OK"
