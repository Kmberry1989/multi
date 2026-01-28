extends Area3D

@export var speed: float = 12.0
@export var damage: float = 25.0
@export var lifetime: float = 3.0
@export var hit_vfx_scene: PackedScene = null
@export var hit_vfx_lifetime: float = 0.35
@onready var _deep_raycast: DeepRayCast3D = $DeepRayCast3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var _dir: Vector3 = Vector3.ZERO
var _owner: Node = null
var _collision_radius: float = 0.35

func setup(projectile_owner: Node, charged: bool) -> void:
	_owner = projectile_owner
	_dir = -projectile_owner.global_transform.basis.z
	_dir.y = 0
	_dir = _dir.normalized()
	if charged:
		damage = 45.0
		speed = 16.0
		scale = Vector3.ONE * 1.4
	global_transform.origin = owner.global_transform.origin + _dir * 1.0 + Vector3.UP * 0.8
	if is_instance_valid(_deep_raycast):
		if _owner is PhysicsBody3D:
			_deep_raycast.add_exclude(_owner)
		_deep_raycast.collision_mask = collision_mask

func _ready():
	if is_instance_valid(_collision_shape) and _collision_shape.shape is SphereShape3D:
		_collision_radius = _collision_shape.shape.radius
	if is_instance_valid(_deep_raycast):
		monitoring = false
	else:
		monitoring = true
		connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	if is_instance_valid(_deep_raycast):
		_deep_raycast.forward_distance = speed * delta + _collision_radius
		_deep_raycast._update_raycast()
		if _deep_raycast.get_collider_count() > 0:
			_handle_hit(_deep_raycast.get_collider(0), _deep_raycast.get_hit_position(0))
			return
	global_translate(_dir * speed * delta)

func _on_body_entered(body: Node):
	_handle_hit(body, global_transform.origin)

func _handle_hit(body: Node, hit_position: Vector3) -> void:
	if body == _owner:
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage, _dir, damage * 0.3, 0.35)
	_spawn_hit_vfx(hit_position)
	queue_free()

func _spawn_hit_vfx(hit_position: Vector3) -> void:
	if hit_vfx_scene:
		var vfx_instance = hit_vfx_scene.instantiate()
		if vfx_instance is Node3D:
			vfx_instance.global_transform.origin = hit_position
		get_tree().current_scene.add_child(vfx_instance)
		return

	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	flash.mesh = mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2, 1.0)
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.7)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat

	flash.global_transform.origin = hit_position
	get_tree().current_scene.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 0.6, hit_vfx_lifetime)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, hit_vfx_lifetime)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, hit_vfx_lifetime)
	tween.tween_callback(Callable(flash, "queue_free"))
