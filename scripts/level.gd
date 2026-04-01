extends Node3D

@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: GameMainMenuUI = $MainMenuUI
@onready var multiplayer_chat: GameMultiplayerChatUI = $MultiplayerChatUI
@onready var inventory_ui: InventoryUI = $InventoryUI

@export var player_scene: PackedScene
@export var kart_scene: PackedScene
@export var kart_track_scene: PackedScene

var chat_visible := false
var inventory_visible := false
var game_director: GameDirector
var town_manager: TownManager
var town_hud: TownHUD
var mobile_controls_hud: MobileControlsHUD
var menu_camera: Camera3D
var preview_character: Node3D
var preview_rotation_speed := 0.75
var current_track: Node3D

const CHARACTER_SWITCHER_SCRIPT = preload("res://scripts/character_switcher.gd")
const GAME_DIRECTOR_SCRIPT = preload("res://scripts/game_director.gd")
const TOWN_MANAGER_SCRIPT = preload("res://scripts/town_manager.gd")
const TOWN_HUD_SCRIPT = preload("res://scripts/town_hud.gd")
const MOBILE_CONTROLS_HUD_SCRIPT = preload("res://scripts/mobile_controls_hud.gd")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if DisplayServer.get_name() == "headless":
		Network.start_host("", "blue", "kyle")

	multiplayer_chat.hide()
	multiplayer_chat.set_process_input(true)

	main_menu.host_pressed.connect(_on_host_pressed)
	main_menu.join_pressed.connect(_on_join_pressed)
	main_menu.quit_pressed.connect(_on_quit_pressed)
	main_menu.character_changed.connect(_update_preview_model)

	inventory_ui.inventory_closed.connect(_on_inventory_closed)
	multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	Network.player_connected.connect(_on_player_connected)
	Network.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_remove_player)

	game_director = _ensure_game_director()
	game_director.state_changed.connect(_on_game_state_changed)
	var initial_state := GameDirector.State.LOBBY
	if DisplayServer.get_name() == "headless":
		initial_state = GameDirector.State.TOWN
	game_director.initialize_state(initial_state)

	town_manager = _ensure_town_manager()
	town_hud = _ensure_town_hud()
	mobile_controls_hud = _ensure_mobile_controls_hud()
	town_manager.local_message.connect(_on_town_message)
	town_manager.clock_changed.connect(_on_clock_changed)
	town_manager.plot_text_changed.connect(_on_plot_text_changed)

	_setup_menu_scene()
	if main_menu:
		main_menu.show_menu()

func _process(delta: float) -> void:
	if preview_character and is_instance_valid(preview_character):
		preview_character.rotate_y(preview_rotation_speed * delta)

func _setup_menu_scene() -> void:
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.look_at_from_position(Vector3(0, 1.1, 1.8), Vector3(0, 0.85, 0))
	menu_camera.current = true
	_update_preview_model(main_menu.get_selected_character() if main_menu else "kyle")

func _cleanup_menu_scene() -> void:
	if menu_camera:
		menu_camera.queue_free()
		menu_camera = null
	if preview_character:
		preview_character.queue_free()
		preview_character = null

func _update_preview_model(character_name: String) -> void:
	if preview_character:
		preview_character.queue_free()
		preview_character = null

	var switcher = CHARACTER_SWITCHER_SCRIPT.new()
	preview_character = Node3D.new()
	add_child(preview_character)
	switcher.set_model(preview_character, character_name)
	switcher.queue_free()

	var model = preview_character.get_node_or_null("CharacterModel")
	if model and "animation_player" in model and model.animation_player:
		if model.animation_player.has_animation("Idle"):
			model.animation_player.play("Idle")
		else:
			model.animation_player.play(model.animation_player.get_animation_list()[0])

func _on_host_pressed(skin: String, character_name: String) -> void:
	main_menu.hide_menu()
	var err = Network.start_host("", skin, character_name)
	if err:
		main_menu.show_menu()
		return
	game_director.request_state_change(GameDirector.State.TOWN)

func _on_join_pressed(skin: String, address: String, character_name: String) -> void:
	main_menu.hide_menu()
	var err = Network.join_game("", skin, address, character_name)
	if err:
		main_menu.show_menu()
		return
	game_director.request_state_change(GameDirector.State.TOWN)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	_add_player(peer_id, player_info)

func _add_player(id: int, player_info: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" and id == 1:
		return
	if players_container.has_node(str(id)):
		return
	if player_scene == null:
		return

	var player := player_scene.instantiate() as PlayerCharacter
	player.name = str(id)
	player.position = Vector3.ZERO
	players_container.add_child(player, true)

	player.apply_identity(
		str(player_info.get("profile_id", "")),
		str(player_info.get("display_name", "Neighbor")),
		str(player_info.get("avatar", player_info.get("character", "kyle")))
	)

	var model_name := str(player_info.get("character", "kyle"))
	var switcher = CHARACTER_SWITCHER_SCRIPT.new()
	switcher.set_model(player, model_name)
	switcher.queue_free()

	if town_manager:
		town_manager.register_player(player, player_info)

	if id == multiplayer.get_unique_id() or not multiplayer.has_multiplayer_peer():
		_cleanup_menu_scene()
		if town_hud:
			town_hud.visible = true
		if mobile_controls_hud:
			mobile_controls_hud.bind_context(self, player)
			mobile_controls_hud.visible = true
		if main_menu:
			main_menu.hide_menu()

func _remove_player(id: int) -> void:
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()

func _on_server_disconnected() -> void:
	for child in players_container.get_children():
		child.queue_free()
	main_menu.show_menu()
	if town_hud:
		town_hud.visible = false
	if mobile_controls_hud:
		mobile_controls_hud.visible = false

func _on_chat_message_sent(message_text: String) -> void:
	var trimmed := message_text.strip_edges()
	if trimmed == "":
		return
	rpc("msg_rpc", Network.player_info.get("display_name", "Neighbor"), trimmed)

@rpc("any_peer", "call_local")
func msg_rpc(nick: String, msg: String) -> void:
	multiplayer_chat.add_message(nick, msg)

func toggle_chat() -> void:
	if main_menu.is_menu_visible():
		return
	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()

func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()

func toggle_inventory() -> void:
	if main_menu.is_menu_visible():
		return
	var local_player := _get_local_player()
	if local_player == null:
		return
	inventory_visible = not inventory_visible
	if inventory_visible:
		inventory_ui.open_inventory(local_player)
	else:
		inventory_ui.close_inventory()

func is_inventory_visible() -> bool:
	return inventory_visible

func _on_inventory_closed() -> void:
	inventory_visible = false

func update_local_inventory_display() -> void:
	inventory_ui.refresh_display()

func _get_local_player() -> PlayerCharacter:
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if players_container.has_node(str(local_id)):
		return players_container.get_node(str(local_id)) as PlayerCharacter
	return null

func _input(event) -> void:
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif chat_visible and multiplayer_chat.message.has_focus():
		if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
			multiplayer_chat.send_chat_message()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event.is_action_pressed("camera_cycle"):
		var local_player := _get_local_player()
		if local_player:
			local_player.cycle_camera_preset()
	elif event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_on_town_message("Paused" if get_tree().paused else "Unpaused")

func _unhandled_input(event) -> void:
	if event.is_action_pressed("quit"):
		if menu_camera == null:
			_setup_menu_scene()
		main_menu.show_menu()
		if town_hud:
			town_hud.visible = false
		if mobile_controls_hud:
			mobile_controls_hud.visible = false

func _ensure_game_director() -> GameDirector:
	var existing := get_node_or_null("GameDirector")
	if existing:
		return existing as GameDirector
	var director = GAME_DIRECTOR_SCRIPT.new()
	director.name = "GameDirector"
	add_child(director)
	return director

func _ensure_town_manager() -> TownManager:
	var existing := get_node_or_null("TownManager")
	if existing:
		return existing as TownManager
	var manager = TOWN_MANAGER_SCRIPT.new()
	manager.name = "TownManager"
	add_child(manager)
	return manager

func _ensure_town_hud() -> TownHUD:
	var existing := get_node_or_null("TownHUD")
	if existing:
		return existing as TownHUD
	var hud = TOWN_HUD_SCRIPT.new()
	hud.name = "TownHUD"
	add_child(hud)
	hud.visible = false
	return hud

func _ensure_mobile_controls_hud() -> MobileControlsHUD:
	var existing := get_node_or_null("MobileControlsHUD")
	if existing:
		return existing as MobileControlsHUD
	var hud = MOBILE_CONTROLS_HUD_SCRIPT.new()
	hud.name = "MobileControlsHUD"
	add_child(hud)
	hud.visible = false
	return hud

func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	match new_state:
		GameDirector.State.LOBBY:
			main_menu.show_menu()
			if town_hud:
				town_hud.visible = false
			if mobile_controls_hud:
				mobile_controls_hud.visible = false
			if inventory_ui:
				inventory_ui.close_inventory()
		GameDirector.State.TOWN:
			main_menu.hide_menu()
			if town_hud:
				town_hud.visible = true
			if mobile_controls_hud:
				mobile_controls_hud.visible = true
		GameDirector.State.HOME_EDIT:
			main_menu.hide_menu()
			if town_hud:
				town_hud.visible = true
			if mobile_controls_hud:
				mobile_controls_hud.visible = true
		GameDirector.State.FESTIVAL_ACTIVITY:
			main_menu.hide_menu()
			if mobile_controls_hud:
				mobile_controls_hud.visible = true
			_on_town_message("Festival activity ready. Legacy modes can be started explicitly.")
		GameDirector.State.BOARD_TURN:
			main_menu.hide_menu()
			_setup_board_game()
		GameDirector.State.KART:
			main_menu.hide_menu()
			_setup_kart_mode()
		_:
			main_menu.hide_menu()

func start_festival_activity(mode: String) -> void:
	match mode:
		"board":
			game_director.request_state_change(GameDirector.State.BOARD_TURN)
		"kart":
			game_director.request_state_change(GameDirector.State.KART)
		_:
			game_director.request_state_change(GameDirector.State.FESTIVAL_ACTIVITY)

func _setup_kart_mode() -> void:
	if current_track or kart_track_scene == null:
		return
	current_track = kart_track_scene.instantiate()
	add_child(current_track)

func _setup_board_game() -> void:
	var board_controller = find_child("BoardGameController", true, false)
	if board_controller:
		return
	var board_scene = load("res://scenes/board/board.tscn")
	if board_scene:
		board_controller = board_scene.instantiate()
		if board_controller.name != "BoardGameController":
			board_controller.name = "BoardGameController"
		add_child(board_controller)

func _on_town_message(message: String) -> void:
	if town_hud:
		town_hud.show_message(message)

func _on_clock_changed(day: int, minute_of_day: int) -> void:
	if town_hud:
		town_hud.update_clock(day, minute_of_day)

func _on_plot_text_changed(value: String) -> void:
	if town_hud:
		town_hud.set_plot_text(value)
