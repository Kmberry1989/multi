extends Node

# Helper to wire a shared AnimationPlayer on a wrapper node that hosts a child instance named `CharacterModel`.
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
		if typeof(child) == TYPE_OBJECT and child is Body:
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
		wrapper_node.add_child(shared)

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

		for name in list:
			if shared.has_animation(name):
				continue
			var anim = ap.get_animation(name)
			if anim:
				shared.add_animation(name, anim.duplicate())

	# assign shared animation player to Body nodes inside the instanced model
	var bodies: Array = []
	_collect_body_nodes(inst, bodies)
	for b in bodies:
		b.animation_player = shared

	# If we didn't copy any animations, try loading shared AnimationLibrary resources
	# from `res://assets/characters/player/Shared/Animations` and attach them to `shared.libraries`.
	if shared.get_animation_count() == 0:
		var anim_dir = "res://assets/characters/player/Shared/Animations"
		var dir = DirAccess.open(anim_dir)
		if dir:
			var libs = {}
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.to_lower().ends_with(".glb"):
					var path = anim_dir + "/" + file_name
					var res = ResourceLoader.load(path)
					if res:
						var key = file_name.get_basename()
						# Map basename to gameplay canonical key if mapping exists
						var mapped_key = key
						var map_res = ResourceLoader.load("res://scripts/animation_map.gd")
						if map_res and map_res.has_method("get_library_name_for"):
							# invert animation_map to find matching library basename
							var anim_module = load("res://scripts/animation_map.gd")
							if anim_module:
								for canon_key in anim_module.animation_map.keys():
									if anim_module.animation_map[canon_key] == key:
										mapped_key = canon_key
										break
						libs[mapped_key] = res
				file_name = dir.get_next()
			# merge into shared.libraries if any found
			if libs.size() > 0:
				for k in libs.keys():
					shared.libraries[k] = libs[k]
