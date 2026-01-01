extends Node
class_name HUDManager

const CHAT_UI_NAME := "MultiplayerChatUI"
const INVENTORY_UI_NAME := "InventoryUI"
const MINIGAME_HUD_NAME := "MinigameHUD"
const BOARD_HUD_NAME := "BoardHUD"
const BRAWL_HUD_NAME := "BrawlHUD"
const KART_HUD_NAME := "KartHUD"

@export var chat_scene: PackedScene = preload("res://scenes/ui/multiplayer_chat_ui.tscn")
@export var inventory_scene: PackedScene = preload("res://scenes/ui/inventory_ui.tscn")
@export var minigame_hud_scene: PackedScene
@export var board_hud_scene: PackedScene
@export var brawl_hud_scene: PackedScene
@export var kart_hud_scene: PackedScene

var chat_ui: GameMultiplayerChatUI
var inventory_ui: InventoryUI
var minigame_hud: Node
var board_hud: Node
var brawl_hud: Node
var kart_hud: Node

func _ready() -> void:
	chat_ui = _ensure_layer(CHAT_UI_NAME, chat_scene) as GameMultiplayerChatUI
	inventory_ui = _ensure_layer(INVENTORY_UI_NAME, inventory_scene) as InventoryUI
	minigame_hud = _ensure_layer(MINIGAME_HUD_NAME, minigame_hud_scene)
	board_hud = _ensure_layer(BOARD_HUD_NAME, board_hud_scene)
	brawl_hud = _ensure_layer(BRAWL_HUD_NAME, brawl_hud_scene)
	kart_hud = _ensure_layer(KART_HUD_NAME, kart_hud_scene)

func _ensure_layer(layer_name: String, scene: PackedScene) -> Node:
	var parent_node := get_parent()
	if parent_node == null:
		return null

	var layer = parent_node.get_node_or_null(layer_name)
	if layer == null and scene:
		layer = scene.instantiate()
		layer.name = layer_name
		parent_node.add_child(layer)

	if layer is CanvasItem:
		layer.visible = false

	return layer

func get_chat_ui() -> GameMultiplayerChatUI:
	return chat_ui

func get_inventory_ui() -> InventoryUI:
	return inventory_ui

func toggle_chat() -> void:
	if not chat_ui:
		return
	chat_ui.toggle_chat()

func show_chat() -> void:
	if not chat_ui:
		return
	if not chat_ui.is_chat_visible():
		chat_ui.toggle_chat()

func hide_chat() -> void:
	if not chat_ui:
		return
	if chat_ui.is_chat_visible():
		chat_ui.toggle_chat()
	else:
		chat_ui.hide()

func is_chat_visible() -> bool:
	return chat_ui != null and chat_ui.is_chat_visible()

func toggle_inventory(player: PlayerCharacter) -> void:
	if not inventory_ui:
		return
	if inventory_ui.visible:
		inventory_ui.close_inventory()
	else:
		inventory_ui.open_inventory(player)

func open_inventory(player: PlayerCharacter) -> void:
	if inventory_ui:
		inventory_ui.open_inventory(player)

func close_inventory() -> void:
	if inventory_ui:
		inventory_ui.close_inventory()

func is_inventory_visible() -> bool:
	return inventory_ui != null and inventory_ui.visible

func set_minigame_hud_visible(visible: bool) -> void:
	_set_layer_visible(minigame_hud, visible)

func set_board_hud_visible(visible: bool) -> void:
	_set_layer_visible(board_hud, visible)

func set_brawl_hud_visible(visible: bool) -> void:
	_set_layer_visible(brawl_hud, visible)

func set_kart_hud_visible(visible: bool) -> void:
	_set_layer_visible(kart_hud, visible)

func _set_layer_visible(layer: Node, visible: bool) -> void:
	if layer == null:
		return
	if layer is CanvasItem:
		layer.visible = visible
		return
	if visible and layer.has_method("show"):
		layer.show()
	elif not visible and layer.has_method("hide"):
		layer.hide()
