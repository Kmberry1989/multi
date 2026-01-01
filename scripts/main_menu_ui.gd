extends Control
class_name GameMainMenuUI

signal host_pressed(skin: String, character_name: String)
signal join_pressed(skin: String, address: String, character_name: String)
signal quit_pressed
signal character_changed(character_name: String)

@onready var character_selector: OptionButton = $TopContainer/CharacterSelector
var characters = ["Kyle", "Eric", "Donald", "Kristen", "Rochelle", "Vickie", "Connie", "Caleb", "Bethany", "Maia"]

func _ready():
	_populate_characters()

func _populate_characters():
	character_selector.clear()
	for char_name in characters:
		character_selector.add_item(char_name)
	
	if not character_selector.item_selected.is_connected(_on_character_selected):
		character_selector.item_selected.connect(_on_character_selected)
	
	# Emit initial selection deferred to ensure listeners are ready
	call_deferred("_emit_initial_selection")

func _emit_initial_selection():
	if character_selector.item_count > 0:
		_on_character_selected(0)

func _on_character_selected(index: int):
	var char_name = character_selector.get_item_text(index).to_lower()
	character_changed.emit(char_name)


func _on_host_pressed():
	var skin = "blue"
	var idx = character_selector.selected
	var character_name = "kyle"
	if idx >= 0:
		character_name = character_selector.get_item_text(idx).to_lower()
		
	host_pressed.emit(skin, character_name)

func _on_join_pressed():
	var skin = "blue"
	var address = "127.0.0.1"
	var idx = character_selector.selected
	var character_name = "kyle"
	if idx >= 0:
		character_name = character_selector.get_item_text(idx).to_lower()

	join_pressed.emit(skin, address, character_name)

func _on_quit_pressed():
	quit_pressed.emit()

func show_menu():
	show()

func hide_menu():
	hide()

func is_menu_visible() -> bool:
	return visible

func get_skin() -> String:
	return "blue"

func get_address() -> String:
	return "127.0.0.1"
