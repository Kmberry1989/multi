extends Control
class_name BoardHUD

signal roll_pressed

@onready var current_player_label: Label = $Panel/Margin/VBox/TurnInfo
@onready var round_label: Label = $Panel/Margin/VBox/RoundInfo
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var roll_button: Button = $Panel/Margin/VBox/RollButton

func _ready() -> void:
	if roll_button and not roll_button.pressed.is_connected(_on_roll_pressed):
		roll_button.pressed.connect(_on_roll_pressed)

func set_turn_info(player_label: String, round_number: int) -> void:
	if current_player_label:
		current_player_label.text = "Turn: %s" % player_label
	if round_label:
		round_label.text = "Round %d" % round_number

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func show_roll_result(result: int) -> void:
	set_status("Rolled a %d!" % result)

func set_roll_enabled(enabled: bool) -> void:
	if roll_button:
		roll_button.disabled = not enabled

func _on_roll_pressed() -> void:
	roll_pressed.emit()
