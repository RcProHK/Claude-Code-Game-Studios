# InventorySystem — Story 004: inventory cap + mailbox routing + claim-when-full.
#
# Scope (GDD Rule 3 + EC-7/10):
#   AC-08 — inventory 119 → 120th grant IN_INVENTORY, 121st IN_MAILBOX (both edges)
#   AC-11 — claim while inventory full → blocked + shortfall; with room → success
#   EC-10 — claim never over-admits past MAX_INVENTORY
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-004-cap-mailbox-routing.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut


func before_each() -> void:
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


## Inject N minimal IN_INVENTORY items directly (fixture speed — bypasses receive).
func _fill_inventory(count: int) -> void:
	for i: int in count:
		var item: EquipmentItem = EquipmentItem.new()
		item.item_id = StringName("fixture_tid_%d_D-0-%d" % [i, i])
		item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
		_sut._items[item.item_id] = item


func _make_record(drop_id: String) -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "1764547200123_7_combat_lootdrop"
	record.item_type = "ARMOR"
	record.rarity_tier = "COMMON"
	record.class_tag = "MOBILITY"
	return record


# ─── AC-08: boundary both edges ────────────────────────────────────────────────


func test_120th_item_enters_inventory_121st_routes_to_mailbox() -> void:
	# Arrange — 119 existing
	_fill_inventory(119)

	# Act — two consecutive grants
	var result_120: int = _sut.receive_loot(_make_record("D-1-120"))
	var result_121: int = _sut.receive_loot(_make_record("D-1-121"))

	# Assert — 120th direct, 121st parked; cap count excludes mailbox
	assert_eq(result_120, EquipmentEnums.ReceiveResult.OK)
	assert_eq(result_121, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_inventory_count(), 120)
	var item_121: EquipmentItem = _sut.get_item(
		&"1764547200123_7_combat_lootdrop_D-1-121")
	assert_eq(item_121.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_MAILBOX)


# ─── AC-11 / EC-10: claim ──────────────────────────────────────────────────────


func test_claim_blocked_while_inventory_full_returns_shortfall() -> void:
	# Arrange — full inventory + one mailbox item
	_fill_inventory(120)
	_sut.receive_loot(_make_record("D-1-200"))
	var mailbox_id: StringName = &"1764547200123_7_combat_lootdrop_D-1-200"

	# Act
	var result: Dictionary = _sut.claim(mailbox_id)

	# Assert — blocked, no over-admit, state unchanged
	assert_false(result["ok"])
	assert_eq(result["shortfall"], 1)
	assert_eq(_sut.get_item(mailbox_id).lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	assert_eq(_sut.get_inventory_count(), 120)


func test_claim_succeeds_with_room() -> void:
	# Arrange — 119 in inventory, 1 in mailbox
	_fill_inventory(120)
	_sut.receive_loot(_make_record("D-1-200"))
	var mailbox_id: StringName = &"1764547200123_7_combat_lootdrop_D-1-200"
	_sut._items.erase(_sut._items.keys()[0])  # free one slot

	# Act
	var result: Dictionary = _sut.claim(mailbox_id)

	# Assert
	assert_true(result["ok"])
	assert_eq(_sut.get_item(mailbox_id).lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_sut.get_inventory_count(), 120)


func test_claim_unknown_or_non_mailbox_item_errors() -> void:
	# Arrange
	_fill_inventory(1)
	var inventory_id: StringName = _sut._items.keys()[0]

	# Act / Assert — unknown id
	var unknown: Dictionary = _sut.claim(&"no_such_item")
	assert_false(unknown["ok"])
	assert_eq(unknown["error"], "not_in_mailbox")

	# Act / Assert — item not in mailbox state
	var wrong_state: Dictionary = _sut.claim(inventory_id)
	assert_false(wrong_state["ok"])
	assert_eq(wrong_state["error"], "not_in_mailbox")
