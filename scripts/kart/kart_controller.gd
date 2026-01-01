extends RigidBody3D
class_name KartController

@export var acceleration_force: float = 40.0
@export var brake_force: float = 60.0
@export var max_speed: float = 25.0
@export var steer_torque: float = 8.0
@export var drift_grip: float = 0.7
@export var lateral_grip: float = 6.0

@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

var _throttle_input := 0.0
var _steer_input := 0.0
var _is_drifting := false

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if is_multiplayer_authority() and camera:
		camera.current = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	_throttle_input = Input.get_action_strength("kart_accelerate") - Input.get_action_strength("kart_brake")
	_steer_input = Input.get_action_strength("kart_steer_right") - Input.get_action_strength("kart_steer_left")
	_is_drifting = Input.is_action_pressed("kart_drift")

	_apply_drive_forces(delta)
	_apply_steering(delta)
	_apply_grip(delta)
	_clamp_speed()

func _apply_drive_forces(delta: float) -> void:
	if abs(_throttle_input) < 0.01:
		return

	var forward = -global_transform.basis.z
	var force = forward * acceleration_force * _throttle_input
	if _throttle_input < 0.0:
		force = forward * brake_force * _throttle_input

	apply_central_force(force)

func _apply_steering(_delta: float) -> void:
	if abs(_steer_input) < 0.01:
		return

	var speed_factor = clamp(linear_velocity.length() / max_speed, 0.2, 1.0)
	apply_torque(Vector3.UP * _steer_input * steer_torque * speed_factor)

func _apply_grip(delta: float) -> void:
	var basis = global_transform.basis
	var forward = -basis.z
	var right = basis.x
	var forward_speed = linear_velocity.dot(forward)
	var lateral_speed = linear_velocity.dot(right)

	var grip_strength = lateral_grip
	if _is_drifting:
		grip_strength *= drift_grip

	var lateral_correction = -right * lateral_speed * grip_strength
	apply_central_force(lateral_correction / max(delta, 0.001))

	var damped_lateral = lerp(lateral_speed, 0.0, clamp(grip_strength * delta, 0.0, 1.0))
	linear_velocity = forward * forward_speed + right * damped_lateral

func _clamp_speed() -> void:
	var speed = linear_velocity.length()
	if speed <= max_speed:
		return
	linear_velocity = linear_velocity.normalized() * max_speed
