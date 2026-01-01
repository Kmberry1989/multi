extends Area3D

@export var speed: float = 12.0
@export var damage: float = 25.0
@export var lifetime: float = 3.0
var _dir: Vector3 = Vector3.ZERO
var _owner: Node = null

func setup(owner: Node, charged: bool) -> void:
	_owner = owner
	_dir = -owner.global_transform.basis.z
	_dir.y = 0
	_dir = _dir.normalized()
	if charged:
		damage = 45.0
		speed = 16.0
		scale = Vector3.ONE * 1.4
	global_transform.origin = owner.global_transform.origin + _dir * 1.0 + Vector3.UP * 0.8

func _ready():
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	global_translate(_dir * speed * delta)

func _on_body_entered(body: Node):
	if body == _owner:
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage, _dir, damage * 0.3, 0.35)
	queue_free()
