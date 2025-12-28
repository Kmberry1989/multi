extends Node3D
class_name Body

const LERP_VELOCITY: float = 0.15

@export_category("Objects")
@export var character: Node3D = null
@export var animation_player: AnimationPlayer = null

func apply_rotation(_velocity: Vector3) -> void:
	if not character: return
	var new_rotation_y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y

func animate(_velocity: Vector3) -> void:
	# Safety check: if _character is not a CharacterBody3D (e.g. preview mode), don't access physics methods
	if not character or not character is CharacterBody3D:
		if animation_player:
			if animation_player.current_animation != "Idle":
				animation_player.play("Idle")
		return

	if not character.is_on_floor():
		if _velocity.y < 0:
			animation_player.play("Fall")
		else:
			var current_anim = animation_player.current_animation
			if current_anim != "Jump" and current_anim != "Jump2":
				animation_player.play("Jump")
		return

	if _velocity:
		if character.is_running() and character.is_on_floor():
			animation_player.play("Sprint")
			return

		animation_player.play("Run")
		return

	animation_player.play("Idle")

func play_jump_animation(jump_type: String = "Jump") -> void:
	if animation_player:
		animation_player.play(jump_type)
