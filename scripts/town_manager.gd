extends Node3D
class_name TownManager

const SAVE_PATH := "user://town_state.json"
const CHECKPOINT_INTERVAL := 8.0
const CLOCK_STEP_SECONDS := 1.0
const CLOCK_STEP_MINUTES := 10
const PLOT_SIZE := Vector2(10.0, 10.0)
const PLOT_CENTERS := [
	Vector3(-14.0, 0.0, -14.0),
	Vector3(14.0, 0.0, -14.0),
	Vector3(-14.0, 0.0, 14.0),
	Vector3(14.0, 0.0, 14.0),
]
const HOUSE_OFFSET := Vector3(-2.5, 0.0, -2.5)
const STORAGE_OFFSET := Vector3(2.0, 0.0, -2.0)
const FESTIVAL_KIOSK_POS := Vector3(0.0, 0.0, -2.0)
const CROP_GROWTH_MINUTES := 180

signal local_message(message: String)
signal clock_changed(day: int, minute_of_day: int)
signal plot_text_changed(value: String)

var town_state: TownState = TownState.new()
var _checkpoint_elapsed := 0.0
var _clock_elapsed := 0.0
var _visual_root: Node3D
var _plot_nodes: Dictionary = {}
var _object_nodes: Dictionary = {}
var _crop_nodes: Dictionary = {}
var _npc_nodes: Dictionary = {}
var _local_home_edit_enabled := false

func _ready() -> void:
	_initialize_state()
	_rebuild_visuals()
	_emit_clock()
	_emit_local_plot_text()

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_checkpoint_elapsed += delta
	_clock_elapsed += delta

	if _clock_elapsed >= CLOCK_STEP_SECONDS:
		_clock_elapsed = 0.0
		_advance_clock(CLOCK_STEP_MINUTES)

	if _checkpoint_elapsed >= CHECKPOINT_INTERVAL:
		_checkpoint_elapsed = 0.0
		_save_state()

func _initialize_state() -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_load_or_create_state()
		else:
			_create_default_state()
	else:
		_load_or_create_state()

func _load_or_create_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				town_state.from_dict(parsed)
				_ensure_default_state()
				return
	_create_default_state()
	_save_state()

func _create_default_state() -> void:
	town_state = TownState.new()
	town_state.day = 1
	town_state.minute_of_day = 8 * 60
	town_state.player_profiles.clear()
	town_state.plots.clear()
	town_state.npcs.clear()
	_ensure_default_state()

func _ensure_default_state() -> void:
	if town_state.plots.is_empty():
		for i in range(PLOT_CENTERS.size()):
			var plot_state := PlotState.new()
			plot_state.plot_id = i
			plot_state.center = PLOT_CENTERS[i]
			plot_state.size = PLOT_SIZE
			var home_state := HomeState.new()
			var house_origin := PLOT_CENTERS[i] + HOUSE_OFFSET
			home_state.door_position = house_origin + Vector3(0.0, 0.0, 2.0)
			home_state.interior_origin = house_origin + Vector3(0.0, 0.0, 1.0)
			plot_state.home = home_state.to_dict()
			town_state.plots.append(plot_state.to_dict())

	if town_state.npcs.is_empty():
		town_state.npcs = [
			_create_npc_state("merchant", "Mara", "merchant", Vector3(-6.0, 0.0, 0.0), Vector3(-8.0, 0.0, -6.0), 8, 18),
			_create_npc_state("carpenter", "Otis", "carpenter", Vector3(0.0, 0.0, 4.0), Vector3(2.0, 0.0, -8.0), 9, 17),
			_create_npc_state("gardener", "Pip", "gardener", Vector3(6.0, 0.0, 0.0), Vector3(8.0, 0.0, -6.0), 7, 16),
		]

func _create_npc_state(
	npc_id: String,
	display_name: String,
	role: String,
	day_position: Vector3,
	evening_position: Vector3,
	start_hour: int,
	end_hour: int
) -> Dictionary:
	var npc := NpcRoutineState.new()
	npc.npc_id = npc_id
	npc.display_name = display_name
	npc.role = role
	npc.day_position = day_position
	npc.evening_position = evening_position
	npc.active_start_hour = start_hour
	npc.active_end_hour = end_hour
	return npc.to_dict()

func register_player(player: PlayerCharacter, player_info: Dictionary) -> void:
	if player == null:
		return

	var display_name := str(player_info.get("display_name", "Neighbor"))
	var profile_id := str(player_info.get("profile_id", ""))
	var avatar_id := str(player_info.get("avatar", player_info.get("character", "kyle")))

	player.apply_identity(profile_id, display_name, avatar_id)
	player.set_meta("player_name", display_name)
	player.set_meta("profile_id", profile_id)

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_emit_local_plot_text()
		return

	var profile_dict := _ensure_profile(profile_id, display_name, avatar_id)
	var plot_id := int(profile_dict.get("plot_id", -1))
	player.assign_plot(plot_id, get_plot_spawn_position(plot_id))
	_broadcast_town_state()

func unregister_player(_peer_id: int) -> void:
	pass

func _ensure_profile(profile_id: String, display_name: String, avatar_id: String) -> Dictionary:
	var profile_data: Dictionary = town_state.player_profiles.get(profile_id, {})
	if profile_data.is_empty():
		var profile := PlayerProfileState.new()
		profile.profile_id = profile_id
		profile.display_name = display_name
		profile.avatar_id = avatar_id
		profile.plot_id = _assign_plot_to_profile(profile_id)
		var plot_dict := _get_plot_dict(profile.plot_id)
		profile.home = plot_dict.get("home", {}).duplicate(true)
		profile.storage = {}
		town_state.player_profiles[profile_id] = profile.to_dict()
	else:
		profile_data["display_name"] = display_name
		profile_data["avatar_id"] = avatar_id
		if int(profile_data.get("plot_id", -1)) == -1:
			profile_data["plot_id"] = _assign_plot_to_profile(profile_id)
		town_state.player_profiles[profile_id] = profile_data
	return town_state.player_profiles[profile_id]

func _assign_plot_to_profile(profile_id: String) -> int:
	for plot_dict in town_state.plots:
		if str(plot_dict.get("owner_profile_id", "")) == profile_id:
			return int(plot_dict.get("plot_id", -1))

	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if str(plot_dict.get("owner_profile_id", "")) == "":
			plot_dict["owner_profile_id"] = profile_id
			town_state.plots[i] = plot_dict
			return int(plot_dict.get("plot_id", i))
	return 0

func get_plot_spawn_position(plot_id: int) -> Vector3:
	var plot_dict := _get_plot_dict(plot_id)
	var home_dict: Dictionary = plot_dict.get("home", {})
	var door_data = home_dict.get("door_position", [0.0, 0.0, 0.0])
	return Vector3(
		float(door_data[0]) if door_data.size() > 0 else 0.0,
		float(door_data[1]) if door_data.size() > 1 else 0.0,
		float(door_data[2]) if door_data.size() > 2 else 0.0
	) + Vector3(0.0, 0.0, 2.0)

func _get_plot_dict(plot_id: int) -> Dictionary:
	for plot_dict in town_state.plots:
		if int(plot_dict.get("plot_id", -1)) == plot_id:
			return plot_dict
	return {}

func get_local_plot_id() -> int:
	var profile_id := str(Network.player_info.get("profile_id", ""))
	var profile_dict: Dictionary = town_state.player_profiles.get(profile_id, {})
	return int(profile_dict.get("plot_id", -1))

func get_first_placeable_item(profile_id: String) -> String:
	var player := _get_player_by_profile(profile_id)
	if player == null or player.get_inventory() == null:
		return ""
	for slot in player.get_inventory().slots:
		if slot and not slot.is_empty():
			var item := ItemDatabase.get_item(slot.item_id)
			if item and item.item_type == Item.ItemType.FURNITURE:
				return item.id
	return ""

func get_first_seed_item(profile_id: String) -> String:
	var player := _get_player_by_profile(profile_id)
	if player == null or player.get_inventory() == null:
		return ""
	for slot in player.get_inventory().slots:
		if slot and not slot.is_empty():
			var item := ItemDatabase.get_item(slot.item_id)
			if item and item.item_type == Item.ItemType.SEED:
				return item.id
	return ""

func get_nearest_owned_object_id(profile_id: String, world_position: Vector3, max_distance: float = 2.4) -> String:
	return get_nearest_object_id(world_position, max_distance, profile_id)

func get_nearest_object_id(world_position: Vector3, max_distance: float = 2.4, owner_profile_id: String = "") -> String:
	var nearest_id := ""
	var nearest_distance := max_distance
	for plot_dict in town_state.plots:
		if owner_profile_id != "" and str(plot_dict.get("owner_profile_id", "")) != owner_profile_id:
			continue
		for object_dict in plot_dict.get("placed_objects", []):
			var object_pos := _vector3_from_array(object_dict.get("position", [0.0, 0.0, 0.0]))
			var distance := world_position.distance_to(object_pos)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_id = str(object_dict.get("object_id", ""))
	return nearest_id

func get_nearest_crop_id(profile_id: String, world_position: Vector3, max_distance: float = 2.5) -> String:
	var plot_id := _get_plot_id_for_profile(profile_id)
	if plot_id == -1:
		return ""
	var plot_dict := _get_plot_dict(plot_id)
	var nearest_id := ""
	var nearest_distance := max_distance
	for crop_dict in plot_dict.get("crops", []):
		var crop_pos := _vector3_from_array(crop_dict.get("position", [0.0, 0.0, 0.0]))
		var distance := world_position.distance_to(crop_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(crop_dict.get("crop_id", ""))
	return nearest_id

func is_crop_ready(crop_id: String) -> bool:
	for plot_dict in town_state.plots:
		for crop_dict in plot_dict.get("crops", []):
			if str(crop_dict.get("crop_id", "")) == crop_id:
				return bool(crop_dict.get("ready_to_harvest", false))
	return false

func get_snap_position_for_player(profile_id: String, player_position: Vector3, forward: Vector3, zone: String = "yard") -> Vector3:
	var plot_dict := _get_plot_dict(_get_plot_id_for_profile(profile_id))
	if plot_dict.is_empty():
		return player_position
	var target := player_position + forward.normalized() * 2.0
	target.y = 0.0
	if zone == "home":
		var home_dict: Dictionary = plot_dict.get("home", {})
		var interior_origin := _vector3_from_array(home_dict.get("interior_origin", [target.x, target.y, target.z]))
		var interior_size_data = home_dict.get("interior_size", [4.0, 4.0])
		var half_size := Vector2(
			float(interior_size_data[0]) if interior_size_data.size() > 0 else 4.0,
			float(interior_size_data[1]) if interior_size_data.size() > 1 else 4.0
		) * 0.5
		target.x = clamp(target.x, interior_origin.x - half_size.x, interior_origin.x + half_size.x)
		target.z = clamp(target.z, interior_origin.z - half_size.y, interior_origin.z + half_size.y)
	else:
		var center := _vector3_from_array(plot_dict.get("center", [target.x, target.y, target.z]))
		var size_data = plot_dict.get("size", [10.0, 10.0])
		var half_plot := Vector2(
			float(size_data[0]) if size_data.size() > 0 else 10.0,
			float(size_data[1]) if size_data.size() > 1 else 10.0
		) * 0.5
		target.x = clamp(target.x, center.x - half_plot.x + 1.0, center.x + half_plot.x - 1.0)
		target.z = clamp(target.z, center.z - half_plot.y + 1.0, center.z + half_plot.y - 1.0)
	target.x = round(target.x)
	target.z = round(target.z)
	return target

func is_local_home_edit_enabled() -> bool:
	return _local_home_edit_enabled

func get_plot_bounds_for_profile(profile_id: String) -> Dictionary:
	var plot_dict := _get_plot_dict(_get_plot_id_for_profile(profile_id))
	if plot_dict.is_empty():
		return {}
	return {
		"center": _vector3_from_array(plot_dict.get("center", [0.0, 0.0, 0.0])),
		"size": _vector2_from_array(plot_dict.get("size", [10.0, 10.0])),
	}

func _get_plot_id_for_profile(profile_id: String) -> int:
	var profile_dict: Dictionary = town_state.player_profiles.get(profile_id, {})
	return int(profile_dict.get("plot_id", -1))

func _advance_clock(minutes: int) -> void:
	town_state.minute_of_day += minutes
	while town_state.minute_of_day >= 24 * 60:
		town_state.minute_of_day -= 24 * 60
		town_state.day += 1
	_update_crop_growth()
	_rebuild_visuals()
	_broadcast_town_state()

func _update_crop_growth() -> void:
	var total_minutes := (town_state.day * 24 * 60) + town_state.minute_of_day
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		var crops: Array = plot_dict.get("crops", []).duplicate(true)
		for j in range(crops.size()):
			var crop_dict: Dictionary = crops[j]
			if int(crop_dict.get("last_watered_minute", -1)) < 0:
				continue
			var planted_total := (int(crop_dict.get("planted_day", 1)) * 24 * 60) + int(crop_dict.get("planted_minute", 0))
			var elapsed := maxi(0, total_minutes - planted_total)
			var stage := mini(3, int(elapsed / (CROP_GROWTH_MINUTES / 3.0)))
			crop_dict["growth_stage"] = stage
			crop_dict["ready_to_harvest"] = elapsed >= CROP_GROWTH_MINUTES
			crops[j] = crop_dict
		plot_dict["crops"] = crops
		town_state.plots[i] = plot_dict

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(town_state.to_dict(), "\t"))

func _broadcast_town_state() -> void:
	var state_dict := town_state.to_dict()
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			sync_town_state.rpc(state_dict)
	else:
		sync_town_state(state_dict)

@rpc("authority", "call_local", "reliable")
func sync_town_state(data: Dictionary) -> void:
	town_state.from_dict(data)
	_rebuild_visuals()
	_emit_clock()
	_emit_local_plot_text()

@rpc("authority", "call_local", "reliable")
func push_local_message(message: String) -> void:
	local_message.emit(message)

@rpc("authority", "call_local", "reliable")
func sync_home_edit_mode(enabled: bool) -> void:
	_local_home_edit_enabled = enabled
	var hint := "Touch HUD: move left, drag right to look, tap buttons to interact"
	if enabled:
		hint = "Home edit: Use picks up, Edit places, Rotate turns furniture"
	local_message.emit("Home edit mode %s" % ("enabled" if enabled else "disabled"))
	_emit_local_plot_text()
	clock_changed.emit(town_state.day, town_state.minute_of_day)
	get_tree().call_group("town_hud", "set_hint", hint)

@rpc("any_peer", "reliable")
func request_plot_assignment(profile_id: String = "") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := 1
	if multiplayer.has_multiplayer_peer():
		peer_id = multiplayer.get_remote_sender_id()
	var info: Dictionary = Network.players.get(peer_id, Network.player_info)
	if profile_id == "":
		profile_id = str(info.get("profile_id", ""))
	if profile_id == "":
		return
	var profile_dict := _ensure_profile(profile_id, str(info.get("display_name", "Neighbor")), str(info.get("avatar", info.get("character", "kyle"))))
	var player := _get_player_by_profile(profile_id)
	if player:
		player.assign_plot(int(profile_dict.get("plot_id", -1)), get_plot_spawn_position(int(profile_dict.get("plot_id", -1))))
	_broadcast_town_state()

@rpc("any_peer", "reliable")
func request_interact() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := 1
	if multiplayer.has_multiplayer_peer():
		peer_id = multiplayer.get_remote_sender_id()
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var interaction := _find_best_interaction(player)
	if interaction.is_empty():
		_send_message_to_peer(peer_id, "Nothing nearby to interact with.")
		return

	match str(interaction.get("type", "")):
		"door":
			var enabled := not bool(player.get_meta("home_edit_mode", false))
			player.set_meta("home_edit_mode", enabled)
			sync_home_edit_mode.rpc_id(peer_id, enabled)
		"storage":
			request_storage_transfer_for_peer(peer_id)
		"npc":
			_handle_npc_interaction(peer_id, str(interaction.get("npc_id", "")))
		"festival":
			_send_message_to_peer(peer_id, "Festival kiosk ready. Legacy board and kart modes stay optional.")
		"furniture":
			var object_id := str(interaction.get("object_id", ""))
			var object_dict := _find_object_dict(object_id)
			if str(object_dict.get("item_id", "")) == "cozy_bed":
				if multiplayer.has_multiplayer_peer():
					player.show_emote.rpc("Resting")
				else:
					player.show_emote("Resting")
				_send_message_to_peer(peer_id, "You take a short rest.")
			else:
				if multiplayer.has_multiplayer_peer():
					player.show_emote.rpc("Sitting")
				else:
					player.show_emote("Sitting")
				_send_message_to_peer(peer_id, "You sit for a moment.")
		"activity":
			if multiplayer.has_multiplayer_peer():
				player.show_emote.rpc("Wave")
			else:
				player.show_emote("Wave")
			_send_message_to_peer(peer_id, "Town square activity complete. Say hi to your neighbors.")

@rpc("any_peer", "reliable")
func request_place_furniture(item_id: String, target_position: Vector3, rotation_degrees: float, zone: String = "yard") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	if not bool(player.get_meta("home_edit_mode", false)):
		_send_message_to_peer(peer_id, "Enter your home's edit mode at the front door first.")
		return
	if item_id == "":
		item_id = get_first_placeable_item(profile_id)
	if item_id == "":
		_send_message_to_peer(peer_id, "You do not have any furniture to place.")
		return
	var item := ItemDatabase.get_item(item_id)
	if item == null or item.item_type != Item.ItemType.FURNITURE:
		_send_message_to_peer(peer_id, "That item is not placeable furniture.")
		return
	var plot_id := _get_plot_id_for_profile(profile_id)
	if plot_id == -1:
		return
	var snapped := get_snap_position_for_player(profile_id, target_position, Vector3.ZERO if target_position == Vector3.ZERO else target_position - player.global_position, zone)
	if not _can_place_object(plot_id, snapped, "", zone):
		_send_message_to_peer(peer_id, "That spot is blocked.")
		return
	if player.get_inventory().remove_item(item_id, 1) <= 0:
		_send_message_to_peer(peer_id, "You need the furniture item in your inventory.")
		return
	var object_state := PlacedObjectState.new()
	object_state.object_id = "%s_%s" % [item_id, Time.get_ticks_usec()]
	object_state.item_id = item_id
	object_state.owner_profile_id = profile_id
	object_state.plot_id = plot_id
	object_state.zone = zone
	object_state.position = snapped
	object_state.rotation_degrees = rotation_degrees
	object_state.footprint = _get_item_footprint(item_id)
	_add_object_to_plot(plot_id, object_state.to_dict())
	player.push_inventory_to_owner()
	_send_message_to_peer(peer_id, "Placed %s." % item.name)
	_save_state()
	_broadcast_town_state()

@rpc("any_peer", "reliable")
func request_move_furniture(object_id: String, target_position: Vector3, rotation_degrees: float, zone: String = "yard") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var plot_id := _get_plot_id_for_profile(profile_id)
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if int(plot_dict.get("plot_id", -1)) != plot_id:
			continue
		var objects: Array = plot_dict.get("placed_objects", []).duplicate(true)
		for j in range(objects.size()):
			var object_dict: Dictionary = objects[j]
			if str(object_dict.get("object_id", "")) != object_id:
				continue
			if str(object_dict.get("owner_profile_id", "")) != profile_id:
				return
			var snapped := get_snap_position_for_player(profile_id, target_position, target_position - player.global_position, zone)
			if not _can_place_object(plot_id, snapped, object_id, zone):
				_send_message_to_peer(peer_id, "That spot is blocked.")
				return
			object_dict["position"] = [snapped.x, snapped.y, snapped.z]
			object_dict["rotation_degrees"] = rotation_degrees
			object_dict["zone"] = zone
			objects[j] = object_dict
			plot_dict["placed_objects"] = objects
			town_state.plots[i] = plot_dict
			_send_message_to_peer(peer_id, "Moved furniture.")
			_save_state()
			_broadcast_town_state()
			return

@rpc("any_peer", "reliable")
func request_remove_furniture(object_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		var objects: Array = plot_dict.get("placed_objects", []).duplicate(true)
		for j in range(objects.size()):
			var object_dict: Dictionary = objects[j]
			if str(object_dict.get("object_id", "")) != object_id:
				continue
			if str(object_dict.get("owner_profile_id", "")) != profile_id:
				return
			var item_id := str(object_dict.get("item_id", ""))
			var item := ItemDatabase.get_item(item_id)
			if item:
				player.get_inventory().add_item(item, 1)
				player.push_inventory_to_owner()
			objects.remove_at(j)
			plot_dict["placed_objects"] = objects
			town_state.plots[i] = plot_dict
			_send_message_to_peer(peer_id, "Picked up %s." % (item.name if item else "furniture"))
			_save_state()
			_broadcast_town_state()
			return

@rpc("any_peer", "reliable")
func request_plant_seed(seed_item_id: String, target_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var plot_id := _get_plot_id_for_profile(profile_id)
	if plot_id == -1:
		return
	if seed_item_id == "":
		seed_item_id = get_first_seed_item(profile_id)
	if seed_item_id == "":
		_send_message_to_peer(peer_id, "You do not have any seeds.")
		return
	var item := ItemDatabase.get_item(seed_item_id)
	if item == null or item.item_type != Item.ItemType.SEED:
		return
	var snapped := get_snap_position_for_player(profile_id, target_position, target_position - player.global_position, "yard")
	if _find_crop_at(plot_id, snapped) != "":
		_send_message_to_peer(peer_id, "There is already a crop planted there.")
		return
	if player.get_inventory().remove_item(seed_item_id, 1) <= 0:
		_send_message_to_peer(peer_id, "You need a seed bag in your inventory.")
		return
	var crop_state := CropState.new()
	crop_state.crop_id = "%s_%s" % [seed_item_id, Time.get_ticks_usec()]
	crop_state.crop_type = _get_crop_product(seed_item_id)
	crop_state.plot_id = plot_id
	crop_state.position = snapped
	crop_state.planted_day = town_state.day
	crop_state.planted_minute = town_state.minute_of_day
	crop_state.last_watered_day = town_state.day
	crop_state.last_watered_minute = -1
	_add_crop_to_plot(plot_id, crop_state.to_dict())
	player.push_inventory_to_owner()
	_send_message_to_peer(peer_id, "Planted %s." % item.name)
	_save_state()
	_broadcast_town_state()

@rpc("any_peer", "reliable")
func request_water_crop(crop_id: String = "") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var plot_id := _get_plot_id_for_profile(profile_id)
	if crop_id == "":
		crop_id = get_nearest_crop_id(profile_id, player.global_position)
	if crop_id == "":
		_send_message_to_peer(peer_id, "No crop nearby to water.")
		return
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if int(plot_dict.get("plot_id", -1)) != plot_id:
			continue
		var crops: Array = plot_dict.get("crops", []).duplicate(true)
		for j in range(crops.size()):
			var crop_dict: Dictionary = crops[j]
			if str(crop_dict.get("crop_id", "")) != crop_id:
				continue
			crop_dict["last_watered_day"] = town_state.day
			crop_dict["last_watered_minute"] = town_state.minute_of_day
			crops[j] = crop_dict
			plot_dict["crops"] = crops
			town_state.plots[i] = plot_dict
			_send_message_to_peer(peer_id, "Watered the crop.")
			_broadcast_town_state()
			return

@rpc("any_peer", "reliable")
func request_harvest_crop(crop_id: String = "") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var plot_id := _get_plot_id_for_profile(profile_id)
	if crop_id == "":
		crop_id = get_nearest_crop_id(profile_id, player.global_position)
	if crop_id == "":
		_send_message_to_peer(peer_id, "No ready crop nearby.")
		return
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if int(plot_dict.get("plot_id", -1)) != plot_id:
			continue
		var crops: Array = plot_dict.get("crops", []).duplicate(true)
		for j in range(crops.size()):
			var crop_dict: Dictionary = crops[j]
			if str(crop_dict.get("crop_id", "")) != crop_id:
				continue
			if not bool(crop_dict.get("ready_to_harvest", false)):
				_send_message_to_peer(peer_id, "That crop is still growing.")
				return
			var item_id := str(crop_dict.get("crop_type", "turnip"))
			var item := ItemDatabase.get_item(item_id)
			if item:
				player.get_inventory().add_item(item, 1)
				player.push_inventory_to_owner()
			crops.remove_at(j)
			plot_dict["crops"] = crops
			town_state.plots[i] = plot_dict
			_send_message_to_peer(peer_id, "Harvested %s." % (item.name if item else "crop"))
			_save_state()
			_broadcast_town_state()
			return

@rpc("any_peer", "reliable")
func request_storage_transfer(item_id: String, quantity: int = 1, to_storage: bool = true) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	request_storage_transfer_for_peer(multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1, item_id, quantity, to_storage)

func request_storage_transfer_for_peer(peer_id: int, item_id: String = "", quantity: int = 1, to_storage: bool = true) -> void:
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var profile_dict: Dictionary = town_state.player_profiles.get(profile_id, {})
	if profile_dict.is_empty():
		return
	var storage: Dictionary = profile_dict.get("storage", {}).duplicate(true)
	if to_storage:
		if item_id == "":
			item_id = _get_first_inventory_item(player)
		if item_id == "":
			_send_message_to_peer(peer_id, "You have nothing to store.")
			return
		if player.get_inventory().remove_item(item_id, quantity) <= 0:
			_send_message_to_peer(peer_id, "You need that item in your inventory.")
			return
		storage[item_id] = int(storage.get(item_id, 0)) + quantity
		var stored_item := ItemDatabase.get_item(item_id)
		_send_message_to_peer(peer_id, "Stored %d x %s." % [quantity, stored_item.name if stored_item else item_id])
	else:
		if item_id == "":
			item_id = _get_first_stored_item(storage)
		if item_id == "":
			_send_message_to_peer(peer_id, "Storage is empty.")
			return
		if int(storage.get(item_id, 0)) < quantity:
			_send_message_to_peer(peer_id, "Not enough stored.")
			return
		var item := ItemDatabase.get_item(item_id)
		if item == null:
			return
		var remaining := player.get_inventory().add_item(item, quantity)
		var moved := quantity - remaining
		if moved <= 0:
			_send_message_to_peer(peer_id, "Inventory is full.")
			return
		storage[item_id] = int(storage.get(item_id, 0)) - moved
		if int(storage.get(item_id, 0)) <= 0:
			storage.erase(item_id)
		_send_message_to_peer(peer_id, "Withdrew %d x %s." % [moved, item.name])
	profile_dict["storage"] = storage
	town_state.player_profiles[profile_id] = profile_dict
	player.push_inventory_to_owner()
	_save_state()
	_broadcast_town_state()

func _get_first_inventory_item(player: PlayerCharacter) -> String:
	for slot in player.get_inventory().slots:
		if slot and not slot.is_empty():
			return slot.item_id
	return ""

func _get_first_stored_item(storage: Dictionary) -> String:
	for key in storage.keys():
		return str(key)
	return ""

func _find_best_interaction(player: PlayerCharacter) -> Dictionary:
	var nearest := {}
	var nearest_distance := 2.8
	var profile_id := player.profile_id
	var plot_dict := _get_plot_dict(_get_plot_id_for_profile(profile_id))
	if not plot_dict.is_empty():
		var home_dict: Dictionary = plot_dict.get("home", {})
		var door_pos := _vector3_from_array(home_dict.get("door_position", [0.0, 0.0, 0.0]))
		var storage_pos := _vector3_from_array(home_dict.get("door_position", [0.0, 0.0, 0.0])) + STORAGE_OFFSET
		var door_distance := player.global_position.distance_to(door_pos)
		if door_distance < nearest_distance:
			nearest_distance = door_distance
			nearest = {"type": "door"}
		var storage_distance := player.global_position.distance_to(storage_pos)
		if storage_distance < nearest_distance:
			nearest_distance = storage_distance
			nearest = {"type": "storage"}

	for npc_dict in town_state.npcs:
		var npc_pos := _npc_position(npc_dict)
		var distance := player.global_position.distance_to(npc_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = {"type": "npc", "npc_id": str(npc_dict.get("npc_id", ""))}

	var festival_distance := player.global_position.distance_to(FESTIVAL_KIOSK_POS)
	if festival_distance < nearest_distance:
		nearest_distance = festival_distance
		nearest = {"type": "festival"}

	for plot_iter in town_state.plots:
		for object_dict in plot_iter.get("placed_objects", []):
			var object_pos := _vector3_from_array(object_dict.get("position", [0.0, 0.0, 0.0]))
			var object_distance := player.global_position.distance_to(object_pos)
			if object_distance < nearest_distance and object_distance <= 2.2:
				nearest_distance = object_distance
				nearest = {"type": "furniture", "object_id": str(object_dict.get("object_id", ""))}

	var activity_distance := player.global_position.distance_to(Vector3.ZERO)
	if activity_distance < nearest_distance and activity_distance <= 2.0:
		nearest = {"type": "activity"}

	return nearest

func _handle_npc_interaction(peer_id: int, npc_id: String) -> void:
	var npc_dict := _find_npc_dict(npc_id)
	if npc_dict.is_empty():
		return
	var role := str(npc_dict.get("role", ""))
	var player := _get_player_by_peer(peer_id)
	if player == null:
		return
	var profile_id := player.profile_id
	var profile_dict: Dictionary = town_state.player_profiles.get(profile_id, {})
	var flags: Dictionary = profile_dict.get("service_flags", {}).duplicate(true)
	var today_key := "day_%d_%s" % [town_state.day, role]

	match role:
		"merchant":
			if player.get_inventory().has_item("turnip", 1):
				player.get_inventory().remove_item("turnip", 1)
				var voucher := ItemDatabase.get_item("market_voucher")
				if voucher:
					player.get_inventory().add_item(voucher, 1)
				player.push_inventory_to_owner()
				_send_message_to_peer(peer_id, "Mara trades your turnip for a market voucher.")
			else:
				_send_message_to_peer(peer_id, "Mara says: bring me fresh turnips and I'll swap vouchers.")
		"carpenter":
			if not flags.has(today_key):
				var chair := ItemDatabase.get_item("wood_chair")
				if chair:
					player.get_inventory().add_item(chair, 1)
					player.push_inventory_to_owner()
				flags[today_key] = true
				profile_dict["service_flags"] = flags
				town_state.player_profiles[profile_id] = profile_dict
				_send_message_to_peer(peer_id, "Otis gifts you a wood chair plan and sample furniture.")
			else:
				_send_message_to_peer(peer_id, "Otis says: try rearranging your home until it feels lived in.")
		"gardener":
			if not flags.has(today_key):
				var seeds := ItemDatabase.get_item("turnip_seed")
				if seeds:
					player.get_inventory().add_item(seeds, 3)
					player.push_inventory_to_owner()
				flags[today_key] = true
				profile_dict["service_flags"] = flags
				town_state.player_profiles[profile_id] = profile_dict
				_send_message_to_peer(peer_id, "Pip hands you starter seeds and reminds you to water them.")
			else:
				_send_message_to_peer(peer_id, "Pip says: watered crops grow much faster than dry ones.")
	_save_state()
	_broadcast_town_state()

func _send_message_to_peer(peer_id: int, message: String) -> void:
	if multiplayer.has_multiplayer_peer():
		push_local_message.rpc_id(peer_id, message)
	else:
		push_local_message(message)

func _get_player_by_peer(peer_id: int) -> PlayerCharacter:
	var level := get_tree().get_current_scene()
	if level == null or not level.has_node("PlayersContainer"):
		return null
	var players_container := level.get_node("PlayersContainer")
	if players_container.has_node(str(peer_id)):
		return players_container.get_node(str(peer_id)) as PlayerCharacter
	return null

func _get_player_by_profile(profile_id: String) -> PlayerCharacter:
	var level := get_tree().get_current_scene()
	if level == null or not level.has_node("PlayersContainer"):
		return null
	for child in level.get_node("PlayersContainer").get_children():
		if child is PlayerCharacter and child.profile_id == profile_id:
			return child
	return null

func _rebuild_visuals() -> void:
	if _visual_root:
		_visual_root.queue_free()
	_visual_root = Node3D.new()
	_visual_root.name = "TownVisuals"
	add_child(_visual_root)
	_plot_nodes.clear()
	_object_nodes.clear()
	_crop_nodes.clear()
	_npc_nodes.clear()

	_build_town_square()
	_build_plots()
	_build_npcs()

func _build_town_square() -> void:
	var square := MeshInstance3D.new()
	var square_mesh := BoxMesh.new()
	square_mesh.size = Vector3(10.0, 0.2, 10.0)
	square.mesh = square_mesh
	square.position = Vector3.ZERO
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.76, 0.62)
	square.set_surface_override_material(0, material)
	_visual_root.add_child(square)

	var kiosk := MeshInstance3D.new()
	var kiosk_mesh := BoxMesh.new()
	kiosk_mesh.size = Vector3(2.4, 2.0, 2.0)
	kiosk.mesh = kiosk_mesh
	kiosk.position = FESTIVAL_KIOSK_POS + Vector3(0.0, 1.0, 0.0)
	var kiosk_material := StandardMaterial3D.new()
	kiosk_material.albedo_color = Color(0.64, 0.32, 0.18)
	kiosk.set_surface_override_material(0, kiosk_material)
	_visual_root.add_child(kiosk)

	var kiosk_label := Label3D.new()
	kiosk_label.text = "Festival Kiosk"
	kiosk_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	kiosk_label.position = FESTIVAL_KIOSK_POS + Vector3(0.0, 2.4, 0.0)
	_visual_root.add_child(kiosk_label)

	for i in range(3):
		var stall := MeshInstance3D.new()
		var stall_mesh := BoxMesh.new()
		stall_mesh.size = Vector3(2.0, 1.8, 1.6)
		stall.mesh = stall_mesh
		stall.position = Vector3(-6.0 + (i * 6.0), 0.9, -5.0)
		var stall_material := StandardMaterial3D.new()
		stall_material.albedo_color = Color(0.82, 0.5 + (i * 0.08), 0.32)
		stall.set_surface_override_material(0, stall_material)
		_visual_root.add_child(stall)

func _build_plots() -> void:
	for plot_dict in town_state.plots:
		var plot_id := int(plot_dict.get("plot_id", -1))
		var center := _vector3_from_array(plot_dict.get("center", [0.0, 0.0, 0.0]))
		var owner_profile_id := str(plot_dict.get("owner_profile_id", ""))
		var plot_root := Node3D.new()
		plot_root.name = "Plot_%d" % plot_id
		plot_root.position = center
		_visual_root.add_child(plot_root)
		_plot_nodes[plot_id] = plot_root

		var lot := MeshInstance3D.new()
		var lot_mesh := BoxMesh.new()
		lot_mesh.size = Vector3(PLOT_SIZE.x, 0.1, PLOT_SIZE.y)
		lot.mesh = lot_mesh
		var lot_material := StandardMaterial3D.new()
		lot_material.albedo_color = Color(0.52, 0.7, 0.38) if owner_profile_id != "" else Color(0.42, 0.52, 0.32)
		lot.set_surface_override_material(0, lot_material)
		plot_root.add_child(lot)

		var label := Label3D.new()
		label.text = _get_plot_label_text(plot_dict)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 2.6, 0.0)
		plot_root.add_child(label)

		var home_dict: Dictionary = plot_dict.get("home", {})
		var door_pos := _vector3_from_array(home_dict.get("door_position", [0.0, 0.0, 0.0])) - center
		var house := MeshInstance3D.new()
		var house_mesh := BoxMesh.new()
		house_mesh.size = Vector3(4.0, 2.6, 4.0)
		house.mesh = house_mesh
		house.position = door_pos + Vector3(0.0, 1.3, -1.0)
		var house_material := StandardMaterial3D.new()
		house_material.albedo_color = Color(0.92, 0.84, 0.7)
		house.set_surface_override_material(0, house_material)
		plot_root.add_child(house)

		var storage := MeshInstance3D.new()
		var storage_mesh := BoxMesh.new()
		storage_mesh.size = Vector3(1.0, 1.0, 1.0)
		storage.mesh = storage_mesh
		storage.position = door_pos + STORAGE_OFFSET + Vector3(0.0, 0.5, 0.0)
		var storage_material := StandardMaterial3D.new()
		storage_material.albedo_color = Color(0.55, 0.28, 0.12)
		storage.set_surface_override_material(0, storage_material)
		plot_root.add_child(storage)

		for object_dict in plot_dict.get("placed_objects", []):
			_build_object_node(plot_root, object_dict, center)
		for crop_dict in plot_dict.get("crops", []):
			_build_crop_node(plot_root, crop_dict, center)

func _build_object_node(plot_root: Node3D, object_dict: Dictionary, center: Vector3) -> void:
	var object_id := str(object_dict.get("object_id", ""))
	var item_id := str(object_dict.get("item_id", ""))
	var object_node := Node3D.new()
	object_node.name = object_id
	object_node.position = _vector3_from_array(object_dict.get("position", [0.0, 0.0, 0.0])) - center
	object_node.rotation_degrees.y = float(object_dict.get("rotation_degrees", 0.0))
	plot_root.add_child(object_node)
	_object_nodes[object_id] = object_node

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.9, 1.2)
	if item_id == "cozy_bed":
		box.size = Vector3(2.0, 0.7, 1.4)
	elif item_id == "garden_lamp":
		box.size = Vector3(0.5, 1.8, 0.5)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_item_color(item_id)
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	object_node.add_child(mesh_instance)

	var label := Label3D.new()
	label.text = ItemDatabase.get_item(item_id).name if ItemDatabase.get_item(item_id) else item_id
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, box.size.y + 0.8, 0.0)
	object_node.add_child(label)

func _build_crop_node(plot_root: Node3D, crop_dict: Dictionary, center: Vector3) -> void:
	var crop_id := str(crop_dict.get("crop_id", ""))
	var stage := int(crop_dict.get("growth_stage", 0))
	var crop_node := Node3D.new()
	crop_node.name = crop_id
	crop_node.position = _vector3_from_array(crop_dict.get("position", [0.0, 0.0, 0.0])) - center
	plot_root.add_child(crop_node)
	_crop_nodes[crop_id] = crop_node

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.25 + (stage * 0.05)
	stem_mesh.bottom_radius = 0.18
	stem_mesh.height = 0.35 + (stage * 0.25)
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, stem_mesh.height * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22 + (stage * 0.1), 0.55 + (stage * 0.1), 0.18)
	stem.set_surface_override_material(0, material)
	crop_node.add_child(stem)

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, stem_mesh.height + 0.6, 0.0)
	label.text = "Harvest" if bool(crop_dict.get("ready_to_harvest", false)) else "Growing"
	crop_node.add_child(label)

func _build_npcs() -> void:
	for npc_dict in town_state.npcs:
		var npc_id := str(npc_dict.get("npc_id", ""))
		var npc_root := Node3D.new()
		npc_root.name = "Npc_%s" % npc_id
		npc_root.position = _npc_position(npc_dict)
		_visual_root.add_child(npc_root)
		_npc_nodes[npc_id] = npc_root

		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.4
		body_mesh.mid_height = 1.0
		body.mesh = body_mesh
		body.position = Vector3(0.0, 1.0, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = _npc_color(str(npc_dict.get("role", "")))
		body.set_surface_override_material(0, material)
		npc_root.add_child(body)

		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 2.2, 0.0)
		label.text = "%s\n%s" % [str(npc_dict.get("display_name", "Neighbor")), str(npc_dict.get("role", "npc")).capitalize()]
		npc_root.add_child(label)

func _npc_position(npc_dict: Dictionary) -> Vector3:
	var hour := int(town_state.minute_of_day / 60) % 24
	var start_hour := int(npc_dict.get("active_start_hour", 8))
	var end_hour := int(npc_dict.get("active_end_hour", 18))
	if hour >= start_hour and hour < end_hour:
		return _vector3_from_array(npc_dict.get("day_position", [0.0, 0.0, 0.0]))
	return _vector3_from_array(npc_dict.get("evening_position", [0.0, 0.0, 0.0]))

func _get_plot_label_text(plot_dict: Dictionary) -> String:
	var owner_profile_id := str(plot_dict.get("owner_profile_id", ""))
	if owner_profile_id == "":
		return "Open Plot"
	var profile_dict: Dictionary = town_state.player_profiles.get(owner_profile_id, {})
	var owner_name := str(profile_dict.get("display_name", "Neighbor"))
	return "%s's Plot" % owner_name

func _can_place_object(plot_id: int, position: Vector3, ignore_object_id: String, zone: String) -> bool:
	var plot_dict := _get_plot_dict(plot_id)
	if plot_dict.is_empty():
		return false
	for object_dict in plot_dict.get("placed_objects", []):
		if str(object_dict.get("object_id", "")) == ignore_object_id:
			continue
		if str(object_dict.get("zone", "yard")) != zone:
			continue
		var object_pos := _vector3_from_array(object_dict.get("position", [0.0, 0.0, 0.0]))
		if object_pos.distance_to(position) < 1.4:
			return false
	if _find_crop_at(plot_id, position) != "":
		return false
	return true

func _find_crop_at(plot_id: int, position: Vector3) -> String:
	var plot_dict := _get_plot_dict(plot_id)
	for crop_dict in plot_dict.get("crops", []):
		var crop_pos := _vector3_from_array(crop_dict.get("position", [0.0, 0.0, 0.0]))
		if crop_pos.distance_to(position) < 0.6:
			return str(crop_dict.get("crop_id", ""))
	return ""

func _add_object_to_plot(plot_id: int, object_dict: Dictionary) -> void:
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if int(plot_dict.get("plot_id", -1)) != plot_id:
			continue
		var objects: Array = plot_dict.get("placed_objects", []).duplicate(true)
		objects.append(object_dict)
		plot_dict["placed_objects"] = objects
		town_state.plots[i] = plot_dict
		return

func _add_crop_to_plot(plot_id: int, crop_dict: Dictionary) -> void:
	for i in range(town_state.plots.size()):
		var plot_dict: Dictionary = town_state.plots[i]
		if int(plot_dict.get("plot_id", -1)) != plot_id:
			continue
		var crops: Array = plot_dict.get("crops", []).duplicate(true)
		crops.append(crop_dict)
		plot_dict["crops"] = crops
		town_state.plots[i] = plot_dict
		return

func _find_object_dict(object_id: String) -> Dictionary:
	for plot_dict in town_state.plots:
		for object_dict in plot_dict.get("placed_objects", []):
			if str(object_dict.get("object_id", "")) == object_id:
				return object_dict
	return {}

func _find_npc_dict(npc_id: String) -> Dictionary:
	for npc_dict in town_state.npcs:
		if str(npc_dict.get("npc_id", "")) == npc_id:
			return npc_dict
	return {}

func _emit_clock() -> void:
	clock_changed.emit(town_state.day, town_state.minute_of_day)

func _emit_local_plot_text() -> void:
	var plot_id := get_local_plot_id()
	if plot_id == -1:
		plot_text_changed.emit("Plot: waiting for assignment")
		return
	var plot_dict := _get_plot_dict(plot_id)
	plot_text_changed.emit(_get_plot_label_text(plot_dict))

func _vector3_from_array(data: Array) -> Vector3:
	return Vector3(
		float(data[0]) if data.size() > 0 else 0.0,
		float(data[1]) if data.size() > 1 else 0.0,
		float(data[2]) if data.size() > 2 else 0.0
	)

func _vector2_from_array(data: Array) -> Vector2:
	return Vector2(
		float(data[0]) if data.size() > 0 else 0.0,
		float(data[1]) if data.size() > 1 else 0.0
	)

func _get_crop_product(seed_item_id: String) -> String:
	match seed_item_id:
		"turnip_seed":
			return "turnip"
		"pumpkin_seed":
			return "pumpkin"
		_:
			return "turnip"

func _get_item_footprint(item_id: String) -> Vector2:
	match item_id:
		"cozy_bed":
			return Vector2(2.0, 1.0)
		"garden_lamp":
			return Vector2(1.0, 1.0)
		_:
			return Vector2.ONE

func _get_item_color(item_id: String) -> Color:
	match item_id:
		"wood_chair":
			return Color(0.67, 0.42, 0.24)
		"cozy_bed":
			return Color(0.76, 0.58, 0.68)
		"garden_lamp":
			return Color(0.92, 0.85, 0.42)
		_:
			return Color(0.72, 0.72, 0.72)

func _npc_color(role: String) -> Color:
	match role:
		"merchant":
			return Color(0.91, 0.51, 0.33)
		"carpenter":
			return Color(0.54, 0.4, 0.26)
		"gardener":
			return Color(0.34, 0.71, 0.37)
		_:
			return Color(0.7, 0.7, 0.7)
