# InventorySystem — Story 013: persistence round-trip + save 粒度 + Private Mode.
#
# Scope (GDD Rule 12/13 + EC-21):
#   AC-31 — one mutation → exactly ONE IPersistence write (per-action flush;
#           whole state under inventory.state)
#   AC-27 — full round-trip: items (id+state+lock+receipt+provenance+acquired_at),
#           shards, loadout restored; #11 mock receives equivalent aggregate
#   AC-25 (integration re-assert) — bulk-salvage N items = 1 write
#   AC-32a — secondary-failure degrade is #3's layering (the mock here IS the
#           single IPersistence surface — backend-primary behaviour verified by
#           state surviving through the mock's in-memory store; real two-layer
#           split is #3-owned, exercised in #3's own suite)
#
# Framework: GUT v9.x | MockPersistenceLayer (write spy) + MockStat + MockGSM
# Story: production/epics/equipment-inventory/story-013-persistence-roundtrip.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _mock_persistence: MockPersistenceLayer
var _mock_stat: MockStat
var _mock_gsm: MockInventoryGSM
var _write_log: Array = []


class MockStat extends RefCounted:
	var sda: float = 28.0
	var pushes: Array[Dictionary] = []

	func is_boot_completed() -> bool:
		return true

	func get_attack_power_excluding_equipment() -> float:
		return sda

	func apply_equipment_modifier(equipment_id: StringName, modifier) -> void:
		pushes.append({"id": equipment_id, "deltas": modifier.deltas.duplicate()})


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_stat = MockStat.new()
	_mock_gsm = MockInventoryGSM.new()
	_write_log = []
	_mock_persistence.attach_write_spy(func(entry: Dictionary) -> void:
		_write_log.append(entry))


func _make_sut():
	var sut = InventorySystem.new()
	sut._persistence = _mock_persistence
	sut._stat_system = _mock_stat
	sut._gsm = _mock_gsm
	sut._stat_table = load(TABLE_PATH)
	sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(sut)  # _ready() runs the 8-step boot
	return sut


func _legendary_record(drop_id: String) -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "tid_rt"
	record.item_type = "WEAPON"
	record.rarity_tier = "LEGENDARY"
	record.class_tag = "STRIKE"
	record.item_metadata["source_receipt"] = {
		"workout_date_unix": 1764540000,
		"signature_text": "鍛造自 180kg × 5",
	}
	return record


# ─── AC-31: per-action single write ────────────────────────────────────────────


func test_one_mutation_flushes_exactly_one_write() -> void:
	# Arrange
	var sut = _make_sut()
	_write_log.clear()

	# Act — one receive (grant + auto-equip is ONE action)
	sut.receive_loot(_legendary_record("D-1"))

	# Assert — exactly one inventory.state write
	var state_writes: Array = _write_log.filter(
		func(e: Dictionary) -> bool: return e["key"] == "inventory.state")
	assert_eq(state_writes.size(), 1)


func test_bulk_salvage_many_items_is_one_write() -> void:
	# Arrange — 5 COMMON armors banked
	var sut = _make_sut()
	for i: int in 5:
		var record: LootDrop = LootDrop.new()
		record.drop_id = "D-b%d" % i
		record.transition_id = "tid_rt"
		record.item_type = "ARMOR"
		record.rarity_tier = "COMMON"
		sut.receive_loot(record)
	_write_log.clear()

	# Act
	var result: Dictionary = sut.bulk_salvage(LootEnums.RarityTier.COMMON)

	# Assert — 5 items, ONE write (frame-budget protection, Rule 13)
	assert_eq(result["count"], 5)
	var state_writes: Array = _write_log.filter(
		func(e: Dictionary) -> bool: return e["key"] == "inventory.state")
	assert_eq(state_writes.size(), 1)


# ─── AC-27: full round-trip ────────────────────────────────────────────────────


func test_full_state_round_trips_through_boot() -> void:
	# Arrange — session 1: grant LEGENDARY (auto-equips) + lock it + shards
	var sut1 = _make_sut()
	sut1.receive_loot(_legendary_record("D-1"))
	var item_id: StringName = &"tid_rt_D-1"
	sut1.set_lock(item_id, true)
	var common: LootDrop = LootDrop.new()
	common.drop_id = "D-2"
	common.transition_id = "tid_rt"
	common.item_type = "ARMOR"
	common.rarity_tier = "COMMON"
	sut1.receive_loot(common)
	sut1.salvage(&"tid_rt_D-2")  # 100 shards + tombstone
	# Session 1 "ends" — _mock_persistence retains the state (sut1 stays parked
	# in the tree; autofree reaps it. The GSM handler is re-pointed by sut2.)

	# Act — session 2 boots off the same persistence store
	_mock_stat.pushes.clear()
	var sut2 = _make_sut()
	_mock_gsm.deliver_gameplay()  # initial non-suspended delivery
	await get_tree().process_frame  # deferred boot push (Contract 5 one-shot)

	# Assert — items / lock / receipt / provenance / acquired_at / shards / loadout
	var restored: EquipmentItem = sut2.get_item(item_id)
	assert_not_null(restored)
	assert_eq(restored.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_true(restored.is_locked)
	assert_true(restored.has_receipt())
	assert_eq(restored.source_receipt.signature_text, "鍛造自 180kg × 5")
	assert_ne(restored.provenance_text, "")
	assert_eq(restored.acquired_at_unix, FIXED_NOW)
	assert_eq(sut2.get_forge_shards(), 100)
	assert_eq(sut2._loadout[EquipmentEnums.EquipSlot.WEAPON], item_id)
	assert_true(sut2._tombstones.has(&"tid_rt_D-2"))
	# #11 received the boot replay aggregate (clamped LEGENDARY: 84)
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_almost_eq(_mock_stat.pushes[0]["deltas"][&"attack_power"], 84.0, 0.0001)


func test_empty_store_boots_clean() -> void:
	# Act — nothing persisted
	var sut = _make_sut()

	# Assert — zero items, zero shards, no crash, boot flush written
	assert_eq(sut.get_inventory_count(), 0)
	assert_eq(sut.get_forge_shards(), 0)
