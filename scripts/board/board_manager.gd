extends Node3D
## Manages board layout, spaces, pathfinding, and space metadata.
## Supports customizable space types and circular/linear board paths.
class_name BoardManager

@export var path_node: NodePath = NodePath("Path")
@export var spaces_container: NodePath = NodePath("Spaces")
@export var loop_path := true
@export var space_spacing := 2.0
@export var visualize_spaces := true

var path: Path3D
var spaces: Array[Node3D] = []
var space_visuals: Dictionary = {}  # Maps space index to visual mesh

func _ready() -> void:
	path = get_node_or_null(path_node)
	spaces = _collect_spaces()
	_ensure_default_spaces_if_empty()
	_ensure_default_curve()
	
	if visualize_spaces:
		_create_space_visuals()

## Get total number of spaces on the board
func get_space_count() -> int:
	return spaces.size()

## Get world position of a specific space
func get_space_position(index: int) -> Vector3:
	if spaces.is_empty():
		return global_position

	var clamped_index = _wrap_index(index)
	return spaces[clamped_index].global_position

## Get the type of a space (normal, item, minigame, bonus, trap)
func get_space_type(index: int) -> String:
	if spaces.is_empty():
		return "normal"

	var clamped_index = _wrap_index(index)
	var space = spaces[clamped_index]
	if space.has_meta("space_type"):
		return str(space.get_meta("space_type"))
	return "normal"

## Calculate next index after moving X steps
func get_next_index(current_index: int, steps: int) -> int:
	if spaces.is_empty():
		return 0
	return _wrap_index(current_index + steps)

## Collect all space markers from the container
func _collect_spaces() -> Array[Node3D]:
	var container = get_node_or_null(spaces_container)
	if container == null:
		return []

	var collected: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D:
			collected.append(child)
	return collected

## Handle wrapping for circular/linear boards
func _wrap_index(index: int) -> int:
	if spaces.is_empty():
		return 0
	if loop_path:
		return index % spaces.size()
	return clamp(index, 0, spaces.size() - 1)

## Create default spaces if none exist
func _ensure_default_spaces_if_empty() -> void:
	if not spaces.is_empty():
		return
	
	var container = get_node_or_null(spaces_container)
	if container == null:
		container = Node3D.new()
		container.name = "Spaces"
		add_child(container)
	
	# Create 8 default spaces in a square pattern
	var space_types = ["bonus", "item", "minigame", "bonus", "item", "minigame", "bonus", "item"]
	var positions = [
		Vector3(0, 0, 0),
		Vector3(2, 0, 0),
		Vector3(4, 0, 0),
		Vector3(4, 0, 2),
		Vector3(4, 0, 4),
		Vector3(2, 0, 4),
		Vector3(0, 0, 4),
		Vector3(0, 0, 2),
	]
	
	for i in range(positions.size()):
		var space = Marker3D.new()
		space.name = "Space%02d" % (i + 1)
		space.position = positions[i]
		space.set_meta("space_type", space_types[i])
		container.add_child(space)
	
	spaces = _collect_spaces()

## Create visual representation for each space
func _create_space_visuals() -> void:
	var container = get_node_or_null(spaces_container)
	if not container:
		return
	
	# Create a visual child node for each space
	for i in range(spaces.size()):
		var space = spaces[i]
		var space_type = get_space_type(i)
		var color = _get_space_color(space_type)
		
		# Create a small cube to represent the space
		var visual = MeshInstance3D.new()
		visual.name = "Visual_%s" % space_type
		visual.position = Vector3(0, 0.1, 0)  # Slightly above marker
		
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3(0.6, 0.2, 0.6)
		visual.mesh = cube_mesh
		
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color * 0.5
		visual.set_surface_override_material(0, material)
		
		space.add_child(visual)
		space_visuals[i] = visual

## Get color for space type
func _get_space_color(space_type: String) -> Color:
	match space_type:
		"item":
			return Color.YELLOW
		"minigame":
			return Color.CYAN
		"bonus":
			return Color.GREEN
		"trap":
			return Color.RED
		_:
			return Color.WHITE

## Ensure board path curve exists
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
