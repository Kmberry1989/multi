extends Control
class_name MicrogamePromptUI

@onready var prompt_panel: PanelContainer = $PromptPanel
@onready var prompt_label: Label = $PromptPanel/MarginContainer/VBoxContainer/PromptLabel
@onready var instruction_label: Label = $PromptPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var timer_label: Label = $PromptPanel/MarginContainer/VBoxContainer/TimerLabel
@onready var timer_bar: ProgressBar = $PromptPanel/MarginContainer/VBoxContainer/TimerBar

@onready var summary_panel: PanelContainer = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/MarginContainer/VBoxContainer/SummaryLabel
@onready var summary_score_label: Label = $SummaryPanel/MarginContainer/VBoxContainer/SummaryScoreLabel
@onready var summary_timer_label: Label = $SummaryPanel/MarginContainer/VBoxContainer/SummaryTimerLabel
@onready var summary_timer_bar: ProgressBar = $SummaryPanel/MarginContainer/VBoxContainer/SummaryTimerBar

var _interstitial_time_left := 0.0
var _interstitial_duration := 0.0
var _interstitial_active := false

func _ready() -> void:
	prompt_panel.hide()
	summary_panel.hide()
	set_process(false)

func show_prompt(prompt: String, instruction: String, duration: float) -> void:
	_interstitial_active = false
	set_process(false)

	prompt_panel.show()
	summary_panel.hide()
	prompt_label.text = prompt
	instruction_label.text = instruction
	timer_bar.max_value = duration
	timer_bar.value = duration
	timer_label.text = "%.1f" % duration

func update_round_time(time_left: float, duration: float) -> void:
	if not prompt_panel.visible:
		return
	var clamped = max(0.0, time_left)
	timer_bar.max_value = duration
	timer_bar.value = clamped
	timer_label.text = "%.1f" % clamped

func show_interstitial(round_index: int, score_delta: int, total_score: int, duration: float) -> void:
	prompt_panel.hide()
	summary_panel.show()

	summary_label.text = "Round %d complete!" % round_index
	summary_score_label.text = "Score +%d | Total %d" % [score_delta, total_score]

	_interstitial_duration = duration
	_interstitial_time_left = duration
	_interstitial_active = true
	set_process(true)
	_update_interstitial_timer()

func show_sequence_complete(total_score: int) -> void:
	prompt_panel.hide()
	summary_panel.show()
	summary_label.text = "Microgame set complete!"
	summary_score_label.text = "Final score: %d" % total_score
	summary_timer_label.text = ""
	summary_timer_bar.value = 0
	_interstitial_active = false
	set_process(false)

func _process(delta: float) -> void:
	if not _interstitial_active:
		return
	_interstitial_time_left = max(0.0, _interstitial_time_left - delta)
	_update_interstitial_timer()
	if _interstitial_time_left <= 0.0:
		_interstitial_active = false
		set_process(false)

func _update_interstitial_timer() -> void:
	summary_timer_bar.max_value = _interstitial_duration
	summary_timer_bar.value = _interstitial_time_left
	summary_timer_label.text = "Next round in %.1f" % _interstitial_time_left
