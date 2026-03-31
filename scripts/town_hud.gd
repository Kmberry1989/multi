extends CanvasLayer
class_name TownHUD

var _clock_label: Label
var _hint_label: Label
var _plot_label: Label
var _message_label: Label

func _ready() -> void:
	add_to_group("town_hud")
	layer = 10
	var margin := MarginContainer.new()
	margin.name = "TownHudMargin"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = -16.0
	margin.offset_bottom = -16.0
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(root)

	_clock_label = Label.new()
	_clock_label.text = "Day 1 08:00"
	root.add_child(_clock_label)

	_plot_label = Label.new()
	_plot_label.text = "Plot: unassigned"
	root.add_child(_plot_label)

	_hint_label = Label.new()
	_hint_label.text = "J interact  K edit/place  L garden  Q emote  B inventory  Ctrl chat"
	root.add_child(_hint_label)

	_message_label = Label.new()
	_message_label.text = ""
	root.add_child(_message_label)

func update_clock(day: int, minute_of_day: int) -> void:
	var hours := int(minute_of_day / 60) % 24
	var minutes := minute_of_day % 60
	_clock_label.text = "Day %d  %02d:%02d" % [day, hours, minutes]

func set_plot_text(value: String) -> void:
	_plot_label.text = value

func set_hint(value: String) -> void:
	_hint_label.text = value

func show_message(value: String) -> void:
	_message_label.text = value
