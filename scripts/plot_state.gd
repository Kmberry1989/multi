class_name PlotState
extends RefCounted

var plot_id: int = -1
var owner_profile_id: String = ""
var center: Vector3 = Vector3.ZERO
var size: Vector2 = Vector2(10.0, 10.0)
var home: Dictionary = {}
var placed_objects: Array = []
var crops: Array = []

func to_dict() -> Dictionary:
	return {
		"plot_id": plot_id,
		"owner_profile_id": owner_profile_id,
		"center": [center.x, center.y, center.z],
		"size": [size.x, size.y],
		"home": home.duplicate(true),
		"placed_objects": placed_objects.duplicate(true),
		"crops": crops.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	plot_id = int(data.get("plot_id", -1))
	owner_profile_id = str(data.get("owner_profile_id", ""))
	var center_data = data.get("center", [0.0, 0.0, 0.0])
	center = Vector3(
		float(center_data[0]) if center_data.size() > 0 else 0.0,
		float(center_data[1]) if center_data.size() > 1 else 0.0,
		float(center_data[2]) if center_data.size() > 2 else 0.0
	)
	var size_data = data.get("size", [10.0, 10.0])
	size = Vector2(
		float(size_data[0]) if size_data.size() > 0 else 10.0,
		float(size_data[1]) if size_data.size() > 1 else 10.0
	)
	home = data.get("home", {}).duplicate(true)
	placed_objects = data.get("placed_objects", []).duplicate(true)
	crops = data.get("crops", []).duplicate(true)
