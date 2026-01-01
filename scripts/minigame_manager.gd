extends Node
class_name MinigameManager

signal microgame_started(index: int, microgame_data: Dictionary, duration: float)
signal microgame_finished(index: int, microgame_data: Dictionary, success: bool, score_delta: int, total_score: int)
signal sequence_finished(total_score: int)
signal round_time_updated(time_left: float, duration: float)

@export var microgame_duration_min := 3.0
@export var microgame_duration_max := 7.0
@export var microgame_container_path: NodePath

var microgames: Array = []
var current_index := -1
var current_round_duration := 0.0
var current_score := 0
var microgame_mode := true

var _current_microgame_instance: Node
var _round_timer: Timer
var _container: Node

func _ready() -> void:
	_round_timer = Timer.new()
	_round_timer.one_shot = true
	add_child(_round_timer)
	_round_timer.timeout.connect(_on_round_timeout)

	if microgame_container_path != NodePath(""):
		_container = get_node_or_null(microgame_container_path)

	set_process(true)

func _process(_delta: float) -> void:
	if _round_timer and not _round_timer.is_stopped():
		round_time_updated.emit(_round_timer.time_left, current_round_duration)

func start_microgame_sequence(microgame_list: Array, use_microgame_mode := true) -> void:
	microgames = microgame_list.duplicate()
	microgame_mode = use_microgame_mode
	current_index = -1
	current_score = 0
	start_next_microgame()

func start_next_microgame() -> void:
	_cleanup_microgame_instance()
	current_index += 1

	if current_index >= microgames.size():
		sequence_finished.emit(current_score)
		return

	var microgame_data: Dictionary = microgames[current_index]
	current_round_duration = _pick_round_duration(microgame_data)
	_spawn_microgame(microgame_data)
	_round_timer.start(current_round_duration)
	microgame_started.emit(current_index, microgame_data, current_round_duration)

func complete_current_microgame(success: bool, score_delta: int) -> void:
	if _round_timer and not _round_timer.is_stopped():
		_round_timer.stop()
	_finalize_microgame(success, score_delta)

func _pick_round_duration(microgame_data: Dictionary) -> float:
	if microgame_mode:
		return randf_range(microgame_duration_min, microgame_duration_max)
	return float(microgame_data.get("duration", microgame_duration_max))

func _spawn_microgame(microgame_data: Dictionary) -> void:
	var scene: PackedScene = microgame_data.get("scene")
	if scene == null:
		return

	_current_microgame_instance = scene.instantiate()
	if _container:
		_container.add_child(_current_microgame_instance)
	else:
		add_child(_current_microgame_instance)

func _on_round_timeout() -> void:
	_finalize_microgame(false, 0)

func _finalize_microgame(success: bool, score_delta: int) -> void:
	_cleanup_microgame_instance()
	current_score += score_delta
	var microgame_data: Dictionary = {}
	if current_index >= 0 and current_index < microgames.size():
		microgame_data = microgames[current_index]
	microgame_finished.emit(current_index, microgame_data, success, score_delta, current_score)

func _cleanup_microgame_instance() -> void:
	if _current_microgame_instance and is_instance_valid(_current_microgame_instance):
		_current_microgame_instance.queue_free()
	_current_microgame_instance = null
