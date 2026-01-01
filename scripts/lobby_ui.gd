extends Control
class_name LobbyUI

signal ready_toggled(is_ready: bool)

@onready var players_list: VBoxContainer = $Panel/Content/Columns/PlayersColumn/PlayersList
@onready var turns_rule: Label = $Panel/Content/Columns/RulesColumn/TurnsRule
@onready var minigame_rule: Label = $Panel/Content/Columns/RulesColumn/MinigameRule
@onready var brawl_rule: Label = $Panel/Content/Columns/RulesColumn/BrawlRule
@onready var kart_rule: Label = $Panel/Content/Columns/RulesColumn/KartRule
@onready var ready_button: Button = $Panel/Content/Footer/ReadyButton
@onready var status_label: Label = $Panel/Content/Footer/StatusLabel

func _ready() -> void:
	if not ready_button.toggled.is_connected(_on_ready_toggled):
		ready_button.toggled.connect(_on_ready_toggled)

func update_rules(rule_data: Dictionary) -> void:
	turns_rule.text = "Turns: %s" % str(rule_data.get("turns", "-"))
	minigame_rule.text = "Minigame Pool: %s" % str(rule_data.get("minigame_pool", "-"))
	brawl_rule.text = "Brawl: %s" % _bool_label(rule_data.get("brawl", false))
	kart_rule.text = "Kart: %s" % _bool_label(rule_data.get("kart", false))

func update_players(players: Dictionary, ready_states: Dictionary) -> void:
	for child in players_list.get_children():
		child.queue_free()

	var ids = players.keys()
	ids.sort()
	for id in ids:
		var player_info = players[id]
		var nick = str(player_info.get("nick", "Player %s" % str(id)))
		var is_ready = ready_states.get(id, false)

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = nick
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var ready_label = Label.new()
		ready_label.text = is_ready ? "Ready" : "Not Ready"

		row.add_child(name_label)
		row.add_child(ready_label)
		players_list.add_child(row)

func set_ready_state(is_ready: bool) -> void:
	if ready_button:
		ready_button.set_pressed_no_signal(is_ready)

func set_status(text: String) -> void:
	status_label.text = text

func _on_ready_toggled(button_pressed: bool) -> void:
	ready_toggled.emit(button_pressed)

func _bool_label(value: bool) -> String:
	return value ? "On" : "Off"
