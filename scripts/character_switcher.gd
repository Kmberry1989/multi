extends Node

# Simple model switcher for player nodes.
# Usage: call `CharacterSwitcher.set_model(player_node, "kyle")` to replace/add a `CharacterModel` child.

var characters := {
	"kyle": "res://scenes/characters/kyle.tscn",
	"eric": "res://scenes/characters/eric.tscn",
	"donald": "res://scenes/characters/donald.tscn",
	"kristen": "res://scenes/characters/kristen.tscn",
	"rochelle": "res://scenes/characters/rochelle.tscn",
	"vickie": "res://scenes/characters/vickie.tscn",
	"brawler": "res://scenes/characters/brawler.tscn",
	"connie": "res://scenes/characters/connie.tscn",
	"caleb": "res://scenes/characters/caleb.tscn",
	"bethany": "res://scenes/characters/bethany.tscn",
	"maia": "res://scenes/characters/maia.tscn",
}

func set_model(target_node: Node, character_name: String) -> void:
	if target_node == null:
		push_warning("set_model: target_node is null")
		return
	var key = character_name.to_lower()
	var scene_path = characters.get(key, "")
	if scene_path == "":
		push_warning("Unknown character: %s" % character_name)
		return
	var packed = null
	if ResourceLoader.exists(scene_path):
		packed = ResourceLoader.load(scene_path)
	if not packed:
		push_warning("Failed to load scene: %s — falling back to placeholder." % scene_path)
		var fallback_path = "res://scenes/characters/placeholder.tscn"
		if ResourceLoader.exists(fallback_path):
			packed = ResourceLoader.load(fallback_path)
		else:
			push_error("Placeholder scene missing: %s" % fallback_path)
			return

	# remove existing CharacterModel child
	if target_node.has_node("CharacterModel"):
		var old = target_node.get_node("CharacterModel")
		old.queue_free()

	# instantiate and add (guard against instantiation failure)
	var inst = null
	if packed and packed is PackedScene:
		inst = packed.instantiate()
	if not inst:
		push_error("Instantiation failed for: %s" % scene_path)
		return
	inst.name = "CharacterModel"
	target_node.add_child(inst)
	# Ensure the new instance has the same owner as the player (useful in editor scenes)
	if target_node.owner:
		inst.owner = target_node.owner
	# Re-run player mesh discovery if player has method
	if target_node.has_method("_find_model_meshes"):
		target_node._find_model_meshes()

	# Wire shared animations into a SharedAnimationPlayer
	var helper = load("res://scripts/character_model_helper.gd")
	if helper and helper.has_method("setup_character_model"):
		helper.setup_character_model(target_node)

func set_model_by_player_name(root: Node, player_node_name: String, character_name: String) -> void:
	if not root: return
	if not root.has_node(player_node_name):
		push_warning("Player node not found: %s" % player_node_name)
		return
	var player_node = root.get_node(player_node_name)
	set_model(player_node, character_name)
