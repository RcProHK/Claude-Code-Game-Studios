# InventorySystem — Story 014: boot INITIALISING 8 步.
#
# Scope (GDD Rule 14 + EC-1/2/20 drain side):
#   AC-36 — corrupt persisted dict discarded LOUDLY, valid items load
#   AC-26 — illegal shard balance clamps to 0 + CRITICAL
#   AC-28 — recovery drain: new record granted, tombstoned no-op, namespace
#           cleared AFTER the state flush (no-loss ordering)
#   AC-40 — boot = ONE batched inventory.state write; recovery-clear after it
#   AC-06 — persisted dict with base-stat key + negative delta → guard fires
#   EC-2 scope — persisted LEGENDARY without receipt is NOT killed at boot
#
# Framework: GUT v9.x | MockPersistenceLayer + MockStat + MockGSM
# Story: production/epics/equipment-inventory/story-014-boot-initialising.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _mock_persistence: MockPersistenceLayer
var _mock_stat: MockStat
var _mock_gsm: MockInventoryGSM
var _write_log: Array = []


class MockStat extends RefCounted:
	func is_boot_completed() -> bool:
		return true

	func get_attack_power_excluding_equipment() -> float:
		return 28.0

	func apply_equipment_modifier(_id: StringName, _modifier) -> void:
		pass


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
	add_child_autofree(sut)
	return sut


func _item_dict(item_id: String, overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"item_id": item_id,
		"source_transition_id": "tid_boot",
		"item_type": "ARMOR",
		"rarity": "COMMON",
		"class_tag": "NEUTRAL",
		"stat_modifiers": {"max_hp": 20.0},
		"source_receipt": null,
		"is_cosmetic": false,
		"lifecycle_state": "IN_INVENTORY",
		"is_locked": false,
		"acquired_at_unix": FIXED_NOW,
		"slot_affinity": "ARMOR",
	}
	for key: Variant in overrides:
		base[key] = overrides[key]
	return base


# ─── AC-36: schema-shape guard ─────────────────────────────────────────────────


func test_corrupt_dict_discarded_valid_items_load() -> void:
	# Arrange — 1 corrupt entry (not a dict) + 1 missing-id + 2 valid
	_mock_persistence.write("inventory.state", {
		"items": [
			"not_a_dictionary",
			{"rarity": "EPIC"},  # no item_id → discard
			_item_dict("tid_boot_D-1"),
			_item_dict("tid_boot_D-2"),
		],
		"shards": 50,
	})

	# Act
	var sut = _make_sut()

	# Assert — 2 valid loaded; 2 CRITICAL telemetry
	assert_eq(sut.get_inventory_count(), 2)
	assert_eq(sut.get_telemetry("inventory.item.schema_corrupt").size(), 2)


# ─── AC-26: shard guard ────────────────────────────────────────────────────────


func test_negative_shard_balance_clamps_to_zero_loudly() -> void:
	# Arrange
	_mock_persistence.write("inventory.state", {"items": [], "shards": -500})

	# Act
	var sut = _make_sut()

	# Assert
	assert_eq(sut.get_forge_shards(), 0)
	assert_eq(sut.get_telemetry("inventory.shard.balance_corrupted").size(), 1)


# ─── AC-06: boot-path final-dict guard ─────────────────────────────────────────


func test_persisted_base_stat_key_and_negative_delta_guarded() -> void:
	# Arrange — persisted functional dict carrying STR + negative ATK
	_mock_persistence.write("inventory.state", {
		"items": [_item_dict("tid_boot_D-1",
			{"stat_modifiers": {"STR": 20.0, "attack_power": -5.0}})],
		"shards": 0,
	})

	# Act
	var sut = _make_sut()

	# Assert — STR dropped, negative clamped, each loud (EC-4)
	var item: EquipmentItem = sut.get_item(&"tid_boot_D-1")
	assert_eq(item.stat_modifiers, { &"attack_power": 0.0 })
	assert_eq(sut.get_telemetry("inventory.stat_key.dropped").size(), 2)


func test_persisted_cosmetic_with_stats_scrubbed() -> void:
	# Arrange — EC-5 boot scrub (AC-05 boot path)
	_mock_persistence.write("inventory.state", {
		"items": [_item_dict("tid_boot_D-1", {
			"is_cosmetic": true, "visual_id": "cape",
			"stat_modifiers": {"attack_power": 999.0},
		})],
		"shards": 0,
	})

	# Act
	var sut = _make_sut()

	# Assert
	assert_eq(sut.get_item(&"tid_boot_D-1").stat_modifiers, {})
	assert_eq(sut.get_telemetry("inventory.stat_key.dropped").size(), 1)


# ─── EC-2 scope: persisted trust ───────────────────────────────────────────────


func test_persisted_legendary_without_receipt_not_killed_at_boot() -> void:
	# Arrange — drop-provenance validation must NOT re-run on persisted items
	_mock_persistence.write("inventory.state", {
		"items": [_item_dict("tid_boot_D-1",
			{"rarity": "LEGENDARY", "source_receipt": null})],
		"shards": 0,
	})

	# Act
	var sut = _make_sut()

	# Assert — loaded fine (EC-2 scope = drop path only)
	assert_not_null(sut.get_item(&"tid_boot_D-1"))
	assert_eq(sut.get_telemetry("loot.inventory.grant_fail").size(), 0)


# ─── AC-28: recovery drain + tombstone no-op + clear ───────────────────────────


func test_recovery_drain_grants_new_skips_tombstoned_then_clears() -> void:
	# Arrange — recovery holds 1 new + 1 already-tombstoned record
	var new_record: LootDrop = LootDrop.new()
	new_record.drop_id = "D-new"
	new_record.transition_id = "tid_rec"
	new_record.item_type = "ARMOR"
	new_record.rarity_tier = "COMMON"
	var dead_record: LootDrop = LootDrop.new()
	dead_record.drop_id = "D-dead"
	dead_record.transition_id = "tid_rec"
	dead_record.item_type = "ARMOR"
	dead_record.rarity_tier = "COMMON"
	_mock_persistence.write("loot.pending.recovery",
		[new_record.to_dict(), dead_record.to_dict()])
	_mock_persistence.write("inventory.state", {
		"items": [], "shards": 0,
		"tombstones": {"tid_rec_D-dead": FIXED_NOW - 100},
	})

	# Act
	var sut = _make_sut()

	# Assert — new granted, dead no-op, namespace cleared
	assert_not_null(sut.get_item(&"tid_rec_D-new"))
	assert_null(sut.get_item(&"tid_rec_D-dead"))
	assert_eq(sut.get_inventory_count(), 1)
	assert_eq(_mock_persistence.read("loot.pending.recovery"), [])


# ─── AC-40: single boot write + clear ordering ─────────────────────────────────


func test_boot_flushes_once_and_clears_recovery_after_state_write() -> void:
	# Arrange — boot will mutate via shard clamp + recovery drain
	var record: LootDrop = LootDrop.new()
	record.drop_id = "D-r"
	record.transition_id = "tid_rec"
	record.item_type = "ARMOR"
	record.rarity_tier = "COMMON"
	_mock_persistence.write("loot.pending.recovery", [record.to_dict()])
	_mock_persistence.write("inventory.state", {"items": [], "shards": -1})
	_write_log.clear()

	# Act
	_make_sut()

	# Assert — exactly one inventory.state write; recovery clear comes AFTER it
	var keys_in_order: Array = _write_log.map(
		func(e: Dictionary) -> Variant: return e["key"])
	assert_eq(keys_in_order.count("inventory.state"), 1)
	var state_index: int = keys_in_order.find("inventory.state")
	var recovery_index: int = keys_in_order.find("loot.pending.recovery")
	assert_gt(recovery_index, state_index,
		"recovery clear must follow the state flush (no-loss ordering)")
