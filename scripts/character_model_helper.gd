extends Node

# Helper to wire a shared AnimationPlayer on a wrapper node that hosts a child instance named 
# `CharacterModel`.
# It copies animations from any AnimationPlayer found inside the instanced model into a single
# `SharedAnimationPlayer` on the wrapper and assigns that shared player to any `Body` instances
# so the game's `Body.animation_player` points to the shared source.

func _collect_animation_players(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is AnimationPlayer:
			out.append(child)
		_collect_animation_players(child, out)

func _collect_body_nodes(node: Node, out: Array) -> void:
	for child in node.get_children():
		# `Body` is declared in `scripts/3d_godot_robot.gd` as `class_name Body`.
		if typeof(child) == TYPE_OBJECT and child is RobotBodyController:
			out.append(child)
		_collect_body_nodes(child, out)

func setup_character_model(wrapper_node: Node) -> void:
	if not wrapper_node: return
	if not wrapper_node.has_node("CharacterModel"):
		return

	var inst = wrapper_node.get_node("CharacterModel")

	var shared: AnimationPlayer = wrapper_node.get_node_or_null("SharedAnimationPlayer")
	if not shared:
		shared = AnimationPlayer.new()
		shared.name = "SharedAnimationPlayer"
		inst.add_child(shared)
	elif shared.get_parent() != inst:
		var old_parent = shared.get_parent()
		if old_parent:
			old_parent.remove_child(shared)
		inst.add_child(shared)
	shared.root_node = inst.get_path()

	if wrapper_node is RobotBodyController:
		wrapper_node.animation_player = shared

	# collect animation players inside the instanced model
	var anim_players: Array = []
	_collect_animation_players(inst, anim_players)

	for ap in anim_players:
		var list = []
		# try to get animation names robustly
		if ap and ap.has_method("get_animation_list"):
			list = ap.get_animation_list()
		elif ap and ap.has_method("get_animation_names"):
			list = ap.get_animation_names()
		else:
			# best-effort: iterate indices
			var count = 0
			if ap and ap.has_method("get_animation_count"):
				count = ap.get_animation_count()
				for i in range(count):
					list.append(ap.get_animation_name(i))

		for anim_name in list:
			if shared.has_animation(anim_name):
				continue
			var anim = ap.get_animation(anim_name)
			if anim:
				shared.add_animation(anim_name, anim.duplicate())

	# assign shared animation player to Body nodes inside the instanced model
	if inst is RobotBodyController:
		inst.animation_player = shared

	var bodies: Array = []
	_collect_body_nodes(inst, bodies)
	for b in bodies:
		b.animation_player = shared

	# If we didn't copy any animations, try loading shared AnimationLibrary resources
	# from `res://assets/characters/player/Shared/Animations` and attach them to `shared.libraries`.
	# Always attempt to populate missing standard keys from GLB files
	# This ensures that even if a character has unique animations, 
	# they still get the basic move set (Idle, Run, etc.)
	if true:
		print("SharedAnimationPlayer empty. Attempting to load from GLBs...")
		var anim_dir = "res://assets/characters/player/Shared/Animations/"
		var map_res = load("res://scripts/animation_map.gd")
		if map_res:
			var map_inst = map_res.new()
			for key in map_inst.animation_map:
				if shared.has_animation(key):
					continue
					
				var filename = map_inst.animation_map[key] + ".glb"
				var path = anim_dir + filename
				
				if not ResourceLoader.exists(path):
					# print("Animation file missing: ", path)
					continue
					
				var packed = ResourceLoader.load(path)
				if packed and packed is PackedScene:
					var temp = packed.instantiate()
					# GLB animations are usually in an AnimationPlayer child
					var ap = null
					for child in temp.get_children():
						if child is AnimationPlayer:
							ap = child
							break
					
					if ap:
						var anim_list = ap.get_animation_list()
						if anim_list.size() > 0:
							# Usually just one animation, take the first one 
							# or one matching the file
							var source_anim_name = anim_list[0]
							var anim = ap.get_animation(source_anim_name)
							if anim:
								if key in ["Idle", "Run", "Walk_Forward", "Walk_Back", "Sprint"]:
									anim.loop_mode = Animation.LOOP_LINEAR
								else:
									anim.loop_mode = Animation.LOOP_NONE
								shared.add_animation(key, anim.duplicate())
								print("Loaded animation: ", key, " from ", filename)
					
					temp.free()
			map_inst.free()
