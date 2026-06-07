# InventorySystem — Story 010: salvage + bulk-salvage + transaction ordering.
#
# Scope (GDD Rule 9 + Formula 2 + EC-13/17/19):
#   AC-24 — RARE salvage → +250 shards
#   AC-20 — EQUIPPED salvage: batch (unequip+SALVAGED+shard+backfill) then ONE
#           final push AFTER all mutations (call-order via push snapshot)
#   AC-25 — bulk_salvage(COMMON): 6 unlocked (incl. receipt-bearing) salvaged,
#           locked kept; preview {count 6, yield 600, receipt_count 1}
#   Monotonic curve assertion + locked/not-found refusals
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-010-salvage-bulk-atomicity.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut
var _mock_stat: MockInventoryStat




func before_each() -> void:
	_mock_stat = MockInventoryStat.new()
	_sut = InventorySystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._gsm = MockInventoryGSM.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._stat_system = _mock_stat
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _make_item(id_suffix: String, item_type: int, rarity: int,
		mods: Dictionary, locked: bool = false, with_receipt: bool = false) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("tid_%s_D-0-%s" % [id_suffix, id_suffix])
	item.item_type = item_type
	item.rarity = rarity
	item.stat_modifiers = mods
	item.is_locked = locked
	item.acquired_at_unix = FIXED_NOW
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.slot_affinity = _sut._slot_affinity_for(item_type)
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_sut._items[item.item_id] = item
	return item


## StringName sort 唔係字典序 — set-compare 轉 String 先 sort。
func _sorted_ids(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	out.sort()
	return out


# ─── AC-24: yield ──────────────────────────────────────────────────────────────


func test_salvage_rare_credits_250_shards() -> void:
	# Arrange
	var item: EquipmentItem = _make_item("r", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.RARE, { &"max_hp": 60.0 })

	# Act
	var result: Dictionary = _sut.salvage(item.item_id)

	# Assert
	assert_true(result["ok"])
	assert_eq(result["shards"], 250)
	assert_eq(_sut.get_forge_shards(), 250)
	assert_null(_sut.get_item(item.item_id))
	assert_true(_sut._tombstones.has(item.item_id))


# ─── AC-20: equipped salvage = batch then single final push ────────────────────


func test_equipped_salvage_batches_then_pushes_final_aggregate_once() -> void:
	# Arrange — EPIC weapon equipped + COMMON weapon banked (backfill candidate)
	var equipped: EquipmentItem = _make_item("e", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"attack_power": 45.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, equipped)
	var backfill: EquipmentItem = _make_item("b", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"attack_power": 6.0 })

	# Act
	var result: Dictionary = _sut.salvage(equipped.item_id)

	# Assert — state: salvaged + backfilled; shards credited same transaction
	assert_true(result["ok"])
	assert_null(_sut.get_item(equipped.item_id))
	assert_eq(backfill.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(_sut.get_forge_shards(), 450)
	# Push: exactly ONE, and its deltas reflect the POST-batch loadout
	# (backfill included) — proving the push ran after all mutations.
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_almost_eq(
		_mock_stat.pushes[0]["deltas"][&"attack_power"], 6.0, 0.0001)


func test_non_equipped_salvage_does_not_push() -> void:
	# Arrange — banked item only (loadout untouched)
	var item: EquipmentItem = _make_item("n", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 })

	# Act
	_sut.salvage(item.item_id)

	# Assert
	assert_eq(_mock_stat.pushes.size(), 0)


# ─── Refusals ──────────────────────────────────────────────────────────────────


func test_salvage_locked_item_refused() -> void:
	# Arrange
	var locked: EquipmentItem = _make_item("l", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.EPIC, { &"max_hp": 100.0 }, true)

	# Act
	var result: Dictionary = _sut.salvage(locked.item_id)

	# Assert — zero mutation
	assert_false(result["ok"])
	assert_eq(result["error"], "locked")
	assert_not_null(_sut.get_item(locked.item_id))
	assert_eq(_sut.get_forge_shards(), 0)


func test_salvage_unknown_id_refused() -> void:
	var result: Dictionary = _sut.salvage(&"no_such_item")
	assert_false(result["ok"])
	assert_eq(result["error"], "not_found")


# ─── AC-25: bulk-salvage + preview ─────────────────────────────────────────────


func test_bulk_salvage_common_takes_unlocked_keeps_locked() -> void:
	# Arrange — 5 unlocked + 1 locked + 1 unlocked-with-receipt (all COMMON)
	for i: int in 5:
		_make_item("u%d" % i, LootEnums.ItemType.ARMOR,
			LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 })
	var locked: EquipmentItem = _make_item("lk", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 }, true)
	_make_item("rc", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 }, false, true)

	# Act — preview first (no mutation), then execute
	var preview: Dictionary = _sut.bulk_salvage_preview(LootEnums.RarityTier.COMMON)
	var result: Dictionary = _sut.bulk_salvage(LootEnums.RarityTier.COMMON)

	# Assert — receipt-but-unlocked IS salvaged (EC-17); locked kept.
	# Per-key asserts(G-IU-1 #23 story 003 加咗 additive receipt_ids key —
	# exact-dict assert 係 incidental strictness;原 intent = 三個值)。
	assert_eq(preview["count"], 6)
	assert_eq(preview["yield"], 600)
	assert_eq(preview["receipt_count"], 1)
	assert_eq(_sorted_ids(preview["receipt_ids"]), ["tid_rc_D-0-rc"] as Array[String],
		"G-IU-1: receipt_ids 同 loop 收集(誠實名單 = 毀滅名單)")
	assert_eq(result["count"], 6)
	assert_eq(result["shards"], 600)
	assert_eq(_sut.get_forge_shards(), 600)
	assert_not_null(_sut.get_item(locked.item_id))


func test_bulk_salvage_empty_range_is_noop() -> void:
	# Act
	var result: Dictionary = _sut.bulk_salvage(LootEnums.RarityTier.LEGENDARY)

	# Assert — zero count, zero shards, zero pushes
	assert_eq(result["count"], 0)
	assert_eq(_sut.get_forge_shards(), 0)
	assert_eq(_mock_stat.pushes.size(), 0)


func test_bulk_salvage_with_equipped_item_pushes_once() -> void:
	# Arrange — equipped COMMON + 2 banked COMMON
	var equipped: EquipmentItem = _make_item("e", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"attack_power": 6.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, equipped)
	_make_item("b1", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 })
	_make_item("b2", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.COMMON, { &"max_hp": 20.0 })

	# Act
	var result: Dictionary = _sut.bulk_salvage(LootEnums.RarityTier.COMMON)

	# Assert — 3 salvaged, single push for the whole transaction
	assert_eq(result["count"], 3)
	assert_eq(_mock_stat.pushes.size(), 1)


# ─── Monotonic curve invariant ─────────────────────────────────────────────────


func test_default_salvage_curve_passes_monotonic_assert() -> void:
	# Must not crash (design-by-contract pattern)
	InventorySystem.assert_salvage_curve_monotonic()
	pass_test("default RARITY_SHARD_MULT curve is strictly increasing")
