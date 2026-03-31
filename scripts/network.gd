extends Node

const SERVER_ADDRESS := "127.0.0.1"
const SERVER_PORT := 8080
const MAX_PLAYERS := 10
const PROFILE_PATH := "user://player_profile.json"

var players: Dictionary = {}
var player_info := {
	"skin": PlayerCharacter.SkinColor.BLUE,
	"character": "kyle",
	"avatar": "kyle",
	"profile_id": "",
	"display_name": "",
}

signal player_connected(peer_id, player_info)
signal server_disconnected

func _ready() -> void:
	_load_or_create_local_profile()
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host(_unused_nick: String, skin_color_str: String, character_name: String = "kyle"):
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(SERVER_PORT, MAX_PLAYERS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	_apply_local_selection(skin_color_str, character_name)
	players.clear()
	players[1] = player_info.duplicate(true)

	if DisplayServer.get_name() == "headless":
		return

	player_connected.emit(1, players[1])

func join_game(_unused_nick: String, skin_color_str: String, address: String = SERVER_ADDRESS, character_name: String = "kyle"):
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, SERVER_PORT)
	if error:
		return error

	multiplayer.multiplayer_peer = peer
	_apply_local_selection(skin_color_str, character_name)

func _apply_local_selection(skin_color_str: String, character_name: String) -> void:
	player_info["skin"] = skin_str_to_e(skin_color_str)
	player_info["character"] = character_name
	player_info["avatar"] = character_name
	_save_local_profile()

func _on_connected_ok() -> void:
	var peer_id := multiplayer.get_unique_id()
	players[peer_id] = player_info.duplicate(true)
	player_connected.emit(peer_id, players[peer_id])
	register_local_player.rpc_id(1, players[peer_id])

func _on_player_connected(_id: int) -> void:
	pass

@rpc("any_peer", "reliable")
func register_local_player(new_player_info: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	players[peer_id] = new_player_info.duplicate(true)

	for existing_id in players.keys():
		sync_player_to_client.rpc_id(peer_id, int(existing_id), players[existing_id])

	sync_player_to_client.rpc(peer_id, players[peer_id])

@rpc("authority", "call_local", "reliable")
func sync_player_to_client(peer_id: int, synced_player_info: Dictionary) -> void:
	var first_time := not players.has(peer_id)
	players[peer_id] = synced_player_info.duplicate(true)
	if first_time:
		player_connected.emit(peer_id, players[peer_id])

func _on_player_disconnected(id: int) -> void:
	players.erase(id)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

func get_player_info_for_peer(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

func _load_or_create_local_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				player_info["profile_id"] = str(parsed.get("profile_id", ""))
				player_info["display_name"] = str(parsed.get("display_name", ""))
				player_info["character"] = str(parsed.get("character", "kyle"))
				player_info["avatar"] = str(parsed.get("avatar", player_info["character"]))
				if player_info["profile_id"] != "" and player_info["display_name"] != "":
					return

	var generated_id := "%s_%s" % [OS.get_unique_id(), Time.get_unix_time_from_system()]
	if generated_id.begins_with("_"):
		generated_id = "profile_%s" % Time.get_unix_time_from_system()
	var suffix_start := maxi(0, generated_id.length() - 4)
	var generated_name := "Neighbor-%s" % generated_id.substr(suffix_start, generated_id.length() - suffix_start)
	player_info["profile_id"] = generated_id
	player_info["display_name"] = generated_name
	player_info["character"] = "kyle"
	player_info["avatar"] = "kyle"
	_save_local_profile()

func _save_local_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"profile_id": player_info["profile_id"],
			"display_name": player_info["display_name"],
			"character": player_info["character"],
			"avatar": player_info["avatar"],
		}, "\t"))

func skin_str_to_e(s: String):
	match s.to_lower():
		"blue":
			return PlayerCharacter.SkinColor.BLUE
		"yellow":
			return PlayerCharacter.SkinColor.YELLOW
		"green":
			return PlayerCharacter.SkinColor.GREEN
		"red":
			return PlayerCharacter.SkinColor.RED
		_:
			return PlayerCharacter.SkinColor.BLUE
