## #17 G-CS-1 additive read getters — unit suite (#22 story 010)。
## get_loadout copy 語意 + get_items_for_slot filter 正確性。
extends GutTest

const InventoryScript := preload("res://src/autoload/inventory_system.gd")


var _inv = null


func before_each() -> void:
	_inv = InventoryScript.new()
	add_child_autofree(_inv)


func _make_item(id: StringName, slot: int, lifecycle: int) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.slot_affinity = slot
	item.lifecycle_state = lifecycle
	_inv._items[id] = item
	return item


func test_get_loadout_returns_copy() -> void:
	var snap: Dictionary = _inv.get_loadout()
	assert_eq(snap.size(), 4, "4 slots(3 functional + cosmetic)")
	snap[EquipmentEnums.EquipSlot.WEAPON] = &"hacked"
	assert_eq(_inv.get_loadout()[EquipmentEnums.EquipSlot.WEAPON], &"",
		"caller mutation 唔掂 internal _loadout(copy 語意)")


func test_get_items_for_slot_filters_lifecycle_and_affinity() -> void:
	_make_item(&"sword_inv", EquipmentEnums.EquipSlot.WEAPON,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"sword_mailbox", EquipmentEnums.EquipSlot.WEAPON,
		EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_make_item(&"armor_inv", EquipmentEnums.EquipSlot.ARMOR,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	var weapons: Array[StringName] = _inv.get_items_for_slot(EquipmentEnums.EquipSlot.WEAPON)
	assert_eq(weapons, [&"sword_inv"] as Array[StringName],
		"只列 IN_INVENTORY + slot match(mailbox / 異 slot 排除)")


func test_get_items_for_slot_cosmetic_only_via_affinity() -> void:
	_make_item(&"hat", EquipmentEnums.EquipSlot.COSMETIC,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"sword", EquipmentEnums.EquipSlot.WEAPON,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	var cosmetics: Array[StringName] = _inv.get_items_for_slot(EquipmentEnums.EquipSlot.COSMETIC)
	assert_eq(cosmetics, [&"hat"] as Array[StringName])


func test_get_items_for_slot_empty_returns_empty_array() -> void:
	var none: Array[StringName] = _inv.get_items_for_slot(EquipmentEnums.EquipSlot.WEAPON)
	assert_eq(none.size(), 0, "0 件 → 空 array(非 null;EC-20 empty sheet 前提)")


func test_equipped_items_not_listed_for_picker() -> void:
	_make_item(&"worn", EquipmentEnums.EquipSlot.WEAPON,
		EquipmentEnums.ItemLifecycle.EQUIPPED)
	var weapons: Array[StringName] = _inv.get_items_for_slot(EquipmentEnums.EquipSlot.WEAPON)
	assert_eq(weapons.size(), 0, "EQUIPPED 唔屬 picker 候選(IN_INVENTORY only)")
