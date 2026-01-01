extends Node
class_name GameDirector

@export var microgame_prompt_ui_scene: PackedScene = preload("res://scenes/ui/microgame_prompt_ui.tscn")
@export var interstitial_duration := 1.5
@export var microgame_duration_min := 3.0
@export var microgame_duration_max := 7.0
@export var microgame_container_path: NodePath

var minigame_manager: MinigameManager
var prompt_ui: MicrogamePromptUI

func _ready() -> void:
	minigame_manager = get_node_or_null("MinigameManager")
	if not minigame_manager:
		minigame_manager = MinigameManager.new()
		minigame_manager.name = "MinigameManager"
		add_child(minigame_manager)

	minigame_manager.microgame_duration_min = microgame_duration_min
	minigame_manager.microgame_duration_max = microgame_duration_max
	minigame_manager.microgame_container_path = microgame_container_path

	minigame_manager.microgame_started.connect(_on_microgame_started)
	minigame_manager.microgame_finished.connect(_on_microgame_finished)
	minigame_manager.sequence_finished.connect(_on_sequence_finished)
	minigame_manager.round_time_updated.connect(_on_round_time_updated)

	if microgame_prompt_ui_scene:
		prompt_ui = microgame_prompt_ui_scene.instantiate()
		add_child(prompt_ui)
		prompt_ui.hide()

func start_microgame_sequence(microgames: Array) -> void:
	if prompt_ui:
		prompt_ui.show()
	minigame_manager.start_microgame_sequence(microgames, true)

func _on_microgame_started(index: int, microgame_data: Dictionary, duration: float) -> void:
	if not prompt_ui:
		return
	prompt_ui.show_prompt(
		str(microgame_data.get("prompt", "Get ready!")),
		str(microgame_data.get("instruction", "")),
		duration
	)

func _on_microgame_finished(index: int, microgame_data: Dictionary, success: bool, score_delta: int, total_score: int) -> void:
	if prompt_ui:
		prompt_ui.show_interstitial(index + 1, score_delta, total_score, interstitial_duration)

	await get_tree().create_timer(interstitial_duration).timeout
	minigame_manager.start_next_microgame()

func _on_sequence_finished(total_score: int) -> void:
	if prompt_ui:
		prompt_ui.show_sequence_complete(total_score)

func _on_round_time_updated(time_left: float, duration: float) -> void:
	if prompt_ui:
		prompt_ui.update_round_time(time_left, duration)
