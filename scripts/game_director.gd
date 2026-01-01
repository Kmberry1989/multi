extends Node
class_name GameDirector

enum State {
	LOBBY,
	BOARD_TURN,
	MINIGAME,
	RESULTS,
	BRAWL,
	KART,
}

signal state_changed(new_state: int, previous_state: int)
signal state_sync_requested(new_state: int)

var current_state: int = State.LOBBY

func initialize_state(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(new_state, new_state)

func set_state(new_state: int) -> void:
	_apply_state(new_state, false)

func request_state_change(new_state: int) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_apply_state(new_state, true)
		else:
			state_sync_requested.emit(new_state)
			_request_state_change.rpc_id(1, new_state)
	else:
		_apply_state(new_state, false)

func sync_state_from_network(new_state: int) -> void:
	_apply_state(new_state, false)

func _apply_state(new_state: int, broadcast: bool) -> void:
	if new_state == current_state:
		return

	var previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)

	if broadcast:
		state_sync_requested.emit(new_state)
		_sync_state.rpc(new_state)

@rpc("any_peer", "reliable")
func _request_state_change(new_state: int) -> void:
	if not multiplayer.is_server():
		return

	_apply_state(new_state, true)

@rpc("authority", "reliable", "call_local")
func _sync_state(new_state: int) -> void:
	sync_state_from_network(new_state)
