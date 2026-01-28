extends Control
class_name GameMainMenuUI

signal host_pressed(skin: String, character_name: String)
signal join_pressed(skin: String, address: String, character_name: String)
signal quit_pressed
signal character_changed(character_name: String)

@onready var character_select_ui: CharacterSelectUI = $CharacterSelectUI

var selected_character: String = "Kyle"

func _ready():
	if character_select_ui:
		character_select_ui.character_selected.connect(_on_character_selected)
		character_select_ui.host_pressed.connect(_on_host_pressed)
		character_select_ui.join_pressed.connect(_on_join_pressed)
		character_select_ui.quit_pressed.connect(_on_quit_pressed)

func _on_character_selected(character_name: String) -> void:
	selected_character = character_name
	character_changed.emit(character_name)

func _on_host_pressed() -> void:
	var skin = "blue"
	var character_name = selected_character
	if character_name.is_empty():
		character_name = "kyle"
	host_pressed.emit(skin, character_name)

func _on_join_pressed() -> void:
	var skin = "blue"
	var address = "127.0.0.1"
	var character_name = selected_character
	if character_name.is_empty():
		character_name = "kyle"
	join_pressed.emit(skin, address, character_name)

func _on_quit_pressed() -> void:
	quit_pressed.emit()

func get_selected_character() -> String:
	return selected_character

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

