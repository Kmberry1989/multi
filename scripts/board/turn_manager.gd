extends Node
## Server-authoritative turn manager with RPC synchronization for multiplayer.
## Handles dice rolls, player movement, and space event triggering.
class_name TurnManager

signal dice_rolled(player: Node, result: int)
signal player_moved(player: Node, from_index: int, to_index: int)
signal space_event_triggered(player: Node, space_type: String)
signal round_completed(round_number: int)
signal turn_started(player: Node, round_number: int)
signal turn_finished(player: Node, round_number: int)

@export var board_manager_path: NodePath
@export var game_director_path: NodePath
@export var dice_sides := 6

var board_manager: BoardManager
var game_director: GameDirector

var player_order: Array[Node3D] = []
var current_player_index := 0
var round_number := 1
var awaiting_roll := false

func _ready() -> void:
	var node = get_node_or_null(board_manager_path)
	if node is BoardManager:
		board_manager = node
	else:
		push_warning("TurnManager: board_manager_path does not point to a BoardManager node")
		# Fallback: try to find BoardManager sibling or parent
		board_manager = get_parent().find_child("BoardManager", true, false)
	game_director = get_node_or_null(game_director_path)

## Register a player for the board game
func register_player(player: Node3D, start_index: int = 0) -> void:
	if player in player_order:
		return

	player_order.append(player)
	player.set_meta("board_index", start_index)
	_move_player_to_index(player, start_index)

## Start the current player's turn
func start_turn() -> void:
	if player_order.is_empty() or board_manager == null:
		return

	var player = player_order[current_player_index]
	awaiting_roll = true
	turn_started.emit(player, round_number)

## Roll dice and move current player (server authority)
func roll_current_player() -> void:
	if not multiplayer.is_server():
		# Clients send RPC to server
		_request_roll.rpc_id(1)
		return
	
	if player_order.is_empty() or board_manager == null:
		return
	if not awaiting_roll:
		return

	var _player = player_order[current_player_index]
	awaiting_roll = false

	var roll = roll_dice()
	
	# Sync roll to all clients
	_sync_dice_roll.rpc(current_player_index, roll)
	_process_dice_roll(roll)

## Generate random dice value
func roll_dice() -> int:
	return randi_range(1, dice_sides)

## Process the dice roll result (called on server, synced to clients)
func _process_dice_roll(roll: int) -> void:
	if player_order.is_empty():
		return
	
	var player = player_order[current_player_index]
	dice_rolled.emit(player, roll)
	_move_player_steps(player, roll)
	_end_turn()

## Move player by specified steps
func _move_player_steps(player: Node3D, steps: int) -> void:
	var from_index = _get_player_index(player)
	var to_index = board_manager.get_next_index(from_index, steps)
	
	# Sync movement to all clients
	_sync_player_movement.rpc(current_player_index, from_index, to_index)
	_move_player_to_index(player, to_index)
	player_moved.emit(player, from_index, to_index)
	_handle_space_event(player, to_index)

## Move player to specific space index
func _move_player_to_index(player: Node3D, index: int) -> void:
	player.set_meta("board_index", index)
	player.global_position = board_manager.get_space_position(index)

## Sync player position from server (called on clients)
func sync_player_to_index(player: Node3D, index: int) -> void:
	_move_player_to_index(player, index)

## Handle space landing effects (item, minigame, bonus, etc)
func _handle_space_event(player: Node3D, index: int) -> void:
	var space_type = board_manager.get_space_type(index)
	space_event_triggered.emit(player, space_type)

	# Trigger minigame on certain spaces
	if space_type == "minigame" and game_director:
		game_director.start_minigame("space", player)

## Finish current turn and move to next player
func _end_turn() -> void:
	if player_order.is_empty():
		return

	var player = player_order[current_player_index]
	turn_finished.emit(player, round_number)

	current_player_index += 1
	if current_player_index >= player_order.size():
		current_player_index = 0
		round_number += 1
		round_completed.emit(round_number)

## Get player's current board position
func _get_player_index(player: Node3D) -> int:
	if player.has_meta("board_index"):
		return int(player.get_meta("board_index"))
	return 0

## Get current active player
func get_current_player() -> Node3D:
	if player_order.is_empty():
		return null
	if current_player_index < 0 or current_player_index >= player_order.size():
		return null
	return player_order[current_player_index]

## Get turn order index for a specific player
func get_turn_index_for_player(player: Node3D) -> int:
	return player_order.find(player)

## Check if it's a specific player's turn
func is_player_turn(player: Node3D) -> bool:
	return get_current_player() == player

## Reset board state (for rematch/restart)
func reset() -> void:
	player_order.clear()
	current_player_index = 0
	round_number = 1
	awaiting_roll = false

# ==== NETWORKING RPCs ====

## Client requests a dice roll (server authority)
@rpc("any_peer", "reliable")
func _request_roll() -> void:
	if not multiplayer.is_server():
		return
	
	# Only current player can roll
	var requester_id = multiplayer.get_remote_sender_id()
	var current_player = get_current_player()
	if current_player and current_player.get_multiplayer_authority() != requester_id:
		return
	
	roll_current_player()

## Sync dice roll result to all clients
@rpc("authority", "reliable", "call_local")
func _sync_dice_roll(player_index: int, roll: int) -> void:
	if player_index < 0 or player_index >= player_order.size():
		return
	
	var player = player_order[player_index]
	dice_rolled.emit(player, roll)

## Sync player movement to all clients
@rpc("authority", "reliable", "call_local")
func _sync_player_movement(player_index: int, from_index: int, to_index: int) -> void:
	if player_index < 0 or player_index >= player_order.size():
		return
	
	var player = player_order[player_index]
	_move_player_to_index(player, to_index)
	player_moved.emit(player, from_index, to_index)
