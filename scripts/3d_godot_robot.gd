extends Node3D
class_name RobotBodyController

const LERP_VELOCITY: float = 0.15

@export_category("Objects")
@export var character: Node3D = null
@export var animation_player: AnimationPlayer = null
var attack_lock_timer: float = 0.0
var _pending_attack: Dictionary = {}

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
	# Skip locomotion while an attack is playing.
	if attack_lock_timer > 0.0:
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

func play_attack(anim: String, fallback: String = "") -> void:
	# External callers (player controller) can request arbitrary attack animations.
	# If an attack is already playing, queue the next one to avoid interruption.
	if attack_lock_timer > 0.05:
		_pending_attack = {"anim": anim, "fallback": fallback}
		return
	_play_animation(anim, fallback)
	if animation_player:
		var len := 0.5
		if animation_player.has_animation(anim):
			var a = animation_player.get_animation(anim)
			if a:
				len = a.length
		attack_lock_timer = max(attack_lock_timer, len)

func tick_attack_lock(delta: float) -> void:
	if attack_lock_timer > 0.0:
		attack_lock_timer = max(0.0, attack_lock_timer - delta)
	if attack_lock_timer <= 0.0 and _pending_attack.size() > 0:
		var anim = _pending_attack.get("anim", "")
		var fallback = _pending_attack.get("fallback", "")
		_pending_attack.clear()
		play_attack(anim, fallback)
