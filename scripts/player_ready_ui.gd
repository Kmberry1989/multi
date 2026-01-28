extends Control
class_name PlayerReadyUI

signal animation_finished

@onready var battle_card_layer: Control = $BattleCardLayer
@onready var player1_ready: TextureRect = $BattleCardLayer/Player1Ready
@onready var player2_ready: TextureRect = $BattleCardLayer/Player2Ready
@onready var vs_label: Label = $BattleCardLayer/VSLabel
@onready var player1_name: Label = $BattleCardLayer/Player1Ready/Player1Name
@onready var player2_name: Label = $BattleCardLayer/Player2Ready/Player2Name
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var players_data: Dictionary = {}

func _ready() -> void:
	# Set up animations
	_setup_animations()
	# Start hidden
	battle_card_layer.modulate.a = 0

func _setup_animations() -> void:
	var anim = Animation.new()
	anim.length = 1.5
	
	# Fade in battle card layer
	var layer_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(layer_idx, "BattleCardLayer:modulate")
	anim.track_insert_key(layer_idx, 0.0, Color(1, 1, 1, 0))
	anim.track_insert_key(layer_idx, 0.4, Color(1, 1, 1, 1))
	
	# Slide in Player 1 from left
	var p1_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(p1_idx, "BattleCardLayer/Player1Ready:position")
	anim.track_insert_key(p1_idx, 0.0, Vector2(-350, player1_ready.position.y))
	anim.track_insert_key(p1_idx, 0.7, player1_ready.position)
	
	# Slide in Player 2 from right
	var p2_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(p2_idx, "BattleCardLayer/Player2Ready:position")
	anim.track_insert_key(p2_idx, 0.0, Vector2(350, player2_ready.position.y))
	anim.track_insert_key(p2_idx, 0.7, player2_ready.position)
	
	# Fade in Player 1
	var p1_fade_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(p1_fade_idx, "BattleCardLayer/Player1Ready:modulate")
	anim.track_insert_key(p1_fade_idx, 0.3, Color(1, 1, 1, 0))
	anim.track_insert_key(p1_fade_idx, 0.6, Color(1, 1, 1, 1))
	
	# Fade in Player 2
	var p2_fade_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(p2_fade_idx, "BattleCardLayer/Player2Ready:modulate")
	anim.track_insert_key(p2_fade_idx, 0.3, Color(1, 1, 1, 0))
	anim.track_insert_key(p2_fade_idx, 0.6, Color(1, 1, 1, 1))
	
	# Pulse and fade in VS label
	var vs_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(vs_idx, "BattleCardLayer/VSLabel:modulate")
	anim.track_insert_key(vs_idx, 0.5, Color(1, 1, 1, 0))
	anim.track_insert_key(vs_idx, 0.8, Color(1, 1, 1, 1))
	
	var vs_scale_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(vs_scale_idx, "BattleCardLayer/VSLabel:scale")
	anim.track_insert_key(vs_scale_idx, 0.5, Vector2(1.2, 1.2))
	anim.track_insert_key(vs_scale_idx, 0.8, Vector2(1, 1))
	
	var lib
	if animation_player.has_animation_library(""):
		lib = animation_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		animation_player.add_animation_library("", lib)
	
	lib.add_animation("show_ready", anim)
	animation_player.animation_finished.connect(_on_animation_finished)

func show_ready_screen(player1_name_str: String, player2_name_str: String) -> void:
	player1_name.text = player1_name_str
	player2_name.text = player2_name_str
	
	# Load ready images
	var p1_path = "res://assets/characters/player/ReadySelect/%s_READY.png" % player1_name_str.to_upper()
	var p2_path = "res://assets/characters/player/ReadySelect/%s_READY.png" % player2_name_str.to_upper()
	
	if ResourceLoader.exists(p1_path):
		player1_ready.texture = load(p1_path)
	
	if ResourceLoader.exists(p2_path):
		player2_ready.texture = load(p2_path)
	
	# Start animation
	animation_player.play("show_ready")

func _on_animation_finished(_anim_name: String) -> void:
	if _anim_name == "show_ready":
		await get_tree().create_timer(1.75).timeout
		animation_finished.emit()

func hide_ready_screen() -> void:
	battle_card_layer.modulate.a = 0
