extends Node3D


func _ready() -> void:
	var points := OcgNcollectionArray2Double.from_kPA(2, 2)
	points.SetValue(0, 0, .1)
	points.SetValue(0, 1, .0)
	points.SetValue(1, 0, .2)
	points.SetValue(1, 1, .0)
	OcgGeomapiPointstobsplinesurface.from_jIc()
