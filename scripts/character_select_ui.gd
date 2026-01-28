extends Control
class_name CharacterSelectUI

signal character_selected(character_name: String)
signal selection_confirmed(character_name: String)
signal host_pressed
signal join_pressed
signal quit_pressed

@onready var character_grid: GridContainer = $CharacterGridContainer
@onready var selected_label: Label = $SelectedCharacterDisplay/SelectedLabel
@onready var character_image: TextureRect = $SelectedCharacterDisplay/CharacterImage
@onready var confirm_button: Button = $ConfirmButton
@onready var host_button: Button = $BottomButtonContainer/HostButton
@onready var join_button: Button = $BottomButtonContainer/JoinButton
@onready var quit_button: Button = $BottomButtonContainer/QuitButton

var character_portrait_button = preload("res://scenes/ui/character_portrait_button.tscn")
var characters = ["Kyle", "Eric", "Donald", "Kristen", "Rochelle", "Vickie", "Connie", "Caleb", "Bethany", "Maia"]
var selected_character: String = ""

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	host_button.pressed.connect(func(): host_pressed.emit())
	join_button.pressed.connect(func(): join_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())
	_setup_character_buttons()

func _setup_character_buttons() -> void:
	for character in characters:
		var button = character_portrait_button.instantiate() as CharacterPortraitButton
		button.character_name = character
		button.selected.connect(func(): _on_character_button_selected(character))
		character_grid.add_child(button)

func _on_character_button_selected(character_name: String) -> void:
	selected_character = character_name
	character_selected.emit(character_name)
	selected_label.text = "Selected: %s" % character_name
	
	# Update the displayed character image
	var ready_image_path = "res://assets/characters/player/ReadySelect/%s_READY.png" % character_name.to_upper()
	if ResourceLoader.exists(ready_image_path):
		character_image.texture = load(ready_image_path)
	
	confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if selected_character:
		selection_confirmed.emit(selected_character)

func get_selected_character() -> String:
	return selected_character

func reset() -> void:
	selected_character = ""
	selected_label.text = "Selected: None"
	character_image.texture = null
	confirm_button.disabled = true
	
	# Reset all button states
	for button in character_grid.get_children():
		if button is CharacterPortraitButton:
			button.set_selected(false)
			button.set_hovered(false)
