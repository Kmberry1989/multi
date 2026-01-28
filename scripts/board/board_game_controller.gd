extends Node3D
## Main board game orchestrator - manages board state, player tokens, and flow.
## Integrates with GameDirector for state management and game mode transitions.

class_name BoardGameController

signal board_game_started
signal board_game_ended(winners: Array)

@export var board_scene: PackedScene
@export var auto_start := false
@export var rounds_per_game := 3

var board_manager: BoardManager
var turn_manager: TurnManager
var space_events: BoardSpaceEvents
var board_ui: BoardUI
var game_director: GameDirector

var player_tokens: Dictionary = {}  # Maps player_id -> BoardPlayerToken
var game_active := false
var round_count := 0

func _ready() -> void:
	# Find or create board
	var board = find_child("Board", true, false)
	if not board:
		if board_scene:
			board = board_scene.instantiate()
			add_child(board)
		else:
			push_error("BoardGameController: No board scene configured")
			return
	
	# Setup managers
	board_manager = board.find_child("BoardManager", true, false)
	turn_manager = board.find_child("TurnManager", true, false)
	space_events = BoardSpaceEvents.new()
	space_events.name = "SpaceEvents"
	if turn_manager:
		turn_manager.add_child(space_events)
	
	# Setup UI
	var ui_canvas = find_child("BoardUI", true, false)
	if ui_canvas:
		board_ui = BoardUI.new()
		board_ui.name = "BoardUIControl"
		ui_canvas.add_child(board_ui)
		if turn_manager:
			board_ui.setup(turn_manager)
	
	# Connect to game director
	game_director = get_tree().root.get_child(0).find_child("GameDirector", true, false)
	if game_director:
		game_director.state_changed.connect(_on_game_state_changed)
	
	# Connect turn manager signals
	if turn_manager:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_finished.connect(_on_turn_finished)
		turn_manager.round_completed.connect(_on_round_completed)
	
	if board_ui:
		board_ui.roll_pressed.connect(_on_roll_button_pressed)
	
	if auto_start:
		start_board_game()

## Initialize board game with players
func start_board_game(players: Array = []) -> void:
	if not turn_manager or not board_manager:
		push_error("BoardGameController: Missing managers")
		return
	
	game_active = true
	round_count = 0
	
	# Get all connected players if none provided
	if players.is_empty():
		players = get_tree().get_nodes_in_group("players")
	
	# Register players
	turn_manager.reset()
	for i in range(players.size()):
		var player = players[i]
		turn_manager.register_player(player, 0)
		player.set_meta("board_score", 0)
		_create_player_token(player, i)
	
	board_game_started.emit()
	turn_manager.start_turn()

## Create visual token for player
func _create_player_token(player: Node, index: int) -> void:
	var token = BoardPlayerToken.new()
	token.name = "Token_%s" % player.name
	add_child(token)
	
	var player_name = player.get_meta("player_name") if player.has_meta("player_name") else "Player %d" % (index + 1)
	var color = _get_player_color(index)
	
	token.setup(int(player.name), player_name, color)
	token.global_position = board_manager.get_space_position(0)
	
	player_tokens[int(player.name)] = token

## Get distinct color for player by index
func _get_player_color(index: int) -> Color:
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.MAGENTA, Color.CYAN]
	return colors[index % colors.size()]

## Animate player token movement
func _animate_player_move(player: Node, _from_index: int, to_index: int) -> void:
	var player_id = int(player.name)
	if player_id not in player_tokens:
		return
	
	var token = player_tokens[player_id]
	var target_pos = board_manager.get_space_position(to_index)
	
	await token.move_to_position(target_pos)

## Callback when turn starts
func _on_turn_started(_player: Node, _round_num: int) -> void:
	pass  # UI handles this via BoardUI

## Callback when turn finishes
func _on_turn_finished(_player: Node, _round_num: int) -> void:
	# Delay before next turn
	await get_tree().create_timer(1.0).timeout
	turn_manager.start_turn()

## Callback when round completes
func _on_round_completed(round_num: int) -> void:
	round_count = round_num
	
	if round_count >= rounds_per_game:
		end_board_game()

## Callback when player lands on space
func _on_space_event_triggered(_player: Node, _space_type: String) -> void:
	# Token animation happens via turn_manager signals
	await get_tree().create_timer(0.5).timeout

## Callback when roll button is pressed
func _on_roll_button_pressed() -> void:
	if not game_active or not turn_manager:
		return
	
	var current_player = turn_manager.get_current_player()
	if current_player and current_player.get_multiplayer_authority() == multiplayer.get_unique_id():
		turn_manager.roll_current_player()

## Callback when game state changes
func _on_game_state_changed(new_state: int, _prev_state: int) -> void:
	if new_state == GameDirector.State.BOARD_TURN and not game_active:
		start_board_game()
	elif new_state != GameDirector.State.BOARD_TURN and game_active:
		game_active = false

## End board game and determine winners
func end_board_game() -> void:
	game_active = false
	
	# Calculate winners based on board score
	var scores: Array = []
	for player_id in player_tokens:
		var player = get_tree().get_first_child_in_group("players")
		while player:
			if int(player.name) == player_id:
				var score = player.get_meta("board_score") if player.has_meta("board_score") else 0
				scores.append({"player": player, "score": score})
				break
			player = player.get_next_sibling()
	
	# Sort by score
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	
	var winners = scores.map(func(s): return s["player"])
	board_game_ended.emit(winners)
	
	# Transition to next game state
	if game_director:
		game_director.request_state_change(GameDirector.State.RESULTS)

## Get current game scores
func get_leaderboard() -> Array:
	var scores: Array = []
	for player_id in player_tokens:
		var player = get_tree().get_first_child_in_group("players")
		while player:
			if int(player.name) == player_id:
				var score = player.get_meta("board_score") if player.has_meta("board_score") else 0
				scores.append({"name": player.get_meta("player_name") if player.has_meta("player_name") else "Player", "score": score})
				break
			player = player.get_next_sibling()
	
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	return scores
