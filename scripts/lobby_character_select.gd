extends Control
class_name LobbyCharacterSelect

signal character_confirmed(character_name: String)
signal players_ready(p1_char: String, p2_char: String)

@onready var character_select_ui: CharacterSelectUI = $CharacterSelectUI
@onready var player_ready_ui: PlayerReadyUI = $PlayerReadyUI

var p1_character: String = ""
var p2_character: String = ""
var is_p1: bool = true

func _ready() -> void:
	character_select_ui.selection_confirmed.connect(_on_character_confirmed)
	player_ready_ui.animation_finished.connect(_on_ready_animation_finished)

func show_character_select(is_player1: bool = true) -> void:
	is_p1 = is_player1
	character_select_ui.reset()
	character_select_ui.visible = true
	player_ready_ui.visible = false

func show_both_players_ready(p1: String, p2: String) -> void:
	p1_character = p1
	p2_character = p2
	character_select_ui.visible = false
	player_ready_ui.visible = true
	player_ready_ui.show_ready_screen(p1, p2)

func _on_character_confirmed(character_name: String) -> void:
	if is_p1:
		p1_character = character_name
	else:
		p2_character = character_name
	
	character_confirmed.emit(character_name)

func _on_ready_animation_finished() -> void:
	players_ready.emit(p1_character, p2_character)
