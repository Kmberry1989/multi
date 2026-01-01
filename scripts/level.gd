extends Node3D
# Force reload

@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: GameMainMenuUI = $MainMenuUI
@onready var lobby_ui: LobbyUI = $LobbyUI
@export var player_scene: PackedScene

@onready var multiplayer_chat: GameMultiplayerChatUI = $MultiplayerChatUI
@onready var inventory_ui: InventoryUI = $InventoryUI

var chat_visible = false
var inventory_visible = false

var menu_camera: Camera3D
var preview_character: Node3D
var preview_rotation_speed = 1.0

const CHARACTER_SWITCHER_SCRIPT = preload("res://scripts/character_switcher.gd")
const CONTROLS_UI_SCENE = preload("res://scenes/ui/controls_ui.tscn") # Scene confirmed to exist
const LOBBY_RULES = {
	"turns": 10,
	"minigame_pool": "Default",
	"brawl": true,
	"kart": false
}

var ready_by_peer := {}
var match_started = false


func _ready():
	if DisplayServer.get_name() == "headless":
		print("Dedicated server starting...")
		Network.start_host("", "")

	multiplayer_chat.hide()
	main_menu.show_menu()
	multiplayer_chat.set_process_input(true)

	main_menu.host_pressed.connect(_on_host_pressed)
	main_menu.join_pressed.connect(_on_join_pressed)
	main_menu.quit_pressed.connect(_on_quit_pressed)
	main_menu.character_changed.connect(_update_preview_model)

	if lobby_ui:
		lobby_ui.hide()
		lobby_ui.ready_toggled.connect(_on_lobby_ready_toggled)
		lobby_ui.update_rules(LOBBY_RULES)

	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)

	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

	_setup_menu_scene()

func _process(delta):
	if preview_character and is_instance_valid(preview_character):
		preview_character.rotate_y(preview_rotation_speed * delta)
		
	# Watchdog: Force mouse to be visible if it gets captured somehow
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		print("Debug Watchdog: Mouse was ", Input.mouse_mode, " - Forcing to VISIBLE.")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_menu_scene():
	# Create a camera for the menu background
	menu_camera = Camera3D.new()
	# Position camera to look at origin where character will spawn
	add_child(menu_camera)
	# Zoom in closer (approx half distance)
	menu_camera.look_at_from_position(Vector3(0, 1.0, 1.75), Vector3(0, 0.85, 0))
	menu_camera.current = true

func _update_preview_model(character_name: String):
	if preview_character:
		preview_character.queue_free()
		preview_character = null
	
	var switcher = CHARACTER_SWITCHER_SCRIPT.new()
	
	# Create a pivot node
	preview_character = Node3D.new()
	add_child(preview_character)
	preview_character.position = Vector3(0, 0, 0)
	
	# Use switcher to load model
	switcher.set_model(preview_character, character_name)
	switcher.queue_free()
	
	# Play Idle animation
	var model = preview_character.get_node_or_null("CharacterModel")
	if model and "animation_player" in model and model.animation_player:
		if model.animation_player.has_animation("Idle"):
			model.animation_player.play("Idle")
		else:
			var anims = model.animation_player.get_animation_list()
			if anims.size() > 0:
				model.animation_player.play(anims[0])

func _cleanup_menu_scene():
	if menu_camera:
		menu_camera.queue_free()
		menu_camera = null
	if preview_character:
		preview_character.queue_free()
		preview_character = null

func _on_player_connected(peer_id, player_info):
	ready_by_peer[peer_id] = false
	_refresh_lobby()
	if multiplayer.is_server():
		_broadcast_lobby_state()

	if match_started:
		_add_player(peer_id, player_info)

func _on_host_pressed(nickname: String, skin: String, character_name: String):
	print("Debug: Host button pressed. Nick:", nickname, " Char:", character_name)
	main_menu.hide_menu()
	var err = Network.start_host(nickname, skin, character_name)
	if err:
		print("Error starting host: ", err)
		main_menu.show_menu() # Re-show menu on failure
		return
	_show_lobby()

func _on_join_pressed(nickname: String, skin: String, address: String, character_name: String):
	print("Debug: Join button pressed. Address:", address)
	main_menu.hide_menu()
	var err = Network.join_game(nickname, skin, address, character_name)
	if err:
		print("Error joining game: ", err)
		main_menu.show_menu()
		return
	_show_lobby()

func _add_player(id: int, player_info : Dictionary):
	print("Debug: _add_player called for ID: ", id)
	if DisplayServer.get_name() == "headless" and id == 1:
		return

	if not match_started:
		return

	if players_container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)
	
	if id == multiplayer.get_unique_id():
		_cleanup_menu_scene()
		_show_controls_ui()
		# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE




	var nick = Network.players[id]["nick"]
	player.nickname.text = nick

	var skin_enum = player_info["skin"]
	player.set_player_skin(skin_enum)

	# Auto-assign a character model based on selection or fallback to nickname matching
	var model_name = "kyle"
	if player_info.has("character"):
		model_name = player_info["character"]
	else:
		# Legacy fallback
		var nick_lower = str(player_info.get("nick", "")).to_lower()
		var known = ["kyle","eric","donald","kristen","rochelle","vickie"]
		for character_name in known:
			if nick_lower.find(character_name) != -1:
				model_name = character_name
				break

	# instantiate a temporary switcher to set model
	if CHARACTER_SWITCHER_SCRIPT:
		var switcher = CHARACTER_SWITCHER_SCRIPT.new()
		switcher.set_model(player, model_name)

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 0, spawn_point.y)

func _remove_player(id):
	if multiplayer.is_server():
		ready_by_peer.erase(id)
		_broadcast_lobby_state()

	if players_container.has_node(str(id)):
		var player_node = players_container.get_node(str(id))
		if player_node:
			player_node.queue_free()
	_refresh_lobby()

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------- MULTIPLAYER CHAT ----------
func toggle_chat():
	if main_menu.is_menu_visible():
		return

	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()

func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()

func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif chat_visible and multiplayer_chat.message.has_focus():
		if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
			multiplayer_chat.send_chat_message()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_debug_add_item()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_debug_print_inventory()

func _on_chat_message_sent(message_text: String) -> void:
	var trimmed_message = message_text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	var nick = Network.players[multiplayer.get_unique_id()]["nick"]
	rpc("msg_rpc", nick, trimmed_message)

@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	multiplayer_chat.add_message(nick, msg)

# ---------- INVENTORY SYSTEM ----------
func toggle_inventory():
	if main_menu.is_menu_visible():
		return

	var local_player = _get_local_player()
	if not local_player:
		return

	inventory_visible = !inventory_visible
	if inventory_visible:
		inventory_ui.open_inventory(local_player)
	else:
		inventory_ui.close_inventory()

func is_inventory_visible() -> bool:
	return inventory_visible

# Additional helper for testing
func _notification(what):
	if what == NOTIFICATION_READY:
		print("Inventory System Controls:")
		print("  B - Toggle inventory")
		print("  F1 - Add random test item (debug)")
		print("  F2 - Print inventory contents (debug)")

func _on_inventory_closed():
	inventory_visible = false

func update_local_inventory_display():
	if inventory_ui:
		# Always refresh if the UI exists, regardless of visibility
		inventory_ui.refresh_display()
		print("Debug: Inventory display updated from server sync")

func _get_local_player() -> PlayerCharacter:
	var local_player_id = multiplayer.get_unique_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id)) as PlayerCharacter
	return null

# Debug functions for testing inventory system
func _debug_add_item():
	var local_player = _get_local_player()
	if local_player:
		var test_items = [
			"iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"
		]
		var random_item = test_items[randi() % test_items.size()]
		print("Debug: Requesting to add ", random_item, 
			" to player ", local_player.name, 
			" (authority: ", local_player.get_multiplayer_authority(), ")")
		local_player.request_add_item.rpc_id(1, random_item, 1)
	else:
		print("Debug: No local player found!")

func _debug_print_inventory():
	var local_player = _get_local_player()
	if local_player and local_player.get_inventory():
		var inventory = local_player.get_inventory()
		print("=== Inventory Debug ===")
		for i in range(inventory.slots.size()):
			var slot = inventory.get_slot(i)
			if slot and not slot.is_empty():
				print("Slot ", i, ": ", slot.item_id, " x", slot.quantity)
		print("=====================")
	else:
		print("No inventory found for local player")

func _show_controls_ui():
	var controls_ui = CONTROLS_UI_SCENE.instantiate()
	add_child(controls_ui)

func _show_lobby():
	if DisplayServer.get_name() == "headless":
		return
	if lobby_ui:
		lobby_ui.show()
		_refresh_lobby()

func _refresh_lobby():
	if not lobby_ui:
		return
	lobby_ui.update_players(Network.players, ready_by_peer)
	var all_ready = _are_all_players_ready()
	if all_ready:
		lobby_ui.set_status("All players ready. Starting...")
	else:
		lobby_ui.set_status("Waiting for players to ready up...")
	var local_ready = ready_by_peer.get(multiplayer.get_unique_id(), false)
	lobby_ui.set_ready_state(local_ready)

func _are_all_players_ready() -> bool:
	if Network.players.is_empty():
		return false
	for id in Network.players.keys():
		if not ready_by_peer.get(id, false):
			return false
	return true

func _on_lobby_ready_toggled(is_ready: bool) -> void:
	if multiplayer.is_server():
		_set_player_ready(multiplayer.get_unique_id(), is_ready)
	else:
		request_ready_state.rpc_id(1, is_ready)

@rpc("any_peer", "reliable")
func request_ready_state(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	_set_player_ready(peer_id, is_ready)

func _set_player_ready(peer_id: int, is_ready: bool) -> void:
	ready_by_peer[peer_id] = is_ready
	_broadcast_lobby_state()
	_check_start_conditions()

func _broadcast_lobby_state() -> void:
	_refresh_lobby()
	if multiplayer.is_server():
		lobby_state_sync_rpc.rpc(ready_by_peer)

@rpc("authority", "reliable")
func lobby_state_sync_rpc(ready_state: Dictionary) -> void:
	ready_by_peer = ready_state.duplicate()
	_refresh_lobby()

func _check_start_conditions() -> void:
	if match_started or not multiplayer.is_server():
		return
	if not _are_all_players_ready():
		return
	start_match_rpc.rpc()

@rpc("authority", "call_local")
func start_match_rpc() -> void:
	if match_started:
		return
	match_started = true
	if lobby_ui:
		lobby_ui.hide()
	for id in Network.players.keys():
		_add_player(id, Network.players[id])


func _unhandled_input(event):
	if event.is_action_pressed("quit"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			main_menu.show_menu()
			
	# Mouse capture logic is intentionally disabled
	# if event is InputEventMouseButton and event.pressed:
	# 	pass
