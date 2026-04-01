extends Node3D
class_name SpringArmCharacter

const MOUSE_SENSIBILITY: float = 0.005
const TOUCH_SENSIBILITY: float = 0.0075

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null

func _unhandled_input(_event) -> void:
	if (_event is InputEventMouseMotion) and is_multiplayer_authority():
		if owner and "is_ai" in owner and owner.is_ai:
			return
		apply_look_delta(_event.relative, MOUSE_SENSIBILITY)

func apply_look_delta(relative: Vector2, sensitivity: float = TOUCH_SENSIBILITY) -> void:
	if _spring_arm == null:
		return
	rotate_y(-relative.x * sensitivity)
	_spring_arm.rotate_x(-relative.y * sensitivity)
	_spring_arm.rotation.x = clamp(_spring_arm.rotation.x, -PI / 4, PI / 24)
