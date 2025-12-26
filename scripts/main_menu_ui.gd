extends Control
class_name MainMenuUI

signal host_pressed(nickname: String, skin: String)
signal join_pressed(nickname: String, skin: String, address: String)
signal quit_pressed

@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput

func _ready():
	pass

func _on_host_pressed():
	var nickname = nick_input.text.strip_edges()
	# Simplified: single field for nickname. Use default skin.
	var skin = "blue"
	host_pressed.emit(nickname, skin)

func _on_join_pressed():
	var nickname = nick_input.text.strip_edges()
	# Simplified: single field for nickname. Use default skin and local address.
	var skin = "blue"
	var address = "127.0.0.1"
	join_pressed.emit(nickname, skin, address)

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
	return "blue"

func get_address() -> String:
	return "127.0.0.1"
