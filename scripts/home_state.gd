class_name HomeState
extends RefCounted

var door_position: Vector3 = Vector3.ZERO
var interior_origin: Vector3 = Vector3.ZERO
var interior_size: Vector2 = Vector2(4.0, 4.0)
var storage: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"door_position": [door_position.x, door_position.y, door_position.z],
		"interior_origin": [interior_origin.x, interior_origin.y, interior_origin.z],
		"interior_size": [interior_size.x, interior_size.y],
		"storage": storage.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	var door_data = data.get("door_position", [0.0, 0.0, 0.0])
	door_position = Vector3(
		float(door_data[0]) if door_data.size() > 0 else 0.0,
		float(door_data[1]) if door_data.size() > 1 else 0.0,
		float(door_data[2]) if door_data.size() > 2 else 0.0
	)
	var interior_data = data.get("interior_origin", [0.0, 0.0, 0.0])
	interior_origin = Vector3(
		float(interior_data[0]) if interior_data.size() > 0 else 0.0,
		float(interior_data[1]) if interior_data.size() > 1 else 0.0,
		float(interior_data[2]) if interior_data.size() > 2 else 0.0
	)
	var size_data = data.get("interior_size", [4.0, 4.0])
	interior_size = Vector2(
		float(size_data[0]) if size_data.size() > 0 else 4.0,
		float(size_data[1]) if size_data.size() > 1 else 4.0
	)
	storage = data.get("storage", {}).duplicate(true)
