class_name NpcRoutineState
extends RefCounted

var npc_id: String = ""
var display_name: String = ""
var role: String = ""
var day_position: Vector3 = Vector3.ZERO
var evening_position: Vector3 = Vector3.ZERO
var active_start_hour: int = 8
var active_end_hour: int = 18
var current_zone: String = "town_square"

func to_dict() -> Dictionary:
	return {
		"npc_id": npc_id,
		"display_name": display_name,
		"role": role,
		"day_position": [day_position.x, day_position.y, day_position.z],
		"evening_position": [evening_position.x, evening_position.y, evening_position.z],
		"active_start_hour": active_start_hour,
		"active_end_hour": active_end_hour,
		"current_zone": current_zone,
	}

func from_dict(data: Dictionary) -> void:
	npc_id = str(data.get("npc_id", ""))
	display_name = str(data.get("display_name", ""))
	role = str(data.get("role", ""))
	var day_data = data.get("day_position", [0.0, 0.0, 0.0])
	day_position = Vector3(
		float(day_data[0]) if day_data.size() > 0 else 0.0,
		float(day_data[1]) if day_data.size() > 1 else 0.0,
		float(day_data[2]) if day_data.size() > 2 else 0.0
	)
	var evening_data = data.get("evening_position", [0.0, 0.0, 0.0])
	evening_position = Vector3(
		float(evening_data[0]) if evening_data.size() > 0 else 0.0,
		float(evening_data[1]) if evening_data.size() > 1 else 0.0,
		float(evening_data[2]) if evening_data.size() > 2 else 0.0
	)
	active_start_hour = int(data.get("active_start_hour", 8))
	active_end_hour = int(data.get("active_end_hour", 18))
	current_zone = str(data.get("current_zone", "town_square"))
