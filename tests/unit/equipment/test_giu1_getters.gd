## #17 G-IU-1 additive 三件 — unit suite(#23 story 003)。
## get_all_inventory_items / get_mailbox_items 口徑 + copy 語意;
## bulk_salvage_preview receipt_ids 同源一致性(predicate↔receipt_ids)。
## Fixture pattern = test_inventory_read_getters.gd(G-CS-1 先例)。
extends GutTest

const InventoryScript := preload("res://src/autoload/inventory_system.gd")


var _inv = null


func before_each() -> void:
	_inv = InventoryScript.new()
	_inv._persistence = MockPersistenceLayer.new()  # 隔離 user://(_ready 前注入 — suite 慣例)
	add_child_autofree(_inv)


func _make_item(id: StringName, lifecycle: int, rarity: int = 0,
		locked: bool = false, with_receipt: bool = false) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = lifecycle
	item.rarity = rarity
	item.is_locked = locked
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_inv._items[id] = item
	return item


## StringName.sort() 唔係字典序(`<` 比 pointer/index)— set-compare 一律
## 轉 String 先 sort(getters 零 ordering 承諾,test 只驗集合相等)。
func _sorted(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	out.sort()
	return out


## ============ AC: get_all_inventory_items 口徑(= get_inventory_count) ============

func test_get_all_inventory_items_lists_exactly_in_inventory_plus_equipped() -> void:
	# Arrange: 混合 lifecycle fixture(QA case 1)。
	_make_item(&"inv_item", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"equipped_item", EquipmentEnums.ItemLifecycle.EQUIPPED)
	_make_item(&"mailbox_item", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	# Act
	var all_items: Array[StringName] = _inv.get_all_inventory_items()
	# Assert: 恰好 IN_INVENTORY + EQUIPPED(零 ordering 承諾 — set compare)。
	assert_eq(_sorted(all_items), ["equipped_item", "inv_item"] as Array[String],
		"口徑 = get_inventory_count(IN_INVENTORY + EQUIPPED;mailbox 排除)")


func test_get_all_inventory_items_count_matches_get_inventory_count() -> void:
	_make_item(&"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"b", EquipmentEnums.ItemLifecycle.EQUIPPED)
	_make_item(&"c", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_make_item(&"d", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_inv.get_all_inventory_items().size(), _inv.get_inventory_count(),
		"cap 數乜佢列乜 — 兩個口徑恆等(#23 Rule 5/8)")


func test_get_mailbox_items_lists_exactly_in_mailbox() -> void:
	_make_item(&"inv_item", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"mb_1", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_make_item(&"mb_2", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	assert_eq(_sorted(_inv.get_mailbox_items()), ["mb_1", "mb_2"] as Array[String],
		"恰好 IN_MAILBOX(inventory/equipped 排除)")


func test_getters_empty_state_return_empty_arrays() -> void:
	assert_eq(_inv.get_all_inventory_items().size(), 0, "空倉 → 空 array 非 null")
	assert_eq(_inv.get_mailbox_items().size(), 0)


## ============ AC: copy 語意(QA case 2) ============

func test_returned_arrays_are_copies_caller_mutation_safe() -> void:
	# Arrange
	_make_item(&"inv_item", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"mb_item", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	# Act: caller mutate return arrays。
	var all_items: Array[StringName] = _inv.get_all_inventory_items()
	all_items.append(&"hacked")
	all_items.clear()
	var mailbox: Array[StringName] = _inv.get_mailbox_items()
	mailbox.append(&"hacked_mb")
	# Assert: #17 internal 不變 — 重 call 攞返原本結果。
	assert_eq(_inv.get_all_inventory_items(), [&"inv_item"] as Array[StringName])
	assert_eq(_inv.get_mailbox_items(), [&"mb_item"] as Array[StringName])


## ============ AC: preview receipt_ids 同源一致性(QA case 3) ============

func test_preview_receipt_ids_consistency_across_lifecycles() -> void:
	# Arrange: unlocked receipt 件 × 三 lifecycle 各一(bulk range = mailbox +
	# inventory + equipped,Rule 18 ground truth)+ locked receipt 件 + 無
	# receipt 件 + 異 rarity receipt 件。
	_make_item(&"r_inv", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, false, true)
	_make_item(&"r_mb", EquipmentEnums.ItemLifecycle.IN_MAILBOX, 0, false, true)
	_make_item(&"r_eq", EquipmentEnums.ItemLifecycle.EQUIPPED, 0, false, true)
	_make_item(&"r_locked", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, true, true)
	_make_item(&"plain", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, false, false)
	_make_item(&"r_other_rarity", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 2, false, true)
	# Act
	var preview: Dictionary = _inv.bulk_salvage_preview(0)
	# Assert: receipt_ids 含三件唔含 locked / 異 rarity。
	var ids: Array[StringName] = preview["receipt_ids"]
	assert_eq(_sorted(ids), ["r_eq", "r_inv", "r_mb"] as Array[String],
		"receipt_ids = bulk range 內全部 has_receipt(locked / 異 rarity 排除)")
	# 一致性 assert(AC):count == receipt_count;⊆ bulk range 由 fixture 構造保證。
	assert_eq(preview["receipt_count"], 3)
	assert_eq(ids.size(), preview["receipt_count"],
		"receipt_ids.size() == receipt_count(同 loop 收集 — 零 drift)")


func test_preview_existing_keys_byte_identical_to_old_behaviour() -> void:
	# Arrange: 4 件 rarity 0(1 locked)→ 舊 keys 行為唔變。
	_make_item(&"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, false, true)
	_make_item(&"b", EquipmentEnums.ItemLifecycle.IN_MAILBOX, 0, false, false)
	_make_item(&"c", EquipmentEnums.ItemLifecycle.EQUIPPED, 0, false, false)
	_make_item(&"locked", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, true, true)
	# Act
	var preview: Dictionary = _inv.bulk_salvage_preview(0)
	# Assert: count/yield/receipt_count 同舊公式(3 unlocked;yield = 3 × tier-0)。
	assert_eq(preview["count"], 3)
	assert_eq(preview["yield"], 3 * InventoryScript.salvage_yield(0))
	assert_eq(preview["receipt_count"], 1, "只有 a 帶 receipt(locked 排除)")


func test_preview_zero_match_returns_empty_receipt_ids() -> void:
	_make_item(&"other", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 3, false, true)
	var preview: Dictionary = _inv.bulk_salvage_preview(0)
	assert_eq(preview["count"], 0)
	assert_eq((preview["receipt_ids"] as Array).size(), 0,
		"0 件 rarity match → receipt_ids 空 array(#23 Rule 15 0-件 row 前提)")
