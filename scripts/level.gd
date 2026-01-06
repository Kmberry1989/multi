extends Node3D
# Force reload

@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: GameMainMenuUI = $MainMenuUI
@export var player_scene: PackedScene
@export var kart_scene: PackedScene
@export var kart_track_scene: PackedScene

@onready var multiplayer_chat: GameMultiplayerChatUI = $MultiplayerChatUI
@onready var inventory_ui: InventoryUI = $InventoryUI

var chat_visible = false
var inventory_visible = false
var game_director: GameDirector
var _is_paused: bool = false
var _ai_spawned: bool = false

var menu_camera: Camera3D
var preview_character: Node3D
var preview_rotation_speed = 1.0

enum GameMode { ON_FOOT, KART }
@export var game_mode: GameMode = GameMode.ON_FOOT

var current_track: Node3D

const CHARACTER_SWITCHER_SCRIPT = preload("res://scripts/character_switcher.gd")
const CONTROLS_UI_SCENE = preload("res://scenes/ui/controls_ui.tscn") # Scene confirmed to exist
const GAME_DIRECTOR_SCRIPT = preload("res://scripts/game_director.gd")


func _ready():
	if DisplayServer.get_name() == "headless":
		print("Dedicated server starting...")
		Network.start_host("", "")

	multiplayer_chat.hide()
	multiplayer_chat.set_process_input(true)

	main_menu.host_pressed.connect(_on_host_pressed)
	main_menu.join_pressed.connect(_on_join_pressed)
	main_menu.quit_pressed.connect(_on_quit_pressed)
	main_menu.character_changed.connect(_update_preview_model)

	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)

	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

	game_director = _ensure_game_director()
	game_director.state_changed.connect(_on_game_state_changed)
	game_director.initialize_state(GameDirector.State.LOBBY)

	_setup_menu_scene()
	_setup_kart_mode()

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
	_add_player(peer_id, player_info)

func _on_host_pressed(skin: String, character_name: String):
	print("Debug: Host button pressed. Char:", character_name)
	main_menu.hide_menu()
	var err = Network.start_host("", skin, character_name)
	if err:
		print("Error starting host: ", err)
		game_director.request_state_change(GameDirector.State.LOBBY)
	else:
		game_director.request_state_change(GameDirector.State.BOARD_TURN)

func _on_join_pressed(skin: String, address: String, character_name: String):
	print("Debug: Join button pressed. Address:", address)
	main_menu.hide_menu()
	var err = Network.join_game("", skin, address, character_name)
	if err:
		print("Error joining game: ", err)
		game_director.request_state_change(GameDirector.State.LOBBY)
	else:
		game_director.request_state_change(GameDirector.State.BOARD_TURN)

func _add_player(id: int, player_info : Dictionary):
	print("Debug: _add_player called for ID: ", id)
	if DisplayServer.get_name() == "headless" and id == 1:
		return

	if players_container.has_node(str(id)):
		return

	var scene_to_spawn := _get_player_scene()
	if scene_to_spawn == null:
		push_warning("No player scene configured for mode: %s" % [game_mode])
		return

	var player = scene_to_spawn.instantiate()
	player.name = str(id)
	if game_mode == GameMode.KART:
		player.position = _get_kart_spawn_point(id)
	else:
		player.position = get_spawn_point()
	players_container.add_child(player, true)
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	if id == multiplayer.get_unique_id():
		_cleanup_menu_scene()
		_show_controls_ui()
		# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Spawn AI opponents once after local player join (host only)
	if not _ai_spawned and multiplayer.is_server():
		_spawn_ai_opponents()

	# Auto-assign a character model
	var model_name = "kyle"
	if player_info.has("character"):
		model_name = player_info["character"]

	# instantiate a temporary switcher to set model
	if CHARACTER_SWITCHER_SCRIPT:
		var switcher = CHARACTER_SWITCHER_SCRIPT.new()
		switcher.set_model(player, model_name)

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 0, spawn_point.y)

func _get_kart_spawn_point(id: int) -> Vector3:
	if current_track:
		var spawn_root = current_track.get_node_or_null("SpawnPoints")
		if spawn_root and spawn_root.get_child_count() > 0:
			var index = (id - 1) % spawn_root.get_child_count()
			var marker = spawn_root.get_child(index)
			if marker is Node3D:
				return marker.global_position
	return get_spawn_point()

func _get_player_scene() -> PackedScene:
	if game_mode == GameMode.KART:
		return kart_scene
	return player_scene

func _setup_kart_mode() -> void:
	if game_mode != GameMode.KART:
		return
	if kart_track_scene == null:
		push_warning("Kart mode enabled without a track scene.")
		return
	current_track = kart_track_scene.instantiate()
	add_child(current_track)

func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

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
	elif event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("camera_cycle"):
		var local_player = _get_local_player()
		if local_player and local_player.has_method("cycle_camera_preset"):
			local_player.cycle_camera_preset()
	elif event.is_action_pressed("target_cycle"):
		var local_player = _get_local_player()
		if local_player and local_player.has_method("cycle_target"):
			local_player.cycle_target(_get_opponents_for(local_player))

func _on_chat_message_sent(message_text: String) -> void:
	var trimmed_message = message_text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	rpc("msg_rpc", "", trimmed_message)

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

func _toggle_pause():
	_is_paused = !_is_paused
	get_tree().paused = _is_paused
	if _is_paused:
		_print_controls()
		print("Paused")
	else:
		print("Unpaused")

func _print_controls():
	# Reduced verbosity: print condensed controls once
	print("Controls: Move WASD/LS, Jump Space/Cross, Sprint Shift/R2, Punch J/Square, Kick K/Circle, Special L/Triangle, Block Q/R1, Target T/L1, Camera C/R3, Pause P/Touchpad")

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

func _get_opponents_for(player: PlayerCharacter) -> Array:
	var opponents: Array = []
	for child in players_container.get_children():
		if child is PlayerCharacter and child != player:
			if child._state != PlayerCharacter.CombatState.DEAD:
				opponents.append(child)
	return opponents

func _spawn_ai_opponents():
	_ai_spawned = true
	var switcher = CHARACTER_SWITCHER_SCRIPT.new()
	var available = switcher.characters.keys()
	var taken: Array = []
	for child in players_container.get_children():
		if child is PlayerCharacter and child.body:
			taken.append(child.body.name.to_lower())
	for taken_name in taken:
		if taken_name in available:
			available.erase(taken_name)
	if available.is_empty():
		return
	for character_name in available:
		var ai = player_scene.instantiate()
		ai.name = "AI_%s" % character_name
		ai.position = get_spawn_point()
		if ai.has_method("set_player_skin"):
			ai.set_player_skin(PlayerCharacter.SkinColor.BLUE)
		if ai.has_method("set_multiplayer_authority"):
			ai.set_multiplayer_authority(1)
		ai.is_ai = true
		players_container.add_child(ai, true)
		if CHARACTER_SWITCHER_SCRIPT:
			var sw = CHARACTER_SWITCHER_SCRIPT.new()
			sw.set_model(ai, character_name)
		if ai.has_signal("player_died"):
			ai.player_died.connect(_on_player_died)

func _on_player_died(_player):
	_check_round_winner()

func _check_round_winner():
	var alive: Array = []
	for child in players_container.get_children():
		if child is PlayerCharacter and child._state != PlayerCharacter.CombatState.DEAD:
			alive.append(child)
	if alive.size() == 1:
		print("Winner: ", alive[0].name)

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

func _ensure_game_director() -> GameDirector:
	var existing = get_node_or_null("GameDirector")
	if existing:
		return existing as GameDirector

	var director = GAME_DIRECTOR_SCRIPT.new()
	director.name = "GameDirector"
	add_child(director)
	return director

func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	match new_state:
		GameDirector.State.LOBBY:
			main_menu.show_menu()
		_:
			main_menu.hide_menu()


func _unhandled_input(event):
	if event.is_action_pressed("quit"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			main_menu.show_menu()
	elif event.is_action_pressed("toggle_chat"):
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
	elif event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("camera_cycle"):
		var local_player = _get_local_player()
		if local_player and local_player.has_method("cycle_camera_preset"):
			local_player.cycle_camera_preset()
