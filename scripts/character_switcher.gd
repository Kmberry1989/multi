extends Node
# Force reload

# Simple model switcher for player nodes.
# Usage: call `CharacterSwitcher.set_model(player_node, "kyle")` to replace/add a `CharacterModel` child.

var characters := {
	"kyle": "res://scenes/characters/kyle.tscn",
	"eric": "res://scenes/characters/eric.tscn",
	"donald": "res://scenes/characters/donald.tscn",
	"kristen": "res://scenes/characters/kristen.tscn",
	"rochelle": "res://scenes/characters/rochelle.tscn",
	"vickie": "res://scenes/characters/vickie.tscn",
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
	
	# Attach the body controller script to ensure animations work
	# We use the existing 3d_godot_robot.gd which implements the 'Body' class logic
	var body_script = load("res://scripts/3d_godot_robot.gd")
	if body_script:
		inst.set_script(body_script)
		# Manually set the exported variables if the script is attached
		# _character should be the parent (player)
		inst.character = target_node
		# AnimationPlayer is usually a direct child of the GLB scene
		if inst.has_node("AnimationPlayer"):
			inst.animation_player = inst.get_node("AnimationPlayer")
	
	target_node.add_child(inst)
	
	# Update player's reference to the body if applicable
	if "body" in target_node:
		target_node.body = inst
	# Ensure the new instance has the same owner as the player (useful in editor scenes)
	if target_node.owner:
		inst.owner = target_node.owner
	# Re-run player mesh discovery if player has method
	if target_node.has_method("find_model_meshes"):
		target_node.find_model_meshes()

	# Wire shared animations if needed, though individual scenes usually have their own
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
