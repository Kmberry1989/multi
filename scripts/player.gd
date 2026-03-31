extends CharacterBody3D
class_name PlayerCharacter

signal player_died(player)

const NORMAL_SPEED := 4.6
const SPRINT_SPEED := 7.2
const JUMP_VELOCITY := 7.8
const MOVE_ACCEL := 14.0
const MOVE_DECEL := 18.0
const HOUSE_HINT_OFFSET := Vector3(-2.5, 0.0, -1.5)

enum SkinColor { BLUE, YELLOW, GREEN, RED }

var player_inventory: PlayerInventory
var profile_id: String = ""
var display_name: String = "Neighbor"
var avatar_id: String = "kyle"
var assigned_plot_id: int = -1
var is_ai := false

@export_category("Objects")
@export var body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture: CompressedTexture2D
@export var yellow_texture: CompressedTexture2D
@export var green_texture: CompressedTexture2D
@export var red_texture: CompressedTexture2D

var _spring_arm: SpringArm3D = null
var _camera_presets := [
	{"length": 2.5, "offset": Vector3(0, 0.0, 0)},
	{"length": 4.2, "offset": Vector3(0, 0.6, 0)},
	{"length": 1.8, "offset": Vector3(0, 0.55, 0.4)},
]
var _camera_preset_index := 0
var _respawn_synced := false
var _is_running := false
var _placement_rotation := 0.0
var _emote_label: Label3D
var _emote_timer := 0.0
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")

var _bottom_mesh: MeshInstance3D
var _chest_mesh: MeshInstance3D
var _face_mesh: MeshInstance3D
var _limbs_head_mesh: MeshInstance3D

func _enter_tree() -> void:
	var authority_id := str(name).to_int()
	if authority_id <= 0:
		authority_id = 1
	set_multiplayer_authority(authority_id)

func _ready() -> void:
	add_to_group("players")
	_setup_camera()
	_setup_character_model()
	find_model_meshes()
	_setup_identity_visuals()
	_setup_emote_label()

	if is_multiplayer_authority() or multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		request_inventory_sync.rpc_id(1)

func _process(delta: float) -> void:
	if _emote_timer > 0.0:
		_emote_timer -= delta
		if _emote_timer <= 0.0 and _emote_label:
			_emote_label.visible = false

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if _ui_is_blocking():
		freeze()
		return

	_handle_actions()
	_handle_movement(delta)

func _setup_camera() -> void:
	if _spring_arm_offset:
		_spring_arm = _spring_arm_offset.get_node_or_null("SpringArm3D") as SpringArm3D
	var cam := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D")
	if cam:
		cam.current = is_multiplayer_authority() and not is_ai
	_apply_camera_preset()

func _setup_character_model() -> void:
	if not has_node("CharacterModel") and not has_node("3DGodotRobot"):
		var switcher = load("res://scripts/character_switcher.gd").new()
		switcher.set_model(self, avatar_id if avatar_id != "" else "kyle")
		switcher.queue_free()

	if body and not (body is RobotBodyController):
		var body_script = load("res://scripts/3d_godot_robot.gd")
		if body_script:
			body.set_script(body_script)
			body.character = self

	if body:
		var helper = load("res://scripts/character_model_helper.gd").new()
		if helper and helper.has_method("setup_character_model"):
			helper.setup_character_model(body)
			helper.free()

func _setup_identity_visuals() -> void:
	var nickname := get_node_or_null("PlayerNick/Nickname") as Label3D
	if nickname:
		nickname.visible = true
		nickname.text = display_name

func _setup_emote_label() -> void:
	_emote_label = get_node_or_null("PlayerNick/Emote") as Label3D
	if _emote_label == null:
		_emote_label = Label3D.new()
		_emote_label.name = "Emote"
		_emote_label.position = Vector3(0.0, 2.5, 0.0)
		_emote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		get_node("PlayerNick").add_child(_emote_label)
	_emote_label.visible = false

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var desired_velocity := Vector3.ZERO
	if input_dir.length() > 0.0:
		var basis := _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
		var forward := -basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := basis.x
		right.y = 0.0
		right = right.normalized()
		desired_velocity = (right * input_dir.x) + (forward * input_dir.y)
		desired_velocity = desired_velocity.normalized()

	_is_running = Input.is_action_pressed("shift")
	var target_speed := SPRINT_SPEED if _is_running else NORMAL_SPEED
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal := desired_velocity * target_speed
	var accel := MOVE_ACCEL if desired_velocity != Vector3.ZERO else MOVE_DECEL
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, accel * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		if body and body.has_method("play_jump_animation"):
			body.play_jump_animation("Jump")

	move_and_slide()

	if body and body.has_method("apply_rotation"):
		body.apply_rotation(horizontal_velocity if desired_velocity != Vector3.ZERO else Vector3(0.0, 0.0, -1.0))
	if body and body.has_method("animate"):
		body.animate(velocity)

func _handle_actions() -> void:
	var town_manager := _get_town_manager()
	if town_manager == null:
		return

	if Input.is_action_just_pressed("light_punch"):
		if town_manager.is_local_home_edit_enabled():
			var object_id := town_manager.get_nearest_owned_object_id(profile_id, global_position)
			if object_id != "":
				town_manager.request_remove_furniture.rpc_id(1, object_id)
				return
		town_manager.request_interact.rpc_id(1)

	if Input.is_action_just_pressed("light_kick"):
		var target_pos := town_manager.get_snap_position_for_player(profile_id, global_position, -global_transform.basis.z, _edit_zone())
		if town_manager.is_local_home_edit_enabled():
			var object_id := town_manager.get_nearest_owned_object_id(profile_id, global_position)
			if object_id != "":
				town_manager.request_move_furniture.rpc_id(1, object_id, target_pos, _placement_rotation, _edit_zone())
			else:
				var item_id := town_manager.get_first_placeable_item(profile_id)
				town_manager.request_place_furniture.rpc_id(1, item_id, target_pos, _placement_rotation, _edit_zone())

	if Input.is_action_just_pressed("special_attack"):
		var crop_id := town_manager.get_nearest_crop_id(profile_id, global_position)
		if crop_id != "":
			if town_manager.is_crop_ready(crop_id):
				town_manager.request_harvest_crop.rpc_id(1, crop_id)
			else:
				town_manager.request_water_crop.rpc_id(1, crop_id)
		else:
			var seed_id := town_manager.get_first_seed_item(profile_id)
			var seed_target := town_manager.get_snap_position_for_player(profile_id, global_position, -global_transform.basis.z, "yard")
			town_manager.request_plant_seed.rpc_id(1, seed_id, seed_target)

	if Input.is_action_just_pressed("block"):
		if multiplayer.has_multiplayer_peer():
			show_emote.rpc("Heart")
		else:
			show_emote("Heart")

	if Input.is_action_just_pressed("target_cycle"):
		_placement_rotation = wrapf(_placement_rotation + 90.0, 0.0, 360.0)
		var zone_name := "inside" if _edit_zone() == "home" else "yard"
		town_manager.local_message.emit("Placement rotation %d degrees (%s)." % [int(_placement_rotation), zone_name])

func _edit_zone() -> String:
	var town_manager := _get_town_manager()
	if town_manager == null:
		return "yard"
	var bounds := town_manager.get_plot_bounds_for_profile(profile_id)
	if bounds.is_empty():
		return "yard"
	var center: Vector3 = bounds.get("center", Vector3.ZERO)
	return "home" if global_position.distance_to(center + HOUSE_HINT_OFFSET) < 3.0 else "yard"

func _ui_is_blocking() -> bool:
	var current_scene := get_tree().get_current_scene()
	if current_scene == null:
		return false
	if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
		return true
	if current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
		return true
	return false

func freeze() -> void:
	velocity = Vector3.ZERO
	if body and body.has_method("animate"):
		body.animate(Vector3.ZERO)

func is_running() -> bool:
	return _is_running

func cycle_camera_preset() -> void:
	_camera_preset_index = (_camera_preset_index + 1) % _camera_presets.size()
	_apply_camera_preset()

func _apply_camera_preset() -> void:
	if _spring_arm == null or _camera_presets.is_empty():
		return
	var preset: Dictionary = _camera_presets[_camera_preset_index]
	_spring_arm.spring_length = float(preset.get("length", 2.5))
	if _spring_arm_offset:
		_spring_arm_offset.position = preset.get("offset", Vector3.ZERO)

func set_identity(new_profile_id: String, new_display_name: String, new_avatar_id: String) -> void:
	profile_id = new_profile_id
	display_name = new_display_name
	avatar_id = new_avatar_id
	_setup_identity_visuals()

func assign_plot(plot_id: int, spawn_position: Vector3) -> void:
	assigned_plot_id = plot_id
	set_meta("town_plot_id", plot_id)
	var peer_id := str(name).to_int()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		receive_plot_assignment.rpc_id(peer_id, plot_id, spawn_position)
	else:
		receive_plot_assignment(plot_id, spawn_position)

@rpc("any_peer", "call_local", "reliable")
func receive_plot_assignment(plot_id: int, spawn_position: Vector3) -> void:
	assigned_plot_id = plot_id
	set_meta("town_plot_id", plot_id)
	if is_multiplayer_authority() and not _respawn_synced:
		global_position = spawn_position
		_respawn_synced = true

@rpc("any_peer", "call_local", "reliable")
func show_emote(text: String) -> void:
	if _emote_label == null:
		return
	_emote_label.text = text
	_emote_label.visible = true
	_emote_timer = 1.75

func find_model_meshes() -> void:
	var model_root: Node = get_node_or_null("CharacterModel")
	if model_root:
		_bottom_mesh = _find_model_mesh(model_root, "Bottom")
		_chest_mesh = _find_model_mesh(model_root, "Chest")
		_face_mesh = _find_model_mesh(model_root, "Face")
		_limbs_head_mesh = _find_model_mesh(model_root, "Llimbs and head")

func _find_model_mesh(model_root: Node, mesh_name: String) -> MeshInstance3D:
	var direct_robot = model_root.get_node_or_null("RobotArmature/Skeleton3D/%s" % mesh_name)
	if direct_robot and direct_robot is MeshInstance3D:
		return direct_robot
	var direct = model_root.get_node_or_null("Skeleton3D/%s" % mesh_name)
	if direct and direct is MeshInstance3D:
		return direct
	var found = model_root.find_child(mesh_name, true, false)
	if found and found is MeshInstance3D:
		return found
	return null

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture := get_texture_from_name(skin_name)
	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)

func get_texture_from_name(skin_name: SkinColor) -> CompressedTexture2D:
	match skin_name:
		SkinColor.BLUE:
			return blue_texture
		SkinColor.YELLOW:
			return yellow_texture
		SkinColor.GREEN:
			return green_texture
		SkinColor.RED:
			return red_texture
		_:
			return blue_texture

func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance == null or texture == null:
		return
	var material := mesh_instance.get_surface_override_material(0)
	if material and material is StandardMaterial3D:
		material.albedo_texture = texture
		mesh_instance.set_surface_override_material(0, material)

@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync() -> void:
	if not multiplayer.is_server():
		return
	var requesting_client := multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		return
	push_inventory_to_owner()

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return
	if not is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
		return
	if player_inventory == null:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)
	var level_scene := get_tree().get_current_scene()
	if level_scene and level_scene.has_method("update_local_inventory_display"):
		level_scene.update_local_inventory_display()

func push_inventory_to_owner() -> void:
	if player_inventory == null:
		return
	var owner_id := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer():
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			sync_inventory_to_owner(player_inventory.to_dict())
	else:
		sync_inventory_to_owner(player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var requesting_client := multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		return
	if player_inventory == null:
		return
	var success := player_inventory.move_item(from_slot, to_slot, quantity)
	if not success:
		success = player_inventory.swap_items(from_slot, to_slot)
	if success:
		push_inventory_to_owner()

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1) -> void:
	if not multiplayer.is_server():
		return
	var requesting_client := multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:
		return
	if player_inventory == null or quantity <= 0:
		return
	var item := ItemDatabase.get_item(item_id)
	if item == null:
		return
	player_inventory.add_item(item, quantity)
	push_inventory_to_owner()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1) -> void:
	if not multiplayer.is_server():
		return
	var requesting_client := multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		return
	if player_inventory == null or quantity <= 0:
		return
	if player_inventory.remove_item(item_id, quantity) > 0:
		push_inventory_to_owner()

func get_inventory() -> PlayerInventory:
	return player_inventory

func _add_starting_items() -> void:
	if player_inventory == null:
		return
	var starter_items := [
		{"id": "turnip_seed", "qty": 3},
		{"id": "watering_can", "qty": 1},
		{"id": "wood_chair", "qty": 1},
		{"id": "cozy_bed", "qty": 1},
		{"id": "garden_lamp", "qty": 1},
	]
	for entry in starter_items:
		var item := ItemDatabase.get_item(str(entry["id"]))
		if item:
			player_inventory.add_item(item, int(entry["qty"]))

func _get_town_manager() -> TownManager:
	var scene := get_tree().get_current_scene()
	if scene and scene.has_node("TownManager"):
		return scene.get_node("TownManager") as TownManager
	return null
