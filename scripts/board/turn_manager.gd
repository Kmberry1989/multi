extends Node
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
	board_manager = get_node_or_null(board_manager_path)
	game_director = get_node_or_null(game_director_path)

func register_player(player: Node3D, start_index: int = 0) -> void:
	if player in player_order:
		return

	player_order.append(player)
	player.set_meta("board_index", start_index)
	_move_player_to_index(player, start_index)

func start_turn() -> void:
	if player_order.is_empty() or board_manager == null:
		return

	var player = player_order[current_player_index]
	awaiting_roll = true
	turn_started.emit(player, round_number)

func roll_current_player() -> void:
	if player_order.is_empty() or board_manager == null:
		return
	if not awaiting_roll:
		return

	var player = player_order[current_player_index]
	awaiting_roll = false

	var roll = roll_dice()
	emit_signal("dice_rolled", player, roll)
	_move_player_steps(player, roll)
	_end_turn()

func roll_dice() -> int:
	return randi_range(1, dice_sides)

func _move_player_steps(player: Node3D, steps: int) -> void:
	var from_index = _get_player_index(player)
	var to_index = board_manager.get_next_index(from_index, steps)
	_move_player_to_index(player, to_index)
	emit_signal("player_moved", player, from_index, to_index)
	_handle_space_event(player, to_index)

func _move_player_to_index(player: Node3D, index: int) -> void:
	player.set_meta("board_index", index)
	player.global_position = board_manager.get_space_position(index)

func sync_player_to_index(player: Node3D, index: int) -> void:
	_move_player_to_index(player, index)

func _handle_space_event(player: Node3D, index: int) -> void:
	var space_type = board_manager.get_space_type(index)
	emit_signal("space_event_triggered", player, space_type)

	if space_type == "minigame" and game_director:
		game_director.start_minigame("space", player)

func _end_turn() -> void:
	if player_order.is_empty():
		return

	var player = player_order[current_player_index]
	turn_finished.emit(player, round_number)

	current_player_index += 1
	if current_player_index >= player_order.size():
		current_player_index = 0
		round_number += 1
		emit_signal("round_completed", round_number)
		if game_director:
			game_director.start_minigame("round_end", null)

func _get_player_index(player: Node3D) -> int:
	if player.has_meta("board_index"):
		return int(player.get_meta("board_index"))
	return 0

func get_current_player() -> Node3D:
	if player_order.is_empty():
		return null
	if current_player_index < 0 or current_player_index >= player_order.size():
		return null
	return player_order[current_player_index]

func get_turn_index_for_player(player: Node3D) -> int:
	return player_order.find(player)

func reset() -> void:
	player_order.clear()
	current_player_index = 0
	round_number = 1
	awaiting_roll = false
