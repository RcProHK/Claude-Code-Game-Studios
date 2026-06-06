# InventorySystem — Story 012: cosmetic dupe auto-convert + provenance.
#
# Scope (GDD Rule 10/11 + EC-5):
#   AC-37 — cosmetic dupe (visual id already owned) → not granted, shards +=
#           salvage_yield(rarity), CONVERTED_DUPE, telemetry, tombstoned
#           (replay of the convert is also a no-op)
#   AC-05's boot-path scrub lands in Story 014; this story covers the
#           final-dict guard via the shared static (already tested in 002)
#   Provenance — UTC date + class_tag day label; NEUTRAL → 自由日
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-012-cosmetic-provenance.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300  # 2025-12-01 UTC

var _sut


func before_each() -> void:
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _cosmetic_record(drop_id: String, visual_id: String, rarity: String = "RARE") -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "tid_live"
	record.item_type = "COSMETIC"
	record.rarity_tier = rarity
	record.item_metadata["visual_id"] = visual_id
	return record


# ─── AC-37: dupe auto-convert ──────────────────────────────────────────────────


func test_first_cosmetic_grants_normally() -> void:
	# Act
	var result: int = _sut.receive_loot(_cosmetic_record("D-1", "cape_red"))

	# Assert — not a dupe: granted, zero shards
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_forge_shards(), 0)


func test_duplicate_visual_id_converts_to_shards() -> void:
	# Arrange — own cape_red already
	_sut.receive_loot(_cosmetic_record("D-1", "cape_red"))

	# Act — second cape_red from a different drop
	var result: int = _sut.receive_loot(_cosmetic_record("D-2", "cape_red"))

	# Assert — converted at salvage_yield(RARE)=250, never granted twice
	assert_eq(result, EquipmentEnums.ReceiveResult.CONVERTED_DUPE)
	assert_eq(_sut.get_forge_shards(), 250)
	assert_null(_sut.get_item(&"tid_live_D-2"))
	assert_eq(_sut.get_telemetry("inventory.cosmetic.dupe_converted").size(), 1)


func test_converted_dupe_replay_is_noop_no_double_shards() -> void:
	# Arrange — convert happened (tombstoned)
	_sut.receive_loot(_cosmetic_record("D-1", "cape_red"))
	_sut.receive_loot(_cosmetic_record("D-2", "cape_red"))

	# Act — #15 replays the SAME converted drop
	var result: int = _sut.receive_loot(_cosmetic_record("D-2", "cape_red"))

	# Assert — tombstone dedup: no second payment
	assert_eq(result, EquipmentEnums.ReceiveResult.DUPLICATE_NOOP)
	assert_eq(_sut.get_forge_shards(), 250)


func test_different_visual_id_is_not_a_dupe() -> void:
	# Arrange
	_sut.receive_loot(_cosmetic_record("D-1", "cape_red"))

	# Act
	var result: int = _sut.receive_loot(_cosmetic_record("D-2", "cape_blue"))

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_forge_shards(), 0)


func test_functional_items_never_dupe_convert() -> void:
	# Arrange — two functional drops (no visual id) from different drops
	var r1: LootDrop = LootDrop.new()
	r1.drop_id = "D-1"
	r1.transition_id = "tid_live"
	r1.item_type = "WEAPON"
	r1.rarity_tier = "COMMON"
	var r2: LootDrop = LootDrop.new()
	r2.drop_id = "D-2"
	r2.transition_id = "tid_live"
	r2.item_type = "WEAPON"
	r2.rarity_tier = "COMMON"
	_sut.receive_loot(r1)

	# Act — identical type+rarity is a dup FLOOD, not a dupe (salvage answers it)
	var result: int = _sut.receive_loot(r2)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_inventory_count(), 2)


# ─── Provenance (Rule 10) ──────────────────────────────────────────────────────


func test_provenance_neutral_class_labels_free_day() -> void:
	# Arrange — cosmetic forces NEUTRAL → 自由日
	_sut.receive_loot(_cosmetic_record("D-1", "cape_red"))

	# Assert — UTC 12月1日 (FIXED_NOW)
	var item: EquipmentItem = _sut.get_item(&"tid_live_D-1")
	assert_eq(item.provenance_text, "拾於 12月1日・自由日")


func test_provenance_day_labels_per_class_tag() -> void:
	# Direct derivation check across the 4 tags
	assert_eq(_sut._derive_provenance(FIXED_NOW, LootEnums.ClassTag.STRIKE),
		"拾於 12月1日・推日")
	assert_eq(_sut._derive_provenance(FIXED_NOW, LootEnums.ClassTag.CONTROL),
		"拾於 12月1日・拉日")
	assert_eq(_sut._derive_provenance(FIXED_NOW, LootEnums.ClassTag.MOBILITY),
		"拾於 12月1日・腿日")
	assert_eq(_sut._derive_provenance(FIXED_NOW, LootEnums.ClassTag.NEUTRAL),
		"拾於 12月1日・自由日")


func test_provenance_uses_utc_date_across_midnight_boundary() -> void:
	# Arrange — 2025-11-30 23:59:50 UTC (10s before UTC midnight)
	var just_before_midnight: int = 1764547200 - 10

	# Act / Assert — date follows UTC, not local time (determinism pin)
	assert_eq(_sut._derive_provenance(just_before_midnight, LootEnums.ClassTag.STRIKE),
		"拾於 11月30日・推日")
