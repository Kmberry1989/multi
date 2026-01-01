extends CharacterBody3D
class_name PlayerCharacter

const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10

enum SkinColor { BLUE, YELLOW, GREEN, RED }
enum Mode { ADVENTURE, BRAWL }

@onready var nickname: Label3D = $PlayerNick/Nickname
@onready var hurtbox: Area3D = $Hurtbox
@onready var hitbox: Area3D = $Hitbox

var player_inventory: PlayerInventory

@export_category("Combat")
@export var mode: Mode = Mode.ADVENTURE
@export var is_cpu: bool = false
@export var cpu_target_path: NodePath
@export var max_health: float = 100.0
@export var light_attack_damage: float = 8.0
@export var heavy_attack_damage: float = 14.0
@export var knockback_force: float = 6.0
@export var heavy_knockback_force: float = 10.0
@export var block_damage_multiplier: float = 0.4
@export var block_knockback_multiplier: float = 0.5
@export var dodge_impulse: float = 10.0
@export var dodge_cooldown: float = 0.8
@export var light_recovery: float = 0.4
@export var heavy_recovery: float = 0.7
@export var hitbox_active_time: float = 0.2
@export var cpu_attack_range: float = 2.0
@export var cpu_stop_distance: float = 1.1

@export_category("Objects")
@export var body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

var _bottom_mesh: MeshInstance3D
var _chest_mesh: MeshInstance3D
var _face_mesh: MeshInstance3D
var _limbs_head_mesh: MeshInstance3D

func find_model_meshes():
	var model_root: Node = null
	if has_node("CharacterModel"):
		model_root = get_node("CharacterModel")

	# NOTE: removed fallback to embedded 3DGodotRobot to avoid overlapping visuals.
	# Robot nodes are removed at runtime in _ready() instead.

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

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var can_double_jump = true
var has_double_jumped = false
var health: float
var _attack_cooldown := 0.0
var _dodge_timer := 0.0
var _hitbox_timer := 0.0
var _current_attack_damage := 0.0
var _current_knockback := 0.0
var _hit_targets: Dictionary = {}
var _block_active := false

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	# Ensure the camera is current for the local player
	if is_multiplayer_authority():
		var cam = get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D")
		if cam:
			cam.current = true
			
	# Ensure a character model is present. If not, default to Kyle.

	# The placeholder in player.tscn might handle this, but explicit initialization is safer.
	if not has_node("CharacterModel") and not has_node("3DGodotRobot"):
		var switcher = load("res://scripts/character_switcher.gd").new()
		switcher.set_model(self, "kyle")
		switcher.queue_free()

	find_model_meshes()
	health = max_health

	if hitbox:
		hitbox.monitoring = false
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	var is_local_player = is_multiplayer_authority()
	var local_client_id = multiplayer.get_unique_id()

	print(
		"Debug: Player ", name, " ready - authority: ", get_multiplayer_authority(), 
		", local client: ", local_client_id, ", is_local: ", is_local_player
	)

	if is_local_player:
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	elif multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		if get_multiplayer_authority() == local_client_id:
			request_inventory_sync.rpc_id(1)

func _physics_process(delta):
	if not is_multiplayer_authority() and not is_cpu:
		return

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif (
			current_scene.has_method("is_inventory_visible") 
			and current_scene.is_inventory_visible()
		):
			should_freeze = true

		if should_freeze:
			freeze()
			return

	_handle_combat(delta)

	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			body.play_jump_animation("Jump")
	else:
		velocity.y -= gravity * delta

		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			body.play_jump_animation("Jump2")

	velocity.y -= gravity * delta

	_move()
	move_and_slide()
	body.animate(velocity)

func _process(_delta):
	if not is_multiplayer_authority() and not is_cpu:
		return
	_check_fall_and_respawn()

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	body.animate(Vector3.ZERO)

func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = _get_move_input()

	var _direction: Vector3 = transform.basis * Vector3(
		_input_direction.x, 0, _input_direction.y
	).normalized()

	is_running()
	_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		body.apply_rotation(velocity)
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	_current_speed = NORMAL_SPEED
	return false

func _get_move_input() -> Vector2:
	if mode == Mode.BRAWL and is_cpu:
		var target = _get_cpu_target()
		if target:
			var to_target = target.global_transform.origin - global_transform.origin
			if to_target.length() <= cpu_stop_distance:
				return Vector2.ZERO
			return Vector2(to_target.x, to_target.z).normalized()

	return Input.get_vector(
		"move_left", "move_right",
		"move_forward", "move_backward"
	)

func _handle_combat(delta: float) -> void:
	if mode != Mode.BRAWL:
		return

	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_dodge_timer = max(0.0, _dodge_timer - delta)
	_hitbox_timer = max(0.0, _hitbox_timer - delta)

	if _hitbox_timer == 0.0 and hitbox and hitbox.monitoring:
		hitbox.monitoring = false

	var light_attack = false
	var heavy_attack = false
	var block = false
	var dodge = false

	if is_cpu:
		var target = _get_cpu_target()
		if target:
			var distance = global_transform.origin.distance_to(target.global_transform.origin)
			light_attack = distance <= cpu_attack_range
			block = distance <= cpu_stop_distance * 1.2 and randf() < 0.1
			dodge = distance <= cpu_stop_distance * 0.9 and randf() < 0.05
	else:
		light_attack = Input.is_action_just_pressed("combat_light")
		heavy_attack = Input.is_action_just_pressed("combat_heavy")
		block = Input.is_action_pressed("combat_block")
		dodge = Input.is_action_just_pressed("combat_dodge")

	_block_active = block

	if _attack_cooldown == 0.0:
		if heavy_attack:
			_start_attack(heavy_attack_damage, heavy_knockback_force, heavy_recovery)
		elif light_attack:
			_start_attack(light_attack_damage, knockback_force, light_recovery)

	if dodge and _dodge_timer == 0.0:
		_perform_dodge()

func _start_attack(damage: float, knockback: float, recovery: float) -> void:
	_attack_cooldown = recovery
	_hitbox_timer = hitbox_active_time
	_current_attack_damage = damage
	_current_knockback = knockback
	_hit_targets.clear()
	if hitbox:
		hitbox.monitoring = true

func _perform_dodge() -> void:
	_dodge_timer = dodge_cooldown
	var dodge_direction = Vector3.ZERO
	var move_input = _get_move_input()
	if move_input.length() > 0.1:
		dodge_direction = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	else:
		dodge_direction = -transform.basis.z.normalized()
	velocity += dodge_direction * dodge_impulse

func _on_hitbox_area_entered(area: Area3D) -> void:
	if mode != Mode.BRAWL:
		return
	if area == hurtbox:
		return

	var target = area.get_parent()
	if not target or not target.has_method("receive_hit"):
		return
	if _hit_targets.has(target):
		return

	_hit_targets[target] = true
	var knockback_direction = (target.global_transform.origin - global_transform.origin).normalized()
	target.receive_hit(_current_attack_damage, knockback_direction * _current_knockback, self)

func receive_hit(damage: float, knockback: Vector3, _attacker: Node) -> void:
	if mode != Mode.BRAWL:
		return

	if _block_active:
		damage *= block_damage_multiplier
		knockback *= block_knockback_multiplier

	health = max(0.0, health - damage)
	velocity += knockback

	if health <= 0.0:
		health = max_health
		_respawn()

func set_cpu_target(target: Node3D) -> void:
	if target:
		cpu_target_path = target.get_path()

func _get_cpu_target() -> Node3D:
	if cpu_target_path != NodePath(""):
		var target = get_node_or_null(cpu_target_path)
		if target and target is Node3D:
			return target
	return null

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)

func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

# Inventory Network Functions - Server authoritative, client-specific
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	print(
		"Debug: request_inventory_sync called on player ", name, 
		" (authority: ", get_multiplayer_authority(), 
		") by client ", multiplayer.get_remote_sender_id()
	)

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning(
			"Client " + str(requesting_client) + " tried to request inventory for player " 
			+ str(get_multiplayer_authority())
		)
		return

	if player_inventory:
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	print(
		"Debug: sync_inventory_to_owner called on player ", name, 
		" (authority: ", get_multiplayer_authority(), 
		") - local unique id: ", multiplayer.get_unique_id(), 
		" from: ", multiplayer.get_remote_sender_id()
	)

	if multiplayer.get_remote_sender_id() != 1:
		return

	if not is_multiplayer_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if level_scene:
		if is_multiplayer_authority() or get_multiplayer_authority() == multiplayer.get_unique_id():
			print("Debug: This is the local player, updating UI")
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					print("Debug: Calling refresh_display directly on InventoryUI")
					inventory_ui.refresh_display()
		else:
			print("Debug: Not the local player, skipping UI update")

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	print(
		"Debug: request_move_item called - from:", from_slot, " to:", to_slot, 
		" on player ", name, " (authority: ", get_multiplayer_authority(), 
		") by client ", multiplayer.get_remote_sender_id()
	)

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning(
			"Client " + str(requesting_client) + " tried to modify inventory for player " 
			+ str(get_multiplayer_authority())
		)
		return

	if not player_inventory:
		return

	if (
		from_slot < 0 or from_slot >= PlayerInventory.INVENTORY_SIZE 
		or to_slot < 0 or to_slot >= PlayerInventory.INVENTORY_SIZE
	):
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
			print("Debug: Swapped items between slots ", from_slot, " and ", to_slot)
		else:
			print("Debug: Moved item from slot ", from_slot, " to ", to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
		print("Debug: Moved ", quantity, " items from slot ", from_slot, " to ", to_slot)

	if success:
		print("Debug: Move successful, syncing inventory to owner ", get_multiplayer_authority())
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
	else:
		print("Debug: Move/swap failed")

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	print(
		"Debug: request_add_item called on player ", name, 
		" (authority: ", get_multiplayer_authority(), 
		") by client ", multiplayer.get_remote_sender_id()
	)

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:
		push_warning(
			"Client " + str(requesting_client) + " tried to add items to player " 
			+ str(get_multiplayer_authority())
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining
	print("Debug: Added ", added, " ", item_id, " to inventory (", remaining, " remaining)")

	if added > 0:
		var owner_id = get_multiplayer_authority()
		print("Debug: Syncing inventory to owner ", owner_id)
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	print(
		"Debug: request_remove_item called on player ", name, 
		" (authority: ", get_multiplayer_authority(), 
		") by client ", multiplayer.get_remote_sender_id()
	)

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning(
			"Client " + str(requesting_client) + " tried to remove items from player " 
			+ str(get_multiplayer_authority())
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func _add_starting_items():
	if not player_inventory:
		return

	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")

	if sword:
		player_inventory.add_item(sword, 1)
	if potion:
		player_inventory.add_item(potion, 3)
