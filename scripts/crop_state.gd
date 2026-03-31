class_name CropState
extends RefCounted

var crop_id: String = ""
var crop_type: String = ""
var plot_id: int = -1
var position: Vector3 = Vector3.ZERO
var growth_stage: int = 0
var planted_day: int = 1
var planted_minute: int = 0
var last_watered_day: int = 1
var last_watered_minute: int = -1
var ready_to_harvest: bool = false

func to_dict() -> Dictionary:
	return {
		"crop_id": crop_id,
		"crop_type": crop_type,
		"plot_id": plot_id,
		"position": [position.x, position.y, position.z],
		"growth_stage": growth_stage,
		"planted_day": planted_day,
		"planted_minute": planted_minute,
		"last_watered_day": last_watered_day,
		"last_watered_minute": last_watered_minute,
		"ready_to_harvest": ready_to_harvest,
	}

func from_dict(data: Dictionary) -> void:
	crop_id = str(data.get("crop_id", ""))
	crop_type = str(data.get("crop_type", ""))
	plot_id = int(data.get("plot_id", -1))
	var position_data = data.get("position", [0.0, 0.0, 0.0])
	position = Vector3(
		float(position_data[0]) if position_data.size() > 0 else 0.0,
		float(position_data[1]) if position_data.size() > 1 else 0.0,
		float(position_data[2]) if position_data.size() > 2 else 0.0
	)
	growth_stage = int(data.get("growth_stage", 0))
	planted_day = int(data.get("planted_day", 1))
	planted_minute = int(data.get("planted_minute", 0))
	last_watered_day = int(data.get("last_watered_day", 1))
	last_watered_minute = int(data.get("last_watered_minute", -1))
	ready_to_harvest = bool(data.get("ready_to_harvest", false))
