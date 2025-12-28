extends Node3D
class_name RobotBodyController

const LERP_VELOCITY: float = 0.15

@export_category("Objects")
@export var character: Node3D = null
@export var animation_player: AnimationPlayer = null

func _play_animation(name: String, fallback: String = "") -> void:
	if not animation_player:
		return
	if animation_player.has_animation(name):
		animation_player.play(name)
		return
	if fallback != "" and animation_player.has_animation(fallback):
		animation_player.play(fallback)

func apply_rotation(_velocity: Vector3) -> void:
	if not character: return
	var new_rotation_y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y

func animate(_velocity: Vector3) -> void:
	if not animation_player:
		return
	# Safety check: if _character is not a CharacterBody3D (e.g. preview mode), 
	# don't access physics methods
	if not character or not character is CharacterBody3D:
		if animation_player:
			if animation_player.current_animation != "Idle":
				_play_animation("Idle")
		return

	if not character.is_on_floor():
		if _velocity.y < 0:
			_play_animation("Fall", "Jump")
		else:
			var current_anim = animation_player.current_animation
			if current_anim != "Jump" and current_anim != "Jump2":
				_play_animation("Jump")
		return

	if _velocity:
		if character.is_running() and character.is_on_floor():
			_play_animation("Sprint", "Run")
			return

		_play_animation("Run")
		return

	_play_animation("Idle")

func play_jump_animation(jump_type: String = "Jump") -> void:
	if animation_player:
		_play_animation(jump_type, "Jump")
