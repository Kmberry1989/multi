class_name PlacedObjectState
extends RefCounted

var object_id: String = ""
var item_id: String = ""
var owner_profile_id: String = ""
var plot_id: int = -1
var zone: String = "yard"
var position: Vector3 = Vector3.ZERO
var rotation_degrees: float = 0.0
var footprint: Vector2 = Vector2.ONE

func to_dict() -> Dictionary:
	return {
		"object_id": object_id,
		"item_id": item_id,
		"owner_profile_id": owner_profile_id,
		"plot_id": plot_id,
		"zone": zone,
		"position": [position.x, position.y, position.z],
		"rotation_degrees": rotation_degrees,
		"footprint": [footprint.x, footprint.y],
	}

func from_dict(data: Dictionary) -> void:
	object_id = str(data.get("object_id", ""))
	item_id = str(data.get("item_id", ""))
	owner_profile_id = str(data.get("owner_profile_id", ""))
	plot_id = int(data.get("plot_id", -1))
	zone = str(data.get("zone", "yard"))
	var position_data = data.get("position", [0.0, 0.0, 0.0])
	position = Vector3(
		float(position_data[0]) if position_data.size() > 0 else 0.0,
		float(position_data[1]) if position_data.size() > 1 else 0.0,
		float(position_data[2]) if position_data.size() > 2 else 0.0
	)
	rotation_degrees = float(data.get("rotation_degrees", 0.0))
	var footprint_data = data.get("footprint", [1.0, 1.0])
	footprint = Vector2(
		float(footprint_data[0]) if footprint_data.size() > 0 else 1.0,
		float(footprint_data[1]) if footprint_data.size() > 1 else 1.0
	)
