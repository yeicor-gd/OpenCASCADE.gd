extends Node


var _sink_text: String = ""


func _on_sink(text: String) -> void:
	_sink_text += text


func test_probe() -> String:
	var maker := OcgBRepPrimAPIMakeBox.from_6(2.0, 3.0, 4.0)
	var solid := maker.solid()
	for i in range(200):
		_sink_text = ""
		var text: String = OcgBRepTools.dump(solid, Callable(self, "_on_sink"))
		if text.is_empty():
			return "dump %d produced empty text" % i
		if _sink_text != text:
			return "dump %d sink mismatch" % i
	return "OK"
