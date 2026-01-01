extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/level/player.tscn")
@export var enable_cpu_opponent: bool = false

@onready var players_container: Node3D = $PlayersContainer
@onready var spawn_one: Marker3D = $PlayerSpawn1
@onready var spawn_two: Marker3D = $PlayerSpawn2
@onready var cpu_spawn: Marker3D = $CpuSpawn

var _cpu_player: PlayerCharacter

func _ready() -> void:
	if not players_container:
		players_container = self

	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

	for id in Network.players.keys():
		_add_player(id, Network.players[id])

	if enable_cpu_opponent and multiplayer.is_server():
		_spawn_cpu()

func _physics_process(_delta: float) -> void:
	if _cpu_player:
		var target = _get_closest_player(_cpu_player)
		if target:
			_cpu_player.set_cpu_target(target)

func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	_add_player(peer_id, player_info)

func _add_player(id: int, player_info: Dictionary) -> void:
	if players_container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.mode = PlayerCharacter.Mode.BRAWL
	player.position = _get_spawn_point(id)
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.nickname.text = nick
	player.set_player_skin(player_info["skin"])

func _spawn_cpu() -> void:
	if _cpu_player:
		return

	var cpu = player_scene.instantiate()
	cpu.name = "cpu"
	cpu.position = cpu_spawn.global_transform.origin
	cpu.mode = PlayerCharacter.Mode.BRAWL
	cpu.is_cpu = true
	cpu.nickname.text = "CPU"
	players_container.add_child(cpu, true)
	_cpu_player = cpu

func _get_spawn_point(id: int) -> Vector3:
	if id == 1:
		return spawn_one.global_transform.origin
	return spawn_two.global_transform.origin

func _get_closest_player(source: PlayerCharacter) -> PlayerCharacter:
	var closest: PlayerCharacter = null
	var closest_dist := INF

	for child in players_container.get_children():
		if child == source:
			continue
		if not child is PlayerCharacter:
			continue
		var dist = source.global_transform.origin.distance_to(child.global_transform.origin)
		if dist < closest_dist:
			closest_dist = dist
			closest = child

	return closest

func _remove_player(id: int) -> void:
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
