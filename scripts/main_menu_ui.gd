extends Control
class_name GameMainMenuUI

signal host_pressed(nickname: String, skin: String, character_name: String, mode: String)
signal join_pressed(nickname: String, skin: String, address: String, character_name: String, mode: String)
signal quit_pressed
signal character_changed(character_name: String)

@onready var character_selector: OptionButton = $TopContainer/CharacterSelector
@onready var nick_input: LineEdit = $TopContainer/NickInput
@onready var server_address_input: LineEdit = $TopContainer/ServerAddress
@onready var skin_selector: OptionButton = $TopContainer/SkinSelector
@onready var mode_selector: OptionButton = $TopContainer/ModeSelector

var characters = ["Kyle", "Eric", "Donald", "Kristen", "Rochelle", "Vickie", "Connie", "Caleb", "Bethany", "Maia"]
var skins = ["Blue", "Yellow", "Green", "Red"]
var modes = ["Board", "Brawl", "Kart", "Party Mix"]

func _ready():
	_populate_characters()
	_populate_skins()
	_populate_modes()

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

func _populate_skins():
	skin_selector.clear()
	for skin_name in skins:
		skin_selector.add_item(skin_name)

func _populate_modes():
	mode_selector.clear()
	for mode_name in modes:
		mode_selector.add_item(mode_name)

func _get_selected_text(option_button: OptionButton, fallback: String) -> String:
	var selected_index = option_button.selected
	if selected_index >= 0:
		return option_button.get_item_text(selected_index)
	return fallback

func _get_selected_character() -> String:
	var idx = character_selector.selected
	if idx >= 0:
		return character_selector.get_item_text(idx).to_lower()
	return "kyle"

func _on_host_pressed():
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	var character_name = _get_selected_character()
	var mode = get_mode()
		
	host_pressed.emit(nickname, skin, character_name, mode)

func _on_join_pressed():
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	var address = get_address()
	var character_name = _get_selected_character()
	var mode = get_mode()

	join_pressed.emit(nickname, skin, address, character_name, mode)

func _on_quit_pressed():
	quit_pressed.emit()

func show_menu():
	show()

func hide_menu():
	hide()

func is_menu_visible() -> bool:
	return visible

func get_nickname() -> String:
	return nick_input.text.strip_edges()

func get_skin() -> String:
	return _get_selected_text(skin_selector, "Blue").to_lower()

func get_address() -> String:
	var address = server_address_input.text.strip_edges()
	if address.is_empty():
		return "127.0.0.1"
	return address

func get_mode() -> String:
	return _get_selected_text(mode_selector, "Board")
