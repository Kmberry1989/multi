extends Node
## Handles space landing effects: items, minigames, bonuses, traps, etc.
## Server-authoritative effects with client sync.

class_name BoardSpaceEvents

signal space_effect_applied(player: Node, space_type: String, effect: Dictionary)

var turn_manager: TurnManager

func _ready() -> void:
	turn_manager = get_parent() if get_parent() is TurnManager else null
	
	if turn_manager:
		turn_manager.space_event_triggered.connect(_on_space_event)

## Apply effect based on space type
func apply_space_effect(player: Node3D, space_type: String) -> void:
	if not multiplayer.is_server():
		_request_space_effect.rpc_id(1, str(player.name).to_int(), space_type)
		return
	
	var effect_data = _get_space_effect(space_type)
	_sync_space_effect.rpc(str(player.name).to_int(), space_type, effect_data)
	_apply_effect_local(player, space_type, effect_data)

## Get effect parameters for a space type
func _get_space_effect(space_type: String) -> Dictionary:
	match space_type:
		"item":
			return {"type": "item", "count": 1}
		"minigame":
			return {"type": "minigame", "difficulty": "normal"}
		"bonus":
			return {"type": "bonus", "points": 10}
		"trap":
			return {"type": "trap", "damage": 5}
		_:
			return {"type": "normal"}

## Apply effect locally (on all clients)
func _apply_effect_local(player: Node3D, space_type: String, effect_data: Dictionary) -> void:
	match space_type:
		"item":
			_apply_item_effect(player, effect_data)
		"bonus":
			_apply_bonus_effect(player, effect_data)
		"trap":
			_apply_trap_effect(player, effect_data)
	
	space_effect_applied.emit(player, space_type, effect_data)

## Item space: give player random item
func _apply_item_effect(player: Node3D, _effect: Dictionary) -> void:
	if not player.is_in_group("players"):
		return
	
	# Award random item to player
	var items = ["health_potion", "iron_sword"]
	var random_item = items[randi() % items.size()]
	
	if player.has_method("request_add_item"):
		player.request_add_item(random_item, 1)

## Bonus space: add points to player score
func _apply_bonus_effect(player: Node3D, effect: Dictionary) -> void:
	var points = effect.get("points", 10)
	
	if player.has_meta("board_score"):
		var current = player.get_meta("board_score")
		player.set_meta("board_score", current + points)
	else:
		player.set_meta("board_score", points)

## Trap space: subtract points from player score
func _apply_trap_effect(player: Node3D, effect: Dictionary) -> void:
	var damage = effect.get("damage", 5)
	
	if player.has_meta("board_score"):
		var current = player.get_meta("board_score")
		player.set_meta("board_score", maxi(0, current - damage))
	else:
		player.set_meta("board_score", 0)

## Callback when space event is triggered
func _on_space_event(player: Node, space_type: String) -> void:
	apply_space_effect(player, space_type)

# ==== NETWORKING RPCs ====

## Client requests space effect (server authority)
@rpc("any_peer", "reliable")
func _request_space_effect(player_id: int, space_type: String) -> void:
	if not multiplayer.is_server():
		return
	
	var player = get_tree().get_first_child_in_group("players")
	while player:
		if str(player.name).to_int() == player_id:
			apply_space_effect(player, space_type)
			return
		player = player.get_next_sibling()

## Sync space effect to all clients
@rpc("authority", "reliable", "call_local")
func _sync_space_effect(player_id: int, space_type: String, effect_data: Dictionary) -> void:
	var player = get_tree().get_first_child_in_group("players")
	while player:
		if str(player.name).to_int() == player_id:
			_apply_effect_local(player, space_type, effect_data)
			return
		player = player.get_next_sibling()
