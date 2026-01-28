extends TextureRect
class_name CharacterPortraitButton

signal selected
signal hovered
signal unhovered

@export var character_name: String = ""
@export var portrait_path: String = ""

@onready var hover_base: TextureRect = $HoverBase
@onready var selected_flash: TextureRect = $SelectedFlash
@onready var selection_anim: AnimationPlayer = $SelectionAnim

var is_hovered: bool = false
var is_selected: bool = false

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Load portrait assets
	if portrait_path.is_empty():
		portrait_path = (
			"res://assets/characters/player/Portraits/%s.png" % character_name.to_upper()
		)
	
	if ResourceLoader.exists(portrait_path):
		texture = load(portrait_path)
	
	# Load hover and selected overlays
	var hover_overlay = load("res://assets/characters/player/Portraits/HOVERED.png")
	var selected_overlay = load("res://assets/characters/player/Portraits/SELECTED.png")
	
	if hover_overlay:
		hover_base.texture = hover_overlay
	if selected_overlay:
		selected_flash.texture = selected_overlay
	
	_setup_animations()

func _setup_animations() -> void:
	var anim = Animation.new()
	anim.length = 0.3
	
	# Flash animation for selection
	var track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "selected_flash:modulate")
	anim.track_insert_key(track_idx, 0.0, Color.WHITE)
	anim.track_insert_key(track_idx, 0.15, Color.WHITE)
	anim.track_insert_key(track_idx, 0.3, Color(1, 1, 1, 0))
	
	var lib
	if selection_anim.has_animation_library(""):
		lib = selection_anim.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		selection_anim.add_animation_library("", lib)
	
	lib.add_animation("flash", anim)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_selected(true)
		selected.emit()

func _on_mouse_entered() -> void:
	if not is_selected:
		set_hovered(true)
		hovered.emit()

func _on_mouse_exited() -> void:
	set_hovered(false)
	unhovered.emit()

func set_hovered(_hovered: bool) -> void:
	is_hovered = _hovered
	if hover_base:
		hover_base.visible = _hovered

func set_selected(_selected: bool) -> void:
	is_selected = _selected
	if selected_flash:
		if _selected:
			selected_flash.visible = true
			selection_anim.play("flash")
		else:
			selected_flash.visible = false

func get_character_name() -> String:
	return character_name
