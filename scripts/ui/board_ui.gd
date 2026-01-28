extends Control
## Board game UI manager for turn info, dice results, and space event messages.
## Displays current player, round, roll results, and space effects with animations.

class_name BoardUI

signal roll_pressed

@onready var turn_info_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TurnInfoLabel
@onready var round_info_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RoundInfoLabel
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var roll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/RollButton
@onready var space_event_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpaceEventLabel

var turn_manager: TurnManager

func _ready() -> void:
	if roll_button and not roll_button.pressed.is_connected(_on_roll_pressed):
		roll_button.pressed.connect(_on_roll_pressed)
	
	# Hide space event initially
	if space_event_label:
		space_event_label.text = ""
		space_event_label.visible = false

## Connect board systems to UI
func setup(tm: TurnManager) -> void:
	turn_manager = tm
	
	if turn_manager:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.dice_rolled.connect(_on_dice_rolled)
		turn_manager.space_event_triggered.connect(_on_space_event)

## Update turn and round display
func set_turn_info(player_name: String, round_number: int) -> void:
	if turn_info_label:
		turn_info_label.text = "Turn: %s" % player_name
	if round_info_label:
		round_info_label.text = "Round %d" % round_number

## Update status message
func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

## Display dice roll result
func show_roll_result(result: int) -> void:
	set_status("Rolled a %d!" % result)

## Show space event message with animation
func show_space_event(space_type: String, player_name: String) -> void:
	if not space_event_label:
		return
	
	var message = ""
	match space_type:
		"item":
			message = "%s landed on ITEM space - gained random item!" % player_name
		"minigame":
			message = "%s landed on MINIGAME space - starting minigame!" % player_name
		"bonus":
			message = "%s landed on BONUS space - gained 10 points!" % player_name
		"trap":
			message = "%s landed on TRAP space - lost 5 points!" % player_name
		_:
			message = "%s landed on a space" % player_name
	
	space_event_label.text = message
	space_event_label.visible = true
	
	# Animate message
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(space_event_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): await get_tree().create_timer(2.0).timeout)
	tween.tween_property(space_event_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): space_event_label.visible = false)

## Enable/disable roll button
func set_roll_enabled(enabled: bool) -> void:
	if roll_button:
		roll_button.disabled = not enabled

## Signal handler for roll button
func _on_roll_pressed() -> void:
	roll_pressed.emit()

## Callback when turn starts
func _on_turn_started(player: Node, round_num: int) -> void:
	var player_name = "Player"
	if player.has_meta("player_name"):
		player_name = player.get_meta("player_name")
	
	set_turn_info(player_name, round_num)
	set_status("Waiting for roll...")
	set_roll_enabled(true)

## Callback when dice is rolled
func _on_dice_rolled(_player: Node, result: int) -> void:
	show_roll_result(result)
	set_roll_enabled(false)

## Callback when player lands on space
func _on_space_event(player: Node, space_type: String) -> void:
	var player_name = "Player"
	if player.has_meta("player_name"):
		player_name = player.get_meta("player_name")
	
	show_space_event(space_type, player_name)
