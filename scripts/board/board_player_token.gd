extends Node3D
## Visual representation of a player on the board.
## Handles movement animations and UI feedback.

class_name BoardPlayerToken

signal movement_completed

@export var animation_duration := 0.5
@export var token_color := Color.BLUE
@export var hover_height := 0.5

var player_id: int = -1
var player_name: String = ""
var current_space_index: int = 0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	if not mesh:
		_create_default_mesh()
	if not label:
		_create_default_label()

## Initialize the token with player info
func setup(id: int, p_name: String, color: Color) -> void:
	player_id = id
	player_name = p_name
	token_color = color
	
	if label:
		label.text = name
	
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.set_surface_override_material(0, mat)

## Smoothly move token from current position to new position
func move_to_position(target_pos: Vector3) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_pos, animation_duration)
	await tween.finished
	movement_completed.emit()

## Update space index (called when moved on board)
func set_space_index(index: int) -> void:
	current_space_index = index

func _create_default_mesh() -> void:
	mesh = MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var sphere = SphereMesh.new()
	sphere.radii = Vector3(0.3, 0.3, 0.3)
	mesh.mesh = sphere
	add_child(mesh)

func _create_default_label() -> void:
	label = Label3D.new()
	label.name = "Label3D"
	label.position.y = hover_height + 0.5
	label.text = player_name
	add_child(label)
