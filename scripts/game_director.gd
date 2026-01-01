extends Node
class_name GameDirector

signal minigame_requested(trigger: String, player: Node)

func start_minigame(trigger: String, player: Node) -> void:
	print("GameDirector: minigame requested (", trigger, ")")
	emit_signal("minigame_requested", trigger, player)
