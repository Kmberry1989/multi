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

func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var sk = _find_first_skeleton(child)
		if sk:
			return sk
	return null

func _retarget_animation_to_skeleton(anim: Animation, skeleton: Skeleton3D, root: Node) -> Animation:
	if not anim:
		return anim
	if not skeleton or not root:
		return anim.duplicate()
	var dup: Animation = anim.duplicate()
	var sk_rel_path: NodePath = root.get_path_to(skeleton)
	for i in range(dup.get_track_count()):
		var path: NodePath = dup.track_get_path(i)
		if path.get_subname_count() == 0:
			continue
		var bone_name = path.get_subname(0)
		if skeleton.find_bone(bone_name) == -1:
			continue
		var new_path = NodePath(sk_rel_path.get_concatenated_names() + ":" + bone_name)
		dup.track_set_path(i, new_path)
	return dup

func _ensure_default_library(player: AnimationPlayer) -> AnimationLibrary:
	# Godot 4 stores animations inside libraries. Keep a default library with an empty name
	# so animations can be referenced without a prefix (e.g. "Idle").
	if player.has_animation_library(""):
		return player.get_animation_library("")
	var lib := AnimationLibrary.new()
	player.add_animation_library("", lib)
	return lib

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player_recursive(child)
		if found:
			return found
	return null

func setup_character_model(wrapper_node: Node) -> void:
	if not wrapper_node: return
	var inst: Node = null
	if wrapper_node.has_node("CharacterModel"):
		inst = wrapper_node.get_node("CharacterModel")
	elif wrapper_node.get_child_count() > 0:
		inst = wrapper_node.get_child(0)
	if not inst:
		return

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
	var shared_lib := _ensure_default_library(shared)

	if wrapper_node is RobotBodyController:
		wrapper_node.animation_player = shared
	var skeleton: Skeleton3D = _find_first_skeleton(inst)

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
					var retargeted = _retarget_animation_to_skeleton(anim, skeleton, inst)
					shared_lib.add_animation(anim_name, retargeted)

	# assign shared animation player to Body nodes inside the instanced model
	if inst is RobotBodyController:
		inst.animation_player = shared

	var bodies: Array = []
	_collect_body_nodes(inst, bodies)
	for b in bodies:
		b.animation_player = shared

	# Always try to populate missing standard animations from shared GLB files so every character
	# has a baseline move set.
	var had_anims := shared.get_animation_list().size() > 0
	var loaded_any := false
	if not had_anims:
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
				continue
				
			var packed = ResourceLoader.load(path)
			if packed:
				if packed is AnimationLibrary:
					var anim_names = packed.get_animation_list()
					for anim_name in anim_names:
						var anim = packed.get_animation(anim_name)
						if not anim:
							continue
						if key in ["Idle", "Run", "Walk_Forward", "Walk_Back", "Sprint"]:
							anim.loop_mode = Animation.LOOP_LINEAR
						else:
							anim.loop_mode = Animation.LOOP_NONE
						var retargeted_lib_anim = _retarget_animation_to_skeleton(anim, skeleton, inst)
						shared_lib.add_animation(key, retargeted_lib_anim)
						loaded_any = true
						print("Loaded animation: ", key, " from ", filename, " (AnimationLibrary)")
				elif packed is PackedScene:
					var temp = packed.instantiate()
					var ap = _find_animation_player_recursive(temp)
				
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
								var retargeted_glb = _retarget_animation_to_skeleton(anim, skeleton, inst)
								shared_lib.add_animation(key, retargeted_glb)
								loaded_any = true
								print("Loaded animation: ", key, " from ", filename)
					
					temp.free()
		map_inst.free()
	if not had_anims and not loaded_any:
		push_warning("SharedAnimationPlayer still empty after attempting to load shared animations.")
