class_name TownState
extends RefCounted

var day: int = 1
var minute_of_day: int = 480
var player_profiles: Dictionary = {}
var plots: Array = []
var npcs: Array = []

func to_dict() -> Dictionary:
	return {
		"day": day,
		"minute_of_day": minute_of_day,
		"player_profiles": player_profiles.duplicate(true),
		"plots": plots.duplicate(true),
		"npcs": npcs.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minute_of_day = int(data.get("minute_of_day", 480))
	player_profiles = data.get("player_profiles", {}).duplicate(true)
	plots = data.get("plots", []).duplicate(true)
	npcs = data.get("npcs", []).duplicate(true)
