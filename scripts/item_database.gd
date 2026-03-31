extends Node

var items: Dictionary = {}

func _ready() -> void:
	_load_items()

func get_item(item_id: String) -> Item:
	return items.get(item_id)

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func get_all_items() -> Dictionary:
	return items

func _load_items() -> void:
	items.clear()
	_create_town_items()

func _create_town_items() -> void:
	var placeholder_icon = load("res://icon.png")

	_add_item("turnip_seed", "Turnip Seeds", "A starter seed bag for your first veggie patch.", Item.ItemType.SEED, Item.ItemRarity.COMMON, true, 20, 12, placeholder_icon)
	_add_item("pumpkin_seed", "Pumpkin Seeds", "Larger seeds that take a little longer to mature.", Item.ItemType.SEED, Item.ItemRarity.UNCOMMON, true, 20, 18, placeholder_icon)
	_add_item("turnip", "Turnip", "A crisp garden turnip ready to cook or sell.", Item.ItemType.CROP, Item.ItemRarity.COMMON, true, 20, 20, placeholder_icon)
	_add_item("pumpkin", "Pumpkin", "A hearty harvest crop for autumn meals and decor.", Item.ItemType.CROP, Item.ItemRarity.UNCOMMON, true, 20, 30, placeholder_icon)
	_add_item("watering_can", "Watering Can", "Keeps your crops thriving between harvests.", Item.ItemType.TOOL, Item.ItemRarity.COMMON, false, 1, 40, placeholder_icon)
	_add_item("wood_chair", "Wood Chair", "A simple chair for cozy town homes.", Item.ItemType.FURNITURE, Item.ItemRarity.COMMON, false, 1, 35, placeholder_icon)
	_add_item("cozy_bed", "Cozy Bed", "A soft bed for afternoon naps and guest visits.", Item.ItemType.FURNITURE, Item.ItemRarity.UNCOMMON, false, 1, 90, placeholder_icon)
	_add_item("garden_lamp", "Garden Lamp", "Warm lighting for a welcoming yard.", Item.ItemType.FURNITURE, Item.ItemRarity.UNCOMMON, false, 1, 60, placeholder_icon)
	_add_item("wood_plank", "Wood Plank", "A decor material used for simple upgrades.", Item.ItemType.MATERIAL, Item.ItemRarity.COMMON, true, 30, 8, placeholder_icon)
	_add_item("flower_gift", "Flower Gift", "A thoughtful gift for neighbors around town.", Item.ItemType.GIFT, Item.ItemRarity.COMMON, true, 10, 14, placeholder_icon)
	_add_item("market_voucher", "Market Voucher", "A merchant token earned from fresh produce trades.", Item.ItemType.CONSUMABLE, Item.ItemRarity.UNCOMMON, true, 20, 45, placeholder_icon)

func _add_item(
	item_id: String,
	item_name: String,
	description: String,
	item_type: Item.ItemType,
	rarity: Item.ItemRarity,
	stackable: bool,
	max_stack: int,
	value: int,
	icon: Texture2D
) -> void:
	var item := Item.new()
	item.id = item_id
	item.name = item_name
	item.description = description
	item.item_type = item_type
	item.rarity = rarity
	item.stackable = stackable
	item.max_stack = max_stack
	item.value = value
	item.icon = icon
	items[item.id] = item

func add_item_to_database(item: Item) -> bool:
	if item.id.is_empty():
		push_error("Cannot add item with empty ID to database")
		return false
	items[item.id] = item
	return true

func remove_item_from_database(item_id: String) -> bool:
	if items.has(item_id):
		items.erase(item_id)
		return true
	return false
