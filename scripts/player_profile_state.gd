class_name PlayerProfileState
extends RefCounted

var profile_id: String = ""
var display_name: String = ""
var avatar_id: String = "kyle"
var plot_id: int = -1
var home: Dictionary = {}
var storage: Dictionary = {}
var service_flags: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"avatar_id": avatar_id,
		"plot_id": plot_id,
		"home": home.duplicate(true),
		"storage": storage.duplicate(true),
		"service_flags": service_flags.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	profile_id = str(data.get("profile_id", ""))
	display_name = str(data.get("display_name", ""))
	avatar_id = str(data.get("avatar_id", "kyle"))
	plot_id = int(data.get("plot_id", -1))
	home = data.get("home", {}).duplicate(true)
	storage = data.get("storage", {}).duplicate(true)
	service_flags = data.get("service_flags", {}).duplicate(true)
