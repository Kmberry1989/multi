extends CharacterBody3D
class_name PlayerCharacter
signal player_died(player)

const NORMAL_SPEED = 4.8
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 10
const JUMP_WINDUP_TIME = 0.15
const COMBO_WINDOW = 0.6
const HEAVY_HOLD_TIME = 0.4
const SPECIAL_FULL_CHARGE_TIME = 1.0
const SPECIAL_TAP_TIME = 0.2
const SPECIAL_REGEN_PER_SECOND = 12.0
const SPECIAL_MAX = 100.0
const SPECIAL_COST_TAP = 15.0
const SPECIAL_COST_HOLD = 35.0
const SPECIAL_COST_FULL = 75.0
const MAX_HEALTH = 100.0
const FIREBALL_SCENE_PATH = "res://scenes/projectiles/fireball.tscn"
const ATTACK_IMPULSE_LIGHT1 = 0.8
const ATTACK_IMPULSE_LIGHT2 = 1.0
const ATTACK_IMPULSE_LIGHT3 = 1.5
const ATTACK_IMPULSE_HEAVY = 1.5
const FLASH_KICK_IMPULSE = 1.5
const MOVE_ACCEL = 18.0
const MOVE_DECEL = 20.0
const MOVE_BRAKE = 28.0
const SMASH_HIT_STUN = 1.0
const SMASH_DAMAGE = 22.0
const SMASH_KNOCKBACK = 22.0
const MAX_STOCKS = 3
const HIT_STUN_LIGHT = 0.35
const HIT_STUN_MED = 0.6
const HIT_STUN_HEAVY = 0.9
const FALLEN_TIME = 1.5
const DIZZY_TIME = 1.25

enum SkinColor { BLUE, YELLOW, GREEN, RED }
enum CombatState { ALIVE, HITSTUN, DIZZY, FALLEN, DEAD }

var player_inventory: PlayerInventory

@export_category("Objects")
@export var body: Node3D = null
@export var _spring_arm_offset: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera_presets := [
	{"length": 2.5, "offset": Vector3(0, 0.0, 0)},
	{"length": 4.0, "offset": Vector3(0, 0.5, 0)},
	{"length": 1.6, "offset": Vector3(0, 0.4, 0.5)}
]
var _camera_preset_index: int = 0
var is_ai: bool = false
var _current_target: Node3D = null

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
var _jump_windup: float = 0.0
var _jump_pending: bool = false
var _punch_combo_index: int = 0
var _kick_combo_index: int = 0
var _last_punch_time: float = 0.0
var _last_kick_time: float = 0.0
var _punch_hold_time: float = 0.0
var _kick_hold_time: float = 0.0
var _special_charge_time: float = 0.0
var _special_meter: float = SPECIAL_MAX
var damage_percent: float = 0.0
var stocks: int = MAX_STOCKS
var _special_holding: bool = false
var _state: CombatState = CombatState.ALIVE
var _state_timer: float = 0.0
var _hitlag_timer: float = 0.0
var _attack_impulse: Vector3 = Vector3.ZERO
var _ai_attack_cooldown: float = 0.0
var _ai_target_refresh: float = 0.0
var _ai_move_dir: Vector3 = Vector3.ZERO
var _is_shielding: bool = false
var _shield_strength: float = 100.0
var _shield_regen_cooldown: float = 0.0

func _enter_tree():
	var auth = str(name).to_int()
	if auth == 0:
		auth = 1
	set_multiplayer_authority(auth)

func _ready():
	_state = CombatState.ALIVE
	# Ensure the camera is current for the local player
	if is_multiplayer_authority() and not is_ai and name == str(multiplayer.get_unique_id()):
		if _spring_arm_offset:
			_spring_arm = _spring_arm_offset.get_node_or_null("SpringArm3D") as SpringArm3D
		var cam = get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D")
		if cam:
			cam.current = true
		_apply_camera_preset()
	else:
		var cam_other = get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D")
		if cam_other:
			cam_other.current = false
	# Hide nickname label entirely
	var nick_node = get_node_or_null("PlayerNick")
	if nick_node:
		nick_node.visible = false
			
	# Ensure a character model is present. If not, default to Kyle.

	# The placeholder in player.tscn might handle this, but explicit initialization is safer.
	if not has_node("CharacterModel") and not has_node("3DGodotRobot"):
		var switcher = load("res://scripts/character_switcher.gd").new()
		switcher.set_model(self, "kyle")
		switcher.queue_free()

	# Make sure the body controller script and shared animations are wired even for pre-placed scenes.
	if body and not (body is RobotBodyController):
		var body_script = load("res://scripts/3d_godot_robot.gd")
		if body_script:
			body.set_script(body_script)
			body.character = self
	# Always run the helper to attach shared animation player/animations.
	if body:
		var helper = load("res://scripts/character_model_helper.gd").new()
		if helper and helper.has_method("setup_character_model"):
			helper.setup_character_model(body)
			helper.free()

	find_model_meshes()
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
	if not is_multiplayer_authority(): return

	if _state == CombatState.DEAD:
		velocity = Vector3.ZERO
		return

	if _hitlag_timer > 0.0:
		_hitlag_timer -= delta
		velocity = Vector3.ZERO
		return

	if _state == CombatState.DIZZY or _state == CombatState.FALLEN:
		_state_timer -= delta
		if _state == CombatState.FALLEN:
			# stay down until timer and on floor
			if _state_timer <= 0.0 and is_on_floor():
				body.play_attack("GetUp", "GetUp")
				_state = CombatState.ALIVE
		elif _state == CombatState.DIZZY:
			if _state_timer <= 0.0:
				_state = CombatState.ALIVE
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		velocity.y -= gravity * delta
		move_and_slide()
		return

	if _state == CombatState.HITSTUN:
		_state_timer -= delta
		if not is_on_floor():
			velocity.y -= gravity * delta
		# Directional influence: allow slight steering
		if not is_ai:
			var di = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if di.length() > 0.1:
				var di3 = transform.basis * Vector3(di.x, 0, di.y)
				di3.y = 0
				di3 = di3.normalized()
				velocity = velocity.slerp(di3 * velocity.length(), 0.05)
		move_and_slide()
		if _state_timer <= 0.0:
			_state = CombatState.ALIVE
		return

	if is_ai:
		_ai_update(delta)

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

	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false
		if not is_ai:
			# Add a small windup so the jump feels more natural
			if Input.is_action_just_pressed("jump") and not _jump_pending:
				_jump_windup = JUMP_WINDUP_TIME
				_jump_pending = true
				body.play_jump_animation("Jump")
		if _jump_pending:
			_jump_windup -= delta
			if _jump_windup <= 0.0:
				velocity.y = JUMP_VELOCITY
				can_double_jump = true
				_jump_pending = false
	else:
		_jump_pending = false
		velocity.y -= gravity * delta

		if not is_ai and can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			body.play_jump_animation("Jump2")

	_handle_combat_input(delta)
	_move(delta)
	move_and_slide()
	if body and body.has_method("tick_attack_lock"):
		body.tick_attack_lock(delta)
	body.animate(velocity)

func _process(_delta):
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()
	if Input.is_action_just_pressed("camera_cycle"):
		cycle_camera_preset()

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	body.animate(Vector3.ZERO)

func _move(delta: float) -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority() and not is_ai:
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_backward"
			)
	elif is_ai:
		_input_direction = Vector2(_ai_move_dir.x, _ai_move_dir.z)

	var _direction: Vector3 = transform.basis * Vector3(
		_input_direction.x, 0, _input_direction.y
	).normalized()

	# During attack lock, suppress player-driven movement
	if body and body.attack_lock_timer > 0.0:
		_direction = Vector3.ZERO
	else:
		is_running()
		if _spring_arm_offset:
			_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	var target_vel = Vector3.ZERO
	if _direction:
		target_vel.x = _direction.x * _current_speed
		target_vel.z = _direction.z * _current_speed
		body.apply_rotation(target_vel)

	var accel = MOVE_ACCEL
	if target_vel.length() < velocity.length():
		accel = MOVE_DECEL
	if _direction == Vector3.ZERO:
		accel = MOVE_BRAKE

	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	# apply any queued attack impulse (forward burst)
	if _attack_impulse.length() > 0.01:
		velocity.x += _attack_impulse.x
		velocity.z += _attack_impulse.z
		_attack_impulse = _attack_impulse.move_toward(Vector3.ZERO, delta * 5)

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	_current_speed = NORMAL_SPEED
	return false

func _check_fall_and_respawn():
	if _state == CombatState.DEAD:
		return
	if global_transform.origin.y < -20.0 or abs(global_transform.origin.x) > 35.0 or abs(global_transform.origin.z) > 35.0:
		_handle_ko()

func _respawn():
	if _state == CombatState.DEAD:
		return
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	damage_percent = 0.0

func _handle_ko():
	stocks -= 1
	if stocks <= 0:
		_state = CombatState.DEAD
		body.play_attack("Death", "Dizzy")
		emit_signal("player_died", self)
		return
	_state = CombatState.ALIVE
	_respawn()

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	pass

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

func _handle_combat_input(delta: float) -> void:
	if _state != CombatState.ALIVE:
		return
	if is_ai:
		return
	# Regenerate special meter over time
	_special_meter = clamp(_special_meter + SPECIAL_REGEN_PER_SECOND * delta, 0.0, SPECIAL_MAX)
	_shield_regen_cooldown = max(0.0, _shield_regen_cooldown - delta)
	if not _is_shielding and _shield_regen_cooldown <= 0.0:
		_shield_strength = clamp(_shield_strength + 20.0 * delta, 0.0, 100.0)

	# Blocking
	_is_shielding = Input.is_action_pressed("block")
	if _is_shielding:
		body.play_attack("Block", "Idle")

	# Smash stick (C-stick / arrow keys for now)
	var smash_dir := _read_smash_input()
	if smash_dir != Vector2.ZERO and body.attack_lock_timer <= 0.0:
		_play_smash(smash_dir)

	# Punch logic (tap combo / hold heavy)
	if Input.is_action_pressed("light_punch"):
		_punch_hold_time += delta
	if Input.is_action_just_released("light_punch"):
		if _punch_hold_time >= HEAVY_HOLD_TIME:
			_play_punch(true)
		else:
			_play_punch(false)
		_punch_hold_time = 0.0
	elif Input.is_action_just_pressed("light_punch"):
		_punch_hold_time = 0.0

	# Kick logic (tap combo / hold heavy)
	if Input.is_action_pressed("light_kick"):
		_kick_hold_time += delta
	if Input.is_action_just_released("light_kick"):
		if _kick_hold_time >= HEAVY_HOLD_TIME:
			_play_kick(true)
		else:
			_play_kick(false)
		_kick_hold_time = 0.0
	elif Input.is_action_just_pressed("light_kick"):
		_kick_hold_time = 0.0

	# Special logic: tap vs hold vs full charge
	if Input.is_action_just_pressed("special_attack"):
		_special_charge_time = 0.0
		_special_holding = true
	if _special_holding and Input.is_action_pressed("special_attack"):
		_special_charge_time += delta
	if _special_holding and Input.is_action_just_released("special_attack"):
		_trigger_special()
		_special_holding = false

func _play_punch(is_heavy: bool) -> void:
	if body.attack_lock_timer > 0.0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if is_heavy:
		body.play_attack("Punch_Heavy", "Punch_Combo1")
		_punch_combo_index = 0
		_apply_attack_impulse(ATTACK_IMPULSE_HEAVY)
		return

	if now - _last_punch_time > COMBO_WINDOW:
		_punch_combo_index = 0
	var punch_anims = ["Punch_Combo1", "Punch_Combo2", "Punch_Combo3"]
	body.play_attack(punch_anims[_punch_combo_index], "Punch_Combo1")
	if _punch_combo_index == 0:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT1)
	elif _punch_combo_index == 1:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT2)
	else:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT3)
	_punch_combo_index = (_punch_combo_index + 1) % punch_anims.size()
	_last_punch_time = now

func _play_kick(is_heavy: bool) -> void:
	if body.attack_lock_timer > 0.0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if is_heavy:
		body.play_attack("Kick_Heavy", "Kick_Combo1")
		_kick_combo_index = 0
		_apply_attack_impulse(ATTACK_IMPULSE_HEAVY)
		return

	if now - _last_kick_time > COMBO_WINDOW:
		_kick_combo_index = 0
	var kick_anims = ["Kick_Combo1", "Kick_Combo2", "Kick_Combo3"]
	body.play_attack(kick_anims[_kick_combo_index], "Kick_Combo1")
	if _kick_combo_index == 0:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT1)
	elif _kick_combo_index == 1:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT2)
	else:
		_apply_attack_impulse(ATTACK_IMPULSE_LIGHT3)
	_kick_combo_index = (_kick_combo_index + 1) % kick_anims.size()
	_last_kick_time = now

func _trigger_special() -> void:
	var state = "tap"
	if _special_charge_time >= SPECIAL_FULL_CHARGE_TIME and _special_meter >= SPECIAL_COST_FULL:
		state = "full"
	elif _special_charge_time >= SPECIAL_TAP_TIME and _special_meter >= SPECIAL_COST_HOLD:
		state = "hold"

	match state:
		"full":
			_special_meter -= SPECIAL_COST_FULL
			body.play_attack("Special_Charged", "FlashKick")
			_spawn_fireball(true)
		"hold":
			_special_meter -= SPECIAL_COST_HOLD
			body.play_attack("FlashKick", "Kick_Heavy")
			_apply_attack_impulse(FLASH_KICK_IMPULSE)
		_:
			if _special_meter >= SPECIAL_COST_TAP:
				_special_meter -= SPECIAL_COST_TAP
				body.play_attack("Fireball", "Punch_Combo1")
				_spawn_fireball(false)

func get_health_fraction() -> float:
	# Map percent to 0..1 for any UI; 0% -> full, cap at 300%
	return clamp(1.0 - (damage_percent / 300.0), 0.0, 1.0)

func get_special_fraction() -> float:
	return clamp(_special_meter / SPECIAL_MAX, 0.0, 1.0)

func apply_damage(amount: float, direction: Vector3 = Vector3.ZERO, base_knockback: float = 6.0, scaling: float = 0.25) -> void:
	if _state == CombatState.DEAD:
		return
	if _is_shielding and _state == CombatState.ALIVE:
		var blocked = amount * 0.8
		_shield_strength -= blocked
		_shield_regen_cooldown = 1.0
		if _shield_strength <= 0.0:
			_enter_shield_break()
		return
	damage_percent += amount
	var knock = (base_knockback + scaling * damage_percent)
	if direction == Vector3.ZERO:
		direction = -global_transform.basis.z
	direction.y = 0.25
	direction = direction.normalized()
	velocity = direction * knock
	_state = CombatState.HITSTUN
	_state_timer = max(HIT_STUN_LIGHT, min(HIT_STUN_HEAVY, knock * 0.05))
	_hitlag_timer = min(0.35, 0.12 + amount * 0.004)
	if amount > 25:
		body.play_attack("Fall", "Jump")
	elif amount > 12:
		body.play_attack("Dizzy", "Block")
	else:
		body.play_attack("Block", "Idle")

func cycle_camera_preset() -> void:
	if _camera_presets.size() == 0:
		return
	_camera_preset_index = (_camera_preset_index + 1) % _camera_presets.size()
	_apply_camera_preset()

func cycle_target(opponents: Array) -> void:
	if opponents.is_empty():
		_current_target = null
		return
	# Sort by distance
	opponents.sort_custom(func(a, b):
		var da = global_transform.origin.distance_squared_to(a.global_transform.origin)
		var db = global_transform.origin.distance_squared_to(b.global_transform.origin)
		return da < db
	)
	var idx = 0
	if _current_target:
		idx = opponents.find(_current_target)
		if idx == -1:
			idx = 0
		else:
			idx = (idx + 1) % opponents.size()
	_current_target = opponents[idx]

func _apply_camera_preset() -> void:
	if _camera_presets.size() == 0:
		return
	var preset = _camera_presets[_camera_preset_index]
	if _spring_arm:
		if "length" in preset:
			_spring_arm.spring_length = preset.length
	if _spring_arm_offset:
		var offset := Vector3.ZERO
		if "offset" in preset:
			offset = preset.offset
		_spring_arm_offset.transform.origin = offset

func _apply_attack_impulse(strength: float) -> void:
	var forward = -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized() * strength
	_attack_impulse = forward

func _read_smash_input() -> Vector2:
	var dir := Vector2.ZERO
	var h = Input.get_action_strength("smash_right") - Input.get_action_strength("smash_left")
	var v = Input.get_action_strength("smash_down") - Input.get_action_strength("smash_up")
	if abs(h) > 0.2:
		dir.x = sign(h)
	if abs(v) > 0.2:
		dir.y = sign(v)
	return dir

func _play_smash(dir: Vector2) -> void:
	var anim = "Punch_Heavy"
	if dir.y < 0:
		anim = "Kick_Heavy"
	elif dir.y > 0:
		anim = "Special_Charged"
	body.play_attack(anim, anim)
	_apply_attack_impulse(ATTACK_IMPULSE_HEAVY)

func _enter_shield_break():
	_is_shielding = false
	_shield_strength = 0.0
	_state = CombatState.DIZZY
	_state_timer = DIZZY_TIME * 1.5
	body.play_attack("Dizzy", "Block")

func _spawn_fireball(charged: bool) -> void:
	var scene: PackedScene = null
	if ResourceLoader.exists(FIREBALL_SCENE_PATH):
		scene = load(FIREBALL_SCENE_PATH)
	var fireball = null
	if scene:
		fireball = scene.instantiate()
	else:
		# Minimal projectile if scene missing
		fireball = Area3D.new()
	if not fireball:
		return
	if fireball.has_method("setup"):
		fireball.setup(self, charged)
	else:
		fireball.global_transform = global_transform
	get_tree().current_scene.add_child(fireball)

func _ai_update(delta: float) -> void:
	_ai_target_refresh -= delta
	if _ai_target_refresh <= 0.0 or _current_target == null or (_current_target is PlayerCharacter and _current_target._state == CombatState.DEAD):
		_current_target = _find_nearest_opponent()
		_ai_target_refresh = 1.0

	if _current_target:
		var to_target = _current_target.global_transform.origin - global_transform.origin
		to_target.y = 0
		if to_target.length() > 0.2:
			var dir = to_target.normalized()
			_ai_move_dir = Vector3(dir.x, 0, dir.z)
			# Face the target
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.08)
		else:
			_ai_move_dir = Vector3.ZERO

		var dist = to_target.length()
		_ai_attack_cooldown -= delta
		if dist < 2.5 and _ai_attack_cooldown <= 0.0:
			var heavy = dist > 2.0 and randf() > 0.5
			if randf() > 0.5:
				_play_punch(heavy)
			else:
				_play_kick(heavy)
			_ai_attack_cooldown = 1.0 + randf() * 0.5
	else:
		_ai_move_dir = Vector3.ZERO

func _find_nearest_opponent() -> PlayerCharacter:
	if not get_parent():
		return null
	var best: PlayerCharacter = null
	var best_d = INF
	for child in get_parent().get_children():
		if child is PlayerCharacter and child != self:
			if child._state == CombatState.DEAD:
				continue
			var d = global_transform.origin.distance_squared_to(child.global_transform.origin)
			if d < best_d:
				best_d = d
				best = child
	return best

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
