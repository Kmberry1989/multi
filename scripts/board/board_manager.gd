extends Node3D
class_name BoardManager

@export var path_node: NodePath = NodePath("Path")
@export var spaces_container: NodePath = NodePath("Spaces")
@export var loop_path := true

var path: Path3D
var spaces: Array[Node3D] = []

func _ready() -> void:
	path = get_node_or_null(path_node)
	spaces = _collect_spaces()
	_ensure_default_curve()

func get_space_count() -> int:
	return spaces.size()

func get_space_position(index: int) -> Vector3:
	if spaces.is_empty():
		return global_position

	var clamped_index = _wrap_index(index)
	return spaces[clamped_index].global_position

func get_space_type(index: int) -> String:
	if spaces.is_empty():
		return "normal"

	var clamped_index = _wrap_index(index)
	var space = spaces[clamped_index]
	if space.has_meta("space_type"):
		return str(space.get_meta("space_type"))
	return "normal"

func get_next_index(current_index: int, steps: int) -> int:
	if spaces.is_empty():
		return 0
	return _wrap_index(current_index + steps)

func _collect_spaces() -> Array[Node3D]:
	var container = get_node_or_null(spaces_container)
	if container == null:
		return []

	var collected: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D:
			collected.append(child)
	return collected

func _wrap_index(index: int) -> int:
	if spaces.is_empty():
		return 0
	if loop_path:
		return index % spaces.size()
	return clamp(index, 0, spaces.size() - 1)

func _ensure_default_curve() -> void:
	if path == null:
		return

	if path.curve == null:
		path.curve = Curve3D.new()

	if path.curve.point_count >= 2:
		return

	path.curve.clear_points()
	path.curve.add_point(Vector3(0, 0, 0))
	path.curve.add_point(Vector3(4, 0, 0))
	path.curve.add_point(Vector3(4, 0, 4))
	path.curve.add_point(Vector3(0, 0, 4))
	path.curve.add_point(Vector3(0, 0, 0))
