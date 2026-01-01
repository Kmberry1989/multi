extends Node
class_name MinigameManager

signal minigame_started(minigame_name: String)
signal minigame_finished(minigame_name: String, results: Dictionary)

@export var minigame_scene_dir := "res://scenes/minigames"
@export var game_director_path: NodePath

var _minigame_scenes: Dictionary = {}
var _active_minigame: Node


func _ready() -> void:
	_load_minigame_scenes()


func _load_minigame_scenes() -> void:
	_minigame_scenes.clear()

	var dir = DirAccess.open(minigame_scene_dir)
	if dir == null:
		push_warning("MinigameManager: Unable to open minigame directory: %s" % minigame_scene_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tscn":
			var scene_path = minigame_scene_dir.path_join(file_name)
			var scene = load(scene_path)
			if scene is PackedScene:
				_minigame_scenes[file_name.get_basename()] = scene
			else:
				push_warning("MinigameManager: Failed to load scene: %s" % scene_path)
		file_name = dir.get_next()

	dir.list_dir_end()


func get_minigame_names() -> PackedStringArray:
	return PackedStringArray(_minigame_scenes.keys())


func start_minigame(minigame_name: String) -> void:
	if not _minigame_scenes.has(minigame_name):
		push_warning("MinigameManager: Minigame not found: %s" % minigame_name)
		return

	_cleanup_active_minigame()

	var instance = _minigame_scenes[minigame_name].instantiate()
	_active_minigame = instance
	add_child(instance)

	if instance.has_signal("end"):
		instance.connect("end", Callable(self, "_on_minigame_end").bind(minigame_name))
	else:
		push_warning("MinigameManager: Minigame %s missing 'end(results)' signal" % minigame_name)

	if instance.has_method("start"):
		instance.call("start")
	else:
		push_warning("MinigameManager: Minigame %s missing 'start()' method" % minigame_name)

	minigame_started.emit(minigame_name)


func _on_minigame_end(results: Dictionary, minigame_name: String) -> void:
	minigame_finished.emit(minigame_name, results)
	_notify_game_director(minigame_name, results)
	_cleanup_active_minigame()


func _notify_game_director(minigame_name: String, results: Dictionary) -> void:
	var director = _resolve_game_director()
	if director == null:
		push_warning("MinigameManager: GameDirector not found; cannot submit results")
		return

	if director.has_method("on_minigame_completed"):
		director.call("on_minigame_completed", minigame_name, results)
		return

	if director.has_method("handle_minigame_results"):
		director.call("handle_minigame_results", minigame_name, results)
		return

	push_warning("MinigameManager: GameDirector missing result handler method")


func _resolve_game_director() -> Node:
	if game_director_path != NodePath():
		var resolved = get_node_or_null(game_director_path)
		if resolved:
			return resolved

	var grouped = get_tree().get_first_node_in_group("game_director")
	if grouped:
		return grouped

	return get_tree().root.find_child("GameDirector", true, false)


func _cleanup_active_minigame() -> void:
	if _active_minigame and is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null
